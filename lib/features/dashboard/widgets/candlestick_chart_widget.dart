import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../models/analysis_result.dart';
import '../models/asset_model.dart';
import '../models/candle_model.dart';
import '../providers/dashboard_provider.dart';

class CandlestickChartWidget extends StatelessWidget {
  const CandlestickChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final result   = provider.result;
    final asset    = provider.selectedAsset;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChartHeader(
            asset: asset,
            timeframe: provider.selectedTimeframe,
            result: result,
          ),
          Expanded(
            child: _buildBody(result, provider.isLoading),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AnalysisResult? result, bool isLoading) {
    if (isLoading) return const _LoadingState();
    if (result == null || result.candles.isEmpty) return const _EmptyState();
    return _ChartCanvas(result: result);
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _ChartHeader extends StatelessWidget {
  const _ChartHeader({
    required this.asset,
    required this.timeframe,
    required this.result,
  });
  final Asset asset;
  final Timeframe timeframe;
  final AnalysisResult? result;

  @override
  Widget build(BuildContext context) {
    final lastClose = (result?.candles.isNotEmpty ?? false)
        ? result!.candles.last.close
        : null;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            asset.symbol,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 10),
          _TfBadge(tf: timeframe),
          if (lastClose != null) ...[
            const SizedBox(width: 12),
            Text(
              _fmt(lastClose, asset),
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const Spacer(),
          if (result != null && result!.signal != SignalType.wait)
            _SignalChip(signal: result!.signal),
        ],
      ),
    );
  }

  String _fmt(double p, Asset a) {
    final dec = a.pipValue < 0.01 ? 5 : (a.pipValue < 0.1 ? 3 : 2);
    return p.toStringAsFixed(dec);
  }
}

class _TfBadge extends StatelessWidget {
  const _TfBadge({required this.tf});
  final Timeframe tf;

  @override
  Widget build(BuildContext context) {
    final label = switch (tf) {
      Timeframe.m1  => 'M1',
      Timeframe.m5  => 'M5',
      Timeframe.m15 => 'M15',
      Timeframe.m30 => 'M30',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.gold.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.signal});
  final SignalType signal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: signal.primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: signal.primaryColor.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        signal.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: signal.primaryColor,
        ),
      ),
    );
  }
}

