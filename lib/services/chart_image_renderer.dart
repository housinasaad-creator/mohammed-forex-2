import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../features/dashboard/models/candle_model.dart';

/// Renders the candlestick chart to a PNG entirely off the widget tree
/// (PictureRecorder + Canvas) — used both for the plain image sent to the
/// vision agent, and for the final composed image (chart + decision band +
/// entry/SL/TP footer + watermark) shown in the UI and offered for export.
class ChartImageRenderer {
  ChartImageRenderer._();

  static const _bg        = Color(0xFF0B0E14);
  static const _bullCol   = Color(0xFF00D68F);
  static const _bearCol   = Color(0xFFFF3B5C);
  static const _gold      = Color(0xFFD4AF37);
  static const _neutralCol = Color(0xFF8A8FA3);
  static const _axisW     = 70.0;
  static const _footerH   = 56.0;  // Entry / SL / TP / Risk% strip
  static const _bandH     = 116.0; // decision + reasons + exit-note + timestamp strip
  static const _warnH     = 38.0;  // low-liquidity warning strip (top)

  static Future<Uint8List> render({
    required List<Candle> candles,
    List<double> pivotHighs = const [],
    List<double> pivotLows = const [],
    double? entry,
    double? sl,
    double? tp,
    double? riskPercent,
    String? signal,        // 'BUY' | 'SELL' | 'WAIT' — colors the decision band
    double? confidence,    // 0-100
    String? reasonsText,
    String? exitNote,
    bool lowLiquidityWarning = false, // Asian session 00:00-09:00 Turkey time
    String? hardExitTime,             // "HH:mm" Turkey time — now + 2h
    String? sessionName,              // 'London/NY', 'Tokyo', etc.
    String lang = 'en',
    String watermark = 'MOHAMMED FOREX',
    Size size = const Size(900, 480),
  }) async {
    final hasLevels   = entry != null && sl != null && tp != null;
    final hasDecision = signal != null && (reasonsText?.isNotEmpty ?? false);
    final warnH = lowLiquidityWarning ? _warnH : 0.0;
    final totalH = warnH + size.height
        + (hasDecision ? _bandH : 0)
        + (hasLevels ? _footerH : 0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, totalH));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, totalH), Paint()..color = _bg);

    if (lowLiquidityWarning) {
      _paintLowLiquidityBanner(canvas, size.width, warnH, lang);
    }

    canvas.save();
    canvas.translate(0, warnH);
    if (candles.isNotEmpty) {
      _paintChart(canvas, size, candles, pivotHighs, pivotLows, entry, sl, tp);
    }
    // Big, faint, diagonal watermark spread across the chart only — protects
    // against re-posting without crediting the source.
    _paintDiagonalWatermark(canvas, size, watermark);
    _paintCornerTag(canvas, size, watermark);
    canvas.restore();

    double cursorY = warnH + size.height;
    if (hasDecision) {
      final showHardExit = signal != 'WAIT' ? hardExitTime : null;
      _paintDecisionBand(canvas, size.width, cursorY, _bandH, signal!, confidence, reasonsText!, exitNote, showHardExit, sessionName, lang);
      cursorY += _bandH;
    }
    if (hasLevels) {
      _paintLevelsFooter(canvas, size.width, cursorY, _footerH, entry!, sl!, tp!, riskPercent);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.round(), totalH.round());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ── Low-liquidity warning banner (Asian session, Turkey time) ─────────────

  static void _paintLowLiquidityBanner(Canvas canvas, double width, double height, String lang) {
    const amber = Color(0xFFFFB020);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = amber.withOpacity(0.16));
    canvas.drawLine(Offset(0, height), Offset(width, height), Paint()..color = amber..strokeWidth = 1.5);

    final text = lang == 'ar'
        ? '⚠️ تحذير: سيولة ضعيفة - تجنّب الدخول الآن'
        : lang == 'tr'
            ? '⚠️ Uyarı: Zayıf Likidite - Giriş Yapma'
            : '⚠️ Warning: Weak Liquidity - No Entry';

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontFamily: 'Arial', fontSize: 14, fontWeight: FontWeight.w900, color: amber, letterSpacing: 0.3),
      ),
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((width - tp.width) / 2, (height - tp.height) / 2));
  }

  // ── Chart body ─────────────────────────────────────────────────────────────

  static void _paintChart(
    Canvas canvas,
    Size size,
    List<Candle> candles,
    List<double> pivotHighs,
    List<double> pivotLows,
    double? entry,
    double? sl,
    double? tp,
  ) {
    final chartW = size.width - _axisW;
    final chartH = size.height;

    double lo = candles.map((c) => c.low).reduce(math.min);
    double hi = candles.map((c) => c.high).reduce(math.max);
    for (final v in [entry, sl, tp]) {
      if (v != null) {
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
    final pad = (hi - lo) * 0.12;
    lo -= pad;
    hi += pad;
    final range = hi - lo;
    if (range <= 0) return;

    double toY(double p) => chartH * (1.0 - (p - lo) / range);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, chartW, chartH));

    final gridPaint = Paint()..color = const Color(0x14FFFFFF)..strokeWidth = 0.6;
    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(Offset(0, chartH * i / 4), Offset(chartW, chartH * i / 4), gridPaint);
    }

    final supplyPaint = Paint()..color = _bearCol.withOpacity(0.22)..strokeWidth = 0.8;
    final demandPaint = Paint()..color = _bullCol.withOpacity(0.22)..strokeWidth = 0.8;
    for (final ph in pivotHighs) {
      final y = toY(ph);
      if (y >= 0 && y <= chartH) _dash(canvas, 0, chartW, y, supplyPaint);
    }
    for (final pl in pivotLows) {
      final y = toY(pl);
      if (y >= 0 && y <= chartH) _dash(canvas, 0, chartW, y, demandPaint);
    }

    final n = candles.length;
    final cW = chartW / n;
    final bW = (cW * 0.55).clamp(2.0, 14.0);

    for (int i = 0; i < n; i++) {
      final c = candles[i];
      final cx = i * cW + cW / 2;
      final bull = c.close >= c.open;
      final col = bull ? _bullCol : _bearCol;

      canvas.drawLine(Offset(cx, toY(c.high)), Offset(cx, toY(c.low)),
          Paint()..color = col..strokeWidth = 1.2);

      final top = toY(bull ? c.close : c.open);
      final bot = toY(bull ? c.open : c.close);
      final h = (bot - top).abs();

      if (h < 1.2) {
        canvas.drawLine(Offset(cx - bW / 2, top), Offset(cx + bW / 2, top),
            Paint()..color = col..strokeWidth = 1.5);
      } else {
        canvas.drawRect(Rect.fromLTRB(cx - bW / 2, top, cx + bW / 2, bot), Paint()..color = col);
      }
    }

    canvas.restore();

    // Price-axis grid labels — skipped near any entry/sl/tp line so they
    // never overlap that line's own price badge (previous bug: garbled
    // overlapping digits when a grid label landed close to a level line).
    final levelYs = [entry, sl, tp].whereType<double>().map(toY).toList();
    for (int i = 0; i <= 4; i++) {
      final y = chartH * i / 4;
      final tooClose = levelYs.any((ly) => (ly - y).abs() < 18);
      if (tooClose) continue;
      final price = hi - range * i / 4;
      _text(canvas, _fmtPrice(price), Offset(chartW + 6, y - 6),
          const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF8A8FA3)));
    }

    if (entry != null) _level(canvas, chartW, chartH, toY(entry), _gold, 'ENTRY', entry);
    if (sl != null)    _level(canvas, chartW, chartH, toY(sl),    _bearCol, 'SL', sl);
    if (tp != null)    _level(canvas, chartW, chartH, toY(tp),    _bullCol, 'TP', tp);
  }

  static void _level(Canvas canvas, double chartW, double chartH, double y, Color color, String label, double price) {
    if (y < -4 || y > chartH + 4) return;
    _dash(canvas, 0, chartW, y, Paint()..color = color..strokeWidth = 1.6, d: 12, g: 6);

    final labelStyle = TextStyle(fontFamily: 'monospace', fontSize: 10.5, fontWeight: FontWeight.bold, color: color);
    final priceStyle = TextStyle(fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w900, color: color);
    final labelTp = TextPainter(text: TextSpan(text: label, style: labelStyle), textDirection: TextDirection.ltr)..layout();
    final priceTp = TextPainter(text: TextSpan(text: _fmtPrice(price), style: priceStyle), textDirection: TextDirection.ltr)..layout();

    final boxW = math.max(labelTp.width, priceTp.width) + 12;
    final boxH = labelTp.height + priceTp.height + 4;
    final bgR = Rect.fromLTWH(chartW + 6, y - boxH / 2 - 2, boxW, boxH + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(bgR, const Radius.circular(4)), Paint()..color = color.withOpacity(0.20));
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgR, const Radius.circular(4)),
      Paint()..color = color.withOpacity(0.55)..style = PaintingStyle.stroke..strokeWidth = 1,
    );
    labelTp.paint(canvas, Offset(chartW + 12, bgR.top + 3));
    priceTp.paint(canvas, Offset(chartW + 12, bgR.top + 3 + labelTp.height + 1));
  }

  // ── Decision band: signal + confidence + reasons + exit-note + timestamp ──
  // Lives BELOW the candles (never overlaps them) and is colored green/red
  // to match the direction — like a screenshot caption, not an overlay.

  static void _paintDecisionBand(
    Canvas canvas, double width, double top, double height,
    String signal, double? confidence, String reasonsText, String? exitNote, String? hardExitTime,
    String? sessionName, String lang,
  ) {
    final isBuy  = signal == 'BUY';
    final isSell = signal == 'SELL';
    final accent = isBuy ? _bullCol : isSell ? _bearCol : _neutralCol;
    final textDir = lang == 'ar' ? TextDirection.rtl : TextDirection.ltr;

    canvas.drawRect(Rect.fromLTWH(0, top, width, height), Paint()..color = accent.withOpacity(0.10));
    canvas.drawRect(Rect.fromLTWH(0, top, width, height), Paint()..color = const Color(0xFF0E1219).withOpacity(0.35));
    canvas.drawRect(Rect.fromLTWH(0, top, 4, height), Paint()..color = accent);
    canvas.drawLine(Offset(0, top), Offset(width, top), Paint()..color = accent.withOpacity(0.5)..strokeWidth = 1);

    const pad = 16.0;
    double y = top + 10;

    // Row: SIGNAL (confidence%)  ················  timestamp / session / hard-exit
    final sigText = confidence != null ? '$signal (${confidence.toStringAsFixed(0)}%)' : signal;
    final sigTp = TextPainter(
      text: TextSpan(text: sigText, style: TextStyle(fontFamily: 'Arial', fontSize: 19, fontWeight: FontWeight.w900, color: accent)),
      textDirection: TextDirection.ltr,
    )..layout();
    sigTp.paint(canvas, Offset(pad, y));

    final ts = sessionName != null && sessionName.isNotEmpty
        ? '${_timestamp()}  ·  $sessionName'
        : _timestamp();
    final tsTp = TextPainter(
      text: TextSpan(text: ts, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF8A8FA3))),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - pad * 2);
    tsTp.paint(canvas, Offset(width - tsTp.width - pad, y + 4));

    if (hardExitTime != null && hardExitTime.isNotEmpty) {
      final hardExitTp = TextPainter(
        text: TextSpan(
          text: 'Hard Exit Time: $hardExitTime',
          style: TextStyle(fontFamily: 'Arial', fontSize: 11, fontWeight: FontWeight.w800, color: accent),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      hardExitTp.paint(canvas, Offset(width - hardExitTp.width - pad, y + 4 + tsTp.height + 3));
    }

    y += sigTp.height + 6;

    final reasonsTp = TextPainter(
      text: TextSpan(text: reasonsText, style: const TextStyle(fontFamily: 'Arial', fontSize: 13, color: Colors.white, height: 1.35)),
      textDirection: textDir,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: width - pad * 2);
    reasonsTp.paint(canvas, Offset(pad, y));
    y += reasonsTp.height + 6;

    if (exitNote != null && exitNote.isNotEmpty) {
      final exitTp = TextPainter(
        text: TextSpan(text: exitNote, style: TextStyle(fontFamily: 'Arial', fontSize: 12, fontWeight: FontWeight.w600, color: accent.withOpacity(0.95), height: 1.3)),
        textDirection: textDir,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: width - pad * 2);
      exitTp.paint(canvas, Offset(pad, y));
    }
  }

  // ── Footer: exact Entry / SL / TP / Risk% numbers ─────────────────────────

  static void _paintLevelsFooter(
    Canvas canvas, double width, double top, double height,
    double entry, double sl, double tp, double? riskPercent,
  ) {
    canvas.drawRect(Rect.fromLTWH(0, top, width, height), Paint()..color = const Color(0xFF11151F));
    canvas.drawLine(Offset(0, top), Offset(width, top), Paint()..color = const Color(0x1FFFFFFF)..strokeWidth = 1);

    final showRisk = riskPercent != null && riskPercent > 0;
    final cellCount = showRisk ? 4 : 3;
    final cellW = width / cellCount;

    _footerCell(canvas, Rect.fromLTWH(0,         top, cellW, height), 'ENTRY', _fmtPrice(entry), _gold);
    _footerCell(canvas, Rect.fromLTWH(cellW,     top, cellW, height), 'STOP LOSS', _fmtPrice(sl), _bearCol);
    _footerCell(canvas, Rect.fromLTWH(cellW * 2, top, cellW, height), 'TAKE PROFIT', _fmtPrice(tp), _bullCol);
    if (showRisk) {
      _footerCell(canvas, Rect.fromLTWH(cellW * 3, top, cellW, height), 'RISK %', '${riskPercent.toStringAsFixed(1)}%', _gold);
    }
  }

  static void _footerCell(Canvas canvas, Rect cell, String label, String valueText, Color color) {
    final labelStyle = TextStyle(fontFamily: 'Arial', fontSize: 10, fontWeight: FontWeight.w700, color: color.withOpacity(0.85), letterSpacing: 0.6);
    final valueStyle = TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white);

    final labelTp = TextPainter(text: TextSpan(text: label, style: labelStyle), textDirection: TextDirection.ltr)..layout();
    final valueTp = TextPainter(text: TextSpan(text: valueText, style: valueStyle), textDirection: TextDirection.ltr)..layout();

    final cx = cell.left + cell.width / 2;
    final cy = cell.top + cell.height / 2;
    labelTp.paint(canvas, Offset(cx - labelTp.width / 2, cy - labelTp.height - 2));
    valueTp.paint(canvas, Offset(cx - valueTp.width / 2, cy + 2));
  }

  // ── Watermark ──────────────────────────────────────────────────────────────

  static void _paintDiagonalWatermark(Canvas canvas, Size size, String text) {
    final style = TextStyle(
      fontFamily: 'Arial', fontSize: 30, fontWeight: FontWeight.w900,
      color: Colors.white.withOpacity(0.055), letterSpacing: 4,
    );
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.4);

    final stepX = tp.width + 60;
    final stepY = tp.height + 50;
    for (double y = -size.height; y < size.height; y += stepY) {
      for (double x = -size.width; x < size.width; x += stepX) {
        tp.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  static void _paintCornerTag(Canvas canvas, Size size, String text) {
    final style = TextStyle(
      fontFamily: 'Arial', fontSize: 12, fontWeight: FontWeight.w800,
      color: Colors.white.withOpacity(0.5), letterSpacing: 1.2,
    );
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    canvas.drawRect(
      Rect.fromLTWH(size.width - tp.width - 22, size.height - 28, tp.width + 14, 20),
      Paint()..color = const Color(0x55000000),
    );
    tp.paint(canvas, Offset(size.width - tp.width - 15, size.height - 24));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static void _dash(Canvas canvas, double x0, double x1, double y, Paint paint, {double d = 6, double g = 4}) {
    double x = x0;
    while (x < x1) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + d, x1), y), paint);
      x += d + g;
    }
  }

  static void _text(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, offset);
  }

  static String _fmtPrice(double p) {
    if (p >= 1000) return p.toStringAsFixed(2);
    if (p >= 10) return p.toStringAsFixed(3);
    return p.toStringAsFixed(5);
  }

  static String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}  ${two(now.hour)}:${two(now.minute)}';
  }
}