// ── States ─────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.candlestick_chart_outlined,
              color: AppColors.textMuted, size: 38),
          const SizedBox(height: 10),
          Text('Run analysis to view chart',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
          ),
          const SizedBox(height: 10),
          Text('Fetching chart data...',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ── Canvas ─────────────────────────────────────────────────────────────────────

class _ChartCanvas extends StatelessWidget {
  const _ChartCanvas({required this.result});
  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CandlePainter(result: result),
      child: const SizedBox.expand(),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────

class _CandlePainter extends CustomPainter {
  _CandlePainter({required this.result});
  final AnalysisResult result;

  static const _bullCol = Color(0xFF00D68F);
  static const _bearCol = Color(0xFFFF3B5C);
  static const _axisW   = 64.0;

  @override
  void paint(Canvas canvas, Size size) {
    final candles = result.candles;
    if (candles.isEmpty) return;

    final chartW = size.width - _axisW;
    final chartH = size.height;
    if (chartW <= 0 || chartH <= 0) return;

    // ── Price range — based on candles only, never distorted by SL/TP ────────
    double lo = candles.map((c) => c.low).reduce(math.min);
    double hi = candles.map((c) => c.high).reduce(math.max);
    final pad   = (hi - lo) * 0.12;
    lo = lo - pad;
    hi = hi + pad;
    final range = hi - lo;
    if (range <= 0) return;

    double toY(double p) => chartH * (1.0 - (p - lo) / range);

    // ── Clip to chart area ─────────────────────────────────────────────────
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, chartW, chartH));

    // ── Grid ───────────────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      canvas.drawLine(
          Offset(0, chartH * i / 4), Offset(chartW, chartH * i / 4), gridPaint);
    }

    // ── Pivot lines ────────────────────────────────────────────────────────
    final supplyPaint = Paint()
      ..color = _bearCol.withOpacity(0.22)
      ..strokeWidth = 0.8;
    final demandPaint = Paint()
      ..color = _bullCol.withOpacity(0.22)
      ..strokeWidth = 0.8;

    for (final ph in result.pivotHighs) {
      final y = toY(ph);
      if (y >= 0 && y <= chartH) _dash(canvas, 0, chartW, y, supplyPaint);
    }
    for (final pl in result.pivotLows) {
      final y = toY(pl);
      if (y >= 0 && y <= chartH) _dash(canvas, 0, chartW, y, demandPaint);
    }

    // ── Candles ────────────────────────────────────────────────────────────
    final n  = candles.length;
    final cW = chartW / n;
    final bW = (cW * 0.55).clamp(1.5, 10.0);

    for (int i = 0; i < n; i++) {
      final c    = candles[i];
      final cx   = i * cW + cW / 2;
      final bull = c.close >= c.open;
      final col  = bull ? _bullCol : _bearCol;

      canvas.drawLine(Offset(cx, toY(c.high)), Offset(cx, toY(c.low)),
          Paint()..color = col..strokeWidth = 0.8);

      final top = toY(bull ? c.close : c.open);
      final bot = toY(bull ? c.open  : c.close);
      final h   = (bot - top).abs();

      if (h < 1.0) {
        canvas.drawLine(Offset(cx - bW / 2, top), Offset(cx + bW / 2, top),
            Paint()..color = col..strokeWidth = 1);
      } else {
        canvas.drawRect(Rect.fromLTRB(cx - bW / 2, top, cx + bW / 2, bot),
            Paint()..color = col);
      }
    }

    canvas.restore();

    // ── Price axis ─────────────────────────────────────────────────────────
    for (int i = 0; i <= 4; i++) {
      final price = hi - range * i / 4;
      final y     = chartH * i / 4;
      _text(canvas, _fmtPrice(price), Offset(chartW + 4, y - 5),
          const TextStyle(
              fontFamily: 'monospace', fontSize: 9, color: Color(0xFF55556A)));
    }

    // ── Entry / SL / TP lines ──────────────────────────────────────────────
    if (result.signal != SignalType.wait) {
      _level(canvas, chartW, chartH, toY(result.entryPoint),
          const Color(0xFFD4AF37), 'Entry');
      _level(canvas, chartW, chartH, toY(result.stopLoss),
          _bearCol, 'SL');
      _level(canvas, chartW, chartH, toY(result.takeProfit),
          _bullCol, 'TP');
    }
  }

  String _fmtPrice(double p) {
    if (p >= 1000) return p.toStringAsFixed(2);
    if (p >= 10)   return p.toStringAsFixed(3);
    return p.toStringAsFixed(5);
  }

  void _dash(Canvas canvas, double x0, double x1, double y, Paint paint,
      {double d = 6, double g = 4}) {
    double x = x0;
    while (x < x1) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + d, x1), y), paint);
      x += d + g;
    }
  }

  void _level(Canvas canvas, double chartW, double chartH,
      double y, Color color, String label) {
    if (y < -2 || y > chartH + 2) return;
    _dash(canvas, 0, chartW, y,
        Paint()..color = color..strokeWidth = 1.2, d: 10, g: 5);

    final style = TextStyle(
      fontFamily: 'monospace', fontSize: 9,
      fontWeight: FontWeight.bold, color: color,
    );
    final tp = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgR = Rect.fromLTWH(
      chartW + 4, y - tp.height / 2 - 2, tp.width + 8, tp.height + 4,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(bgR, const Radius.circular(2)),
        Paint()..color = color.withOpacity(0.15));
    tp.paint(canvas, Offset(chartW + 8, y - tp.height / 2));
  }

  void _text(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CandlePainter old) => old.result != result;
}
