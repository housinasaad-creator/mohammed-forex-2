import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../core/localization/app_strings.dart';
import '../features/dashboard/models/asset_model.dart';
import '../features/dashboard/models/analysis_result.dart';
import '../features/dashboard/models/candle_model.dart';
import 'news_calendar_service.dart';

class _SessionInfo {
  final String name;    // 'London/NY', 'London', 'New York', 'Tokyo', 'Sydney', 'London Lunch'
  final String warning; // '' = no warning; non-empty = warning text
  final double quality; // 0.0-1.0 for accuracy weighting
  const _SessionInfo(this.name, this.warning, this.quality);
}

class AnalysisService {
  AnalysisService._();

  // ── Market hours ───────────────────────────────────────────────────────────

  static bool _isMarketClosed() {
    final now = DateTime.now().toUtc();
    final wd  = now.weekday;
    if (wd == DateTime.saturday) return true;
    if (wd == DateTime.sunday  && now.hour < 21)  return true;
    if (wd == DateTime.friday  && now.hour >= 22) return true;
    return false;
  }

  // ── Session detection ──────────────────────────────────────────────────────
  // Sessions never stop analysis — only add a warning to factors.

  static _SessionInfo _sessionInfo(AppStrings s) {
    final now = DateTime.now().toUtc();
    final h   = now.hour + now.minute / 60.0;

    // London/NY overlap 13:00-17:00 — best liquidity
    if (h >= 13.0 && h < 17.0) {
      return const _SessionInfo('London/NY', '', 1.0);
    }
    // London morning 08:00-12:00
    if (h >= 8.0 && h < 12.0) {
      return const _SessionInfo('London', '', 0.85);
    }
    // London Lunch 12:00-13:00 — low liquidity warning
    if (h >= 12.0 && h < 13.0) {
      return _SessionInfo('London Lunch', s.sessionLunchWarning, 0.4);
    }
    // New York afternoon 17:00-22:00
    if (h >= 17.0 && h < 22.0) {
      return const _SessionInfo('New York', '', 0.75);
    }
    // Tokyo 00:00-08:00 (London catches 08:00+ first)
    if (h < 8.0) {
      return _SessionInfo('Tokyo', s.sessionTokyoWarning, 0.3);
    }
    // Sydney 22:00-24:00
    return _SessionInfo('Sydney', s.sessionSydneyWarning, 0.3);
  }

  // ── Candlestick pattern detection ──────────────────────────────────────────

  static String _detectPattern(List<Candle> candles) {
    if (candles.length < 2) return '';
    final curr = candles.last;
    final prev = candles[candles.length - 2];

    final range = curr.high - curr.low;
    if (range <= 0) return '';

    final body          = (curr.close - curr.open).abs();
    final upperWick     = curr.high - math.max(curr.open, curr.close);
    final lowerWick     = math.min(curr.open, curr.close) - curr.low;
    final bodyRatio     = body / range;
    final upperRatio    = upperWick / range;
    final lowerRatio    = lowerWick / range;

    // Doji: body < 5% of range, wicks on both sides
    if (bodyRatio < 0.05 && upperRatio > 0.1 && lowerRatio > 0.1) return 'Doji';

    // Pin Bar: body ≤30%, dominant wick ≥60%
    if (lowerRatio >= 0.6 && bodyRatio <= 0.3) return 'BullishPinBar';
    if (upperRatio >= 0.6 && bodyRatio <= 0.3) return 'BearishPinBar';

    // Engulfing: current body engulfs previous body by ≥10%
    final prevBody     = (prev.close - prev.open).abs();
    if (prevBody <= 0) return '';
    final currHigh     = math.max(curr.open, curr.close);
    final currLow      = math.min(curr.open, curr.close);
    final prevHigh     = math.max(prev.open, prev.close);
    final prevLow      = math.min(prev.open, prev.close);

    if (curr.isBullish && !prev.isBullish &&
        currHigh > prevHigh && currLow < prevLow && body >= prevBody * 1.1) {
      return 'BullishEngulfing';
    }
    if (!curr.isBullish && prev.isBullish &&
        currHigh > prevHigh && currLow < prevLow && body >= prevBody * 1.1) {
      return 'BearishEngulfing';
    }
    return '';
  }

  // ── Bollinger Bands (20-period, 2σ) ───────────────────────────────────────

  static Map<String, double> _calcBollinger(List<double> closes, {int period = 20}) {
    final n = closes.length;
    if (n < period) {
      final avg = closes.isEmpty ? 0.0 : closes.reduce((a, b) => a + b) / n;
      return {'upper': avg, 'middle': avg, 'lower': avg};
    }
    final slice = closes.sublist(n - period);
    final sma = slice.reduce((a, b) => a + b) / period;
    final variance = slice.map((v) => (v - sma) * (v - sma)).reduce((a, b) => a + b) / period;
    final std = math.sqrt(variance);
    return {'upper': sma + 2 * std, 'middle': sma, 'lower': sma - 2 * std};
  }

  // ── RSI series from closes (Wilder's smoothing) ───────────────────────────

  static List<double> _calcRsiSeries(List<double> closes, {int period = 14}) {
    final n = closes.length;
    if (n < period + 1) return List.filled(n, 50.0);

    final out = List<double>.filled(n, 50.0);
    double avgGain = 0, avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final d = closes[i] - closes[i - 1];
      if (d > 0) avgGain += d; else avgLoss -= d;
    }
    avgGain /= period;
    avgLoss /= period;
    out[period] = avgLoss == 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss);

    for (int i = period + 1; i < n; i++) {
      final d = closes[i] - closes[i - 1];
      avgGain = (avgGain * (period - 1) + (d > 0 ? d : 0)) / period;
      avgLoss = (avgLoss * (period - 1) + (d < 0 ? -d : 0)) / period;
      out[i] = avgLoss == 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss);
    }
    return out;
  }

  // ── RSI Divergence detection ───────────────────────────────────────────────

  static (bool bullDiv, bool bearDiv) _detectDivergence(
      List<double> closes, List<double> rsiSeries) {
    if (closes.length < 15) return (false, false);

    final lows  = <int>[];
    final highs = <int>[];
    for (int i = 2; i < closes.length - 2; i++) {
      if (closes[i] < closes[i-1] && closes[i] < closes[i-2] &&
          closes[i] < closes[i+1] && closes[i] < closes[i+2]) lows.add(i);
      if (closes[i] > closes[i-1] && closes[i] > closes[i-2] &&
          closes[i] > closes[i+1] && closes[i] > closes[i+2]) highs.add(i);
    }

    // Bullish divergence: last 2 swing lows — price lower but RSI higher
    bool bullDiv = false;
    if (lows.length >= 2) {
      final i1 = lows[lows.length - 2], i2 = lows.last;
      bullDiv = closes[i2] < closes[i1] && rsiSeries[i2] > rsiSeries[i1] + 2;
    }

    // Bearish divergence: last 2 swing highs — price higher but RSI lower
    bool bearDiv = false;
    if (highs.length >= 2) {
      final i1 = highs[highs.length - 2], i2 = highs.last;
      bearDiv = closes[i2] > closes[i1] && rsiSeries[i2] < rsiSeries[i1] - 2;
    }

    return (bullDiv, bearDiv);
  }

  // ── SMC: Order Blocks, FVG, BOS/CHoCH, Liquidity Sweeps ───────────────────

  static Map<String, String> _detectSmc(
      List<Candle> candles, List<double> pivotHighs, List<double> pivotLows) {
    if (candles.length < 6) {
      return {'orderBlock': '', 'fvg': '', 'bos': '', 'liqSweep': ''};
    }
    final price  = candles.last.close;
    final start  = math.max(0, candles.length - 35);

    // ── Order Blocks ────────────────────────────────────────────────────────
    String orderBlock = '';
    for (int i = candles.length - 4; i >= start && orderBlock.isEmpty; i--) {
      if (i + 3 >= candles.length) continue;
      final c = candles[i];
      if (!c.isBullish && candles[i+1].isBullish && candles[i+2].isBullish &&
          candles[i+2].close > c.high) {
        orderBlock = 'Bullish OB @ ${_fmtLv(math.min(c.open, c.close))}–${_fmtLv(math.max(c.open, c.close))}';
      } else if (c.isBullish && !candles[i+1].isBullish && !candles[i+2].isBullish &&
                 candles[i+2].close < c.low) {
        orderBlock = 'Bearish OB @ ${_fmtLv(math.min(c.open, c.close))}–${_fmtLv(math.max(c.open, c.close))}';
      }
    }

    // ── Fair Value Gaps ──────────────────────────────────────────────────────
    String fvg = '';
    for (int i = math.max(0, candles.length - 20); i < candles.length - 2 && fvg.isEmpty; i++) {
      final c0 = candles[i], c2 = candles[i + 2];
      if (c0.high < c2.low) {
        fvg = 'Bullish FVG ${_fmtLv(c0.high)}–${_fmtLv(c2.low)}';
      } else if (c0.low > c2.high) {
        fvg = 'Bearish FVG ${_fmtLv(c2.high)}–${_fmtLv(c0.low)}';
      }
    }

    // ── BOS / CHoCH ──────────────────────────────────────────────────────────
    String bos = '';
    if (pivotHighs.length >= 2 && pivotLows.length >= 2) {
      final lastH = pivotHighs.last, prevH = pivotHighs[pivotHighs.length - 2];
      final lastL = pivotLows.last,  prevL = pivotLows[pivotLows.length - 2];
      if (price > lastH && lastH > prevH)         bos = 'BOS ↑ (Bullish Break)';
      else if (price < lastL && lastL < prevL)    bos = 'BOS ↓ (Bearish Break)';
      else if (price > prevH && lastH < prevH)    bos = 'CHoCH ↑ (Bullish Flip)';
      else if (price < prevL && lastL > prevL)    bos = 'CHoCH ↓ (Bearish Flip)';
    }

    // ── Liquidity Sweeps ─────────────────────────────────────────────────────
    String liqSweep = '';
    if (pivotHighs.isNotEmpty && pivotLows.isNotEmpty) {
      for (int i = math.max(0, candles.length - 6); i < candles.length && liqSweep.isEmpty; i++) {
        final c = candles[i];
        final recentLow  = pivotLows.last;
        final recentHigh = pivotHighs.last;
        if (c.low < recentLow && c.close > recentLow) {
          liqSweep = 'Bullish Sweep @ ${_fmtLv(recentLow)}';
        } else if (c.high > recentHigh && c.close < recentHigh) {
          liqSweep = 'Bearish Sweep @ ${_fmtLv(recentHigh)}';
        }
      }
    }

    return {'orderBlock': orderBlock, 'fvg': fvg, 'bos': bos, 'liqSweep': liqSweep};
  }

  static String _fmtLv(double p) {
    if (p >= 1000) return p.toStringAsFixed(2);
    if (p >= 10)   return p.toStringAsFixed(3);
    return p.toStringAsFixed(5);
  }

  // ── Smart Trade Note (AI-fallback, rule-based) ────────────────────────────

  static String _buildTradeNote({
    required SignalType signal,
    required Timeframe timeframe,
    required double accuracy,
    required bool bullDiv,
    required bool bearDiv,
    required String bos,
    required String fvg,
    required String orderBlock,
    required String liqSweep,
    required String pattern,
    required Map<String, double> bb,
    required double price,
    required double rsi,
    required double atr,
    required Asset asset,
    required AppStrings s,
  }) {
    if (signal == SignalType.wait) {
      return s.t(
        ar: '⏸ لا توجد إشارة — انتظر تأكيداً أقوى قبل الدخول.',
        en: '⏸ No signal — wait for stronger confirmation before entering.',
        tr: '⏸ Sinyal yok — giriş için daha güçlü onay bekleyin.',
      );
    }

    final isBuy = signal == SignalType.buy;

    // Base exit time from timeframe
    int baseMin = switch (timeframe) {
      Timeframe.m1  => 3,
      Timeframe.m5  => 15,
      Timeframe.m15 => 35,
      Timeframe.m30 => 70,
    };

    int score = 0;
    final reasons = <String>[];

    if (bos.isNotEmpty && ((isBuy && bos.contains('↑')) || (!isBuy && bos.contains('↓')))) {
      score += 2;
      reasons.add(s.t(ar: 'كسر هيكل', en: 'BOS', tr: 'BOS'));
    }
    if (orderBlock.isNotEmpty && ((isBuy && orderBlock.contains('Bullish')) || (!isBuy && orderBlock.contains('Bearish')))) {
      score += 2;
      reasons.add(s.t(ar: 'أوردر بلوك', en: 'Order Block', tr: 'Order Block'));
    }
    if (liqSweep.isNotEmpty && ((isBuy && liqSweep.contains('Bullish')) || (!isBuy && liqSweep.contains('Bearish')))) {
      score += 1;
      reasons.add(s.t(ar: 'اصطياد سيولة', en: 'Liquidity Sweep', tr: 'Likidite Süpürmesi'));
    }
    if (fvg.isNotEmpty && ((isBuy && fvg.contains('Bullish')) || (!isBuy && fvg.contains('Bearish')))) {
      score += 1;
      reasons.add(s.t(ar: 'فجوة سعرية (FVG)', en: 'FVG', tr: 'FVG'));
    }
    if ((isBuy && bullDiv) || (!isBuy && bearDiv)) {
      score += 2;
      reasons.add(s.t(ar: 'انحراف RSI', en: 'RSI Divergence', tr: 'RSI Uyumsuzluğu'));
    }
    if ((isBuy && (pattern == 'BullishPinBar' || pattern == 'BullishEngulfing')) ||
        (!isBuy && (pattern == 'BearishPinBar' || pattern == 'BearishEngulfing'))) {
      score += 1;
      reasons.add(s.t(ar: 'نمط شموع', en: 'Candle Pattern', tr: 'Mum Formasyonu'));
    }

    // BB position
    final bbRange = bb['upper']! - bb['lower']!;
    final bbPos   = bbRange > 0 ? (price - bb['lower']!) / bbRange : 0.5;
    if (isBuy && bbPos < 0.15) {
      score += 1;
      reasons.add(s.t(ar: 'نطاق بولينجر السفلي', en: 'Lower BB', tr: 'Alt BB'));
    } else if (!isBuy && bbPos > 0.85) {
      score += 1;
      reasons.add(s.t(ar: 'نطاق بولينجر العلوي', en: 'Upper BB', tr: 'Üst BB'));
    }

    // Adjust timing: strong confluence → faster expected move
    if (score >= 6)       baseMin = (baseMin * 0.65).round();
    else if (score >= 4)  baseMin = (baseMin * 0.80).round();
    else if (score >= 2)  baseMin = (baseMin * 0.90).round();
    else                  baseMin = (baseMin * 1.20).round();

    // ATR volatility adjustment
    final atrPips = atr / asset.pipValue;
    if (atrPips > 25)     baseMin = (baseMin * 0.80).round();
    else if (atrPips < 4) baseMin = (baseMin * 1.20).round();

    baseMin = baseMin.clamp(2, 120);

    final reasonStr = reasons.isEmpty ? '' : reasons.take(3).join(' + ');
    final prefix = s.t(ar: '⏱ إدارة الصفقة', en: '⏱ Trade Management', tr: '⏱ Pozisyon Yönetimi');

    if (reasonStr.isEmpty) {
      return s.t(
        ar: '$prefix: إشارة دون توافق SMC واضح. أغلق الصفقة بعد $baseMin دقيقة إذا لم يُحقَّق الهدف.',
        en: '$prefix: Signal without clear SMC confluence. Close after $baseMin minutes if TP not reached.',
        tr: '$prefix: Net SMC uyumu olmayan sinyal. TP $baseMin dakikada ulaşılmazsa kapat.',
      );
    }

    return s.t(
      ar: '$prefix: بناءً على $reasonStr — أغلق الصفقة بعد $baseMin دقيقة إذا لم يُحقَّق الهدف.',
      en: '$prefix: Based on $reasonStr — close trade after $baseMin minutes if TP not reached.',
      tr: '$prefix: $reasonStr temelinde — $baseMin dakika sonra TP ulaşılmazsa kapat.',
    );
  }

  // ── ATR(14) ────────────────────────────────────────────────────────────────

  static double _calculateAtr(List<Candle> candles, {int period = 14}) {
    if (candles.length < period + 1) return 0.0;
    final slice = candles.sublist(candles.length - period - 1);
    double sum = 0;
    for (int i = 1; i <= period; i++) {
      final c  = slice[i];
      final pc = slice[i - 1].close;
      sum += math.max(c.high - c.low,
             math.max((c.high - pc).abs(), (c.low - pc).abs()));
    }
    return sum / period;
  }

  // ── Dynamic accuracy 0-100% ────────────────────────────────────────────────
  // All 6 factors perfectly aligned → 100%.

  static double _dynamicAccuracy({
    required SignalType signal,
    required double rsi,
    required bool hasMacd,
    required double macdHisto,
    required double macdValue,
    required double macdSignalLine,
    required String htfLabel,
    required ZoneType zone,
    required _SessionInfo session,
    required String pattern,
    required Asset asset,
    required double atr,
    // Deep analysis
    required bool bullDiv,
    required bool bearDiv,
    required Map<String, double> bb,
    required double price,
    required String smcBos,
    required String smcOb,
    required String smcFvg,
    required String smcLiqSweep,
  }) {
    if (signal == SignalType.wait) return 50.0;
    final buy = signal == SignalType.buy;
    double pts = 0.0;

    // RSI — max 20
    if (buy) {
      if (rsi < 32)                   pts += 20;
      else if (rsi < 38)              pts += 14;
      else if (rsi > 52 && rsi < 62)  pts += 8;
      else if (rsi > 38 && rsi < 52)  pts += 4;
      else                            pts += 1;
    } else {
      if (rsi > 68)                   pts += 20;
      else if (rsi > 62)              pts += 14;
      else if (rsi > 38 && rsi < 48)  pts += 8;
      else if (rsi > 48 && rsi < 62)  pts += 4;
      else                            pts += 1;
    }

    // MACD — max 15
    if (hasMacd) {
      final bullish = macdHisto > 0 && macdValue > macdSignalLine;
      final bearish = macdHisto < 0 && macdValue < macdSignalLine;
      if (buy)  { pts += bullish ? 15 : bearish ? 2 : 6; }
      else      { pts += bearish ? 15 : bullish ? 2 : 6; }
    } else {
      pts += 5;
    }

    // HTF — max 20
    if (buy) {
      if (htfLabel == 'Bullish')       pts += 20;
      else if (htfLabel == 'Sideways') pts += 8;
    } else {
      if (htfLabel == 'Bearish')       pts += 20;
      else if (htfLabel == 'Sideways') pts += 8;
    }

    // Zone — max 20
    if (buy) {
      switch (zone) {
        case ZoneType.strongDemand: pts += 20;
        case ZoneType.weakDemand:   pts += 12;
        case ZoneType.neutral:      pts += 6;
        case ZoneType.weakSupply:   pts += 2;
        case ZoneType.strongSupply: pts += 0;
      }
    } else {
      switch (zone) {
        case ZoneType.strongSupply: pts += 20;
        case ZoneType.weakSupply:   pts += 12;
        case ZoneType.neutral:      pts += 6;
        case ZoneType.weakDemand:   pts += 2;
        case ZoneType.strongDemand: pts += 0;
      }
    }

    // Session — max 15
    pts += (session.quality * 15).clamp(0, 15);

    // Pattern — max 10
    final patBull = pattern == 'BullishPinBar' || pattern == 'BullishEngulfing';
    final patBear = pattern == 'BearishPinBar' || pattern == 'BearishEngulfing';
    if (buy)  { pts += patBull ? 10 : patBear ? 0 : 3; }
    else      { pts += patBear ? 10 : patBull ? 0 : 3; }

    // ATR micro-bonus
    if (atr > 0) {
      final atrPips = atr / asset.pipValue;
      if (atrPips > 15) pts += 3;
      else if (atrPips < 4) pts -= 3;
    }

    // ── Deep Analysis Bonuses (top-up, clamped at 100) ──────────────────────
    // RSI Divergence — +10
    if ((buy && bullDiv) || (!buy && bearDiv)) pts += 10;

    // Bollinger Band position — +8
    final bbRange = bb['upper']! - bb['lower']!;
    if (bbRange > 0) {
      final bbPos = (price - bb['lower']!) / bbRange;
      if (buy  && bbPos < 0.12) pts += 8;
      else if (buy  && bbPos < 0.25) pts += 5;
      else if (!buy && bbPos > 0.88) pts += 8;
      else if (!buy && bbPos > 0.75) pts += 5;
      else if (buy  && bbPos > 0.80) pts -= 4;
      else if (!buy && bbPos < 0.20) pts -= 4;
    }

    // SMC — up to +12
    if (smcBos.isNotEmpty) {
      if ((buy && smcBos.contains('↑')) || (!buy && smcBos.contains('↓'))) pts += 6;
      else pts -= 3;
    }
    if (smcOb.isNotEmpty) {
      if ((buy && smcOb.contains('Bullish')) || (!buy && smcOb.contains('Bearish'))) pts += 4;
    }
    if (smcFvg.isNotEmpty) {
      if ((buy && smcFvg.contains('Bullish')) || (!buy && smcFvg.contains('Bearish'))) pts += 2;
    }
    if (smcLiqSweep.isNotEmpty) {
      if ((buy && smcLiqSweep.contains('Bullish')) || (!buy && smcLiqSweep.contains('Bearish'))) pts += 3;
    }

    return pts.clamp(0.0, 100.0);
  }

  // ── Analysis summary builder ───────────────────────────────────────────────

  static String _makeSummary({
    required SignalType signal,
    required double accuracy,
    required double rsi,
    required double macdHisto,
    required String htfLabel,
    required ZoneType zone,
    required String sessionName,
    required String sessionWarning,
    required String pattern,
    required AppStrings s,
  }) {
    final acc = accuracy.toStringAsFixed(0);
    if (signal == SignalType.wait) {
      return s.t(
        ar: 'لا توجد إشارة واضحة حالياً. السوق يفتقر إلى توافق كافٍ بين المؤشرات. انتظر تأكيداً أقوى قبل الدخول.',
        en: 'No clear signal at this time. The market lacks sufficient indicator confluence. Wait for stronger confirmation before entering.',
        tr: 'Şu an net bir sinyal yok. Piyasa yeterli gösterge uyumu sağlamıyor. Giriş yapmadan önce daha güçlü onay bekleyin.',
      );
    }

    final dir = s.t(
      ar: signal == SignalType.buy ? 'شراء' : 'بيع',
      en: signal == SignalType.buy ? 'BUY' : 'SELL',
      tr: signal == SignalType.buy ? 'AL'  : 'SAT',
    );
    final strength = accuracy >= 80
        ? s.t(ar: 'قوية', en: 'strong', tr: 'güçlü')
        : accuracy >= 65
            ? s.t(ar: 'متوسطة', en: 'moderate', tr: 'orta')
            : s.t(ar: 'ضعيفة', en: 'weak', tr: 'zayıf');

    final isBuy = signal == SignalType.buy;
    final rsiPart = (isBuy ? rsi < 38 : rsi > 62)
        ? s.t(ar: 'RSI في منطقة الانعكاس', en: 'RSI in reversal zone', tr: 'RSI dönüş bölgesinde')
        : s.t(ar: 'RSI في منطقة الزخم', en: 'RSI in momentum zone', tr: 'RSI momentum bölgesinde');

    final htfPart = htfLabel == 'Sideways'
        ? s.t(ar: 'H1 جانبي', en: 'H1 ranging', tr: 'H1 yatay')
        : s.t(
            ar: 'H1 ${htfLabel == "Bullish" ? "صاعد" : "هابط"}',
            en: 'H1 $htfLabel',
            tr: 'H1 ${htfLabel == "Bullish" ? "yükseliş" : "düşüş"}',
          );

    final zonePart = switch (zone) {
      ZoneType.strongDemand => s.t(ar: 'منطقة طلب قوية', en: 'strong demand zone', tr: 'güçlü talep bölgesi'),
      ZoneType.weakDemand   => s.t(ar: 'منطقة طلب', en: 'demand zone', tr: 'talep bölgesi'),
      ZoneType.strongSupply => s.t(ar: 'منطقة عرض قوية', en: 'strong supply zone', tr: 'güçlü arz bölgesi'),
      ZoneType.weakSupply   => s.t(ar: 'منطقة عرض', en: 'supply zone', tr: 'arz bölgesi'),
      ZoneType.neutral      => s.t(ar: 'منطقة محايدة', en: 'neutral zone', tr: 'tarafsız bölge'),
    };

    var line1 = s.t(
      ar: 'إشارة $dir $strength ($acc٪) — $rsiPart، $htfPart، $zonePart.',
      en: '$strength $dir signal ($acc%) — $rsiPart, $htfPart, $zonePart.',
      tr: '$strength $dir sinyali ($acc%) — $rsiPart, $htfPart, $zonePart.',
    );

    var line2 = '';
    if (pattern.isNotEmpty) {
      final pName = s.patternName(pattern);
      final confirms = (isBuy && (pattern == 'BullishPinBar' || pattern == 'BullishEngulfing')) ||
                       (!isBuy && (pattern == 'BearishPinBar' || pattern == 'BearishEngulfing'));
      line2 = confirms
          ? s.t(ar: ' نمط $pName يؤكد الإشارة.', en: ' $pName confirms the signal.', tr: ' $pName sinyali doğruluyor.')
          : s.t(ar: ' نمط $pName يخالف الإشارة — توخّ الحذر.', en: ' $pName conflicts with the signal — be cautious.', tr: ' $pName sinyal ile çelişiyor — dikkatli olun.');
    }

    final line3 = sessionWarning.isNotEmpty
        ? s.t(ar: ' ⚠️ $sessionWarning.', en: ' ⚠️ $sessionWarning.', tr: ' ⚠️ $sessionWarning.')
        : s.t(
            ar: ' جلسة $sessionName — سيولة جيدة، ظروف مثالية للدخول.',
            en: ' $sessionName session — good liquidity, favourable entry conditions.',
            tr: ' $sessionName seansı — iyi likidite, giriş için uygun koşullar.',
          );

    return '$line1$line2$line3';
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<AnalysisResult> analyze({
    required Asset asset,
    required Timeframe timeframe,
    String lang = 'en',
    double? livePrice,
  }) async {
    final s = AppStrings.of(lang);

    // Market closed check
    if (_isMarketClosed()) return _buildMarketClosedResult(asset, s: s);

    // News freeze check
    final newsFrozen = await NewsCalendarService.checkEconomicCalendarNews(
      tradeTime: DateTime.now(),
      symbol: asset.symbol,
    );
    if (newsFrozen) return _buildWaitResult(asset, s: s);

    await Future.delayed(const Duration(milliseconds: 1200));

    return await _computeSignal(asset, timeframe, s, livePrice);
  }

  // ── Core Signal Engine ─────────────────────────────────────────────────────

  static Future<AnalysisResult> _computeSignal(Asset asset, Timeframe timeframe, AppStrings s, double? livePrice) async {
    // ── Fetch real indicators from Twelvedata ──────────────────────────────
    final realData = await _fetchRealIndicators(asset, timeframe);

    // If API failed, return data error — no random fallback
    if (realData == null) return _buildDataErrorResult(asset, s: s);

    // RSI — real only
    final rsi = (realData['rsi'] as num).toDouble().clamp(0.0, 100.0);

    // MACD — real only; if all zeros the API had no data
    final macdValue  = (realData['macd_value']     as num).toDouble();
    final macdSignal = (realData['macd_signal']    as num).toDouble();
    final macdHisto  = (realData['macd_histogram'] as num).toDouble();
    final hasMacd    = macdValue != 0.0 || macdSignal != 0.0 || macdHisto != 0.0;

    // Higher timeframe trend from EMA50 on H1 — real only
    final htfBias = switch (realData['htf_trend'] as String? ?? 'Sideways') {
      'Bullish' => 0.5,
      'Bearish' => -0.5,
      _         => 0.0,
    };

    // ── Session detection (warning only, never stops analysis) ────────────
    final session = _sessionInfo(s);

    // ── Confluence scoring ─────────────────────────────────────────────────
    // Score >0 = bullish pressure, <0 = bearish pressure
    double score = 0;
    final List<String> factors = [];

    final rsiStr = rsi.toStringAsFixed(1);
    // RSI
    if (rsi < 32) {
      score += 2.0;
      factors.add(s.rsiOversold(rsiStr));
    } else if (rsi > 68) {
      score -= 2.0;
      factors.add(s.rsiOverbought(rsiStr));
    } else if (rsi > 52 && rsi < 62) {
      score += 0.8;
      factors.add(s.rsiBullMomentum(rsiStr));
    } else if (rsi > 38 && rsi < 48) {
      score -= 0.8;
      factors.add(s.rsiBearPressure(rsiStr));
    } else {
      factors.add(s.rsiNeutral(rsiStr));
    }

    // MACD — only score if data is valid
    if (hasMacd) {
      if (macdHisto > 0 && macdValue > macdSignal) {
        score += 1.5;
        factors.add(s.macdBullish);
      } else if (macdHisto < 0 && macdValue < macdSignal) {
        score -= 1.5;
        factors.add(s.macdBearish);
      } else {
        factors.add(s.macdDiverging);
      }
    }

    // Supply/Demand Zone — real pivot detection only
    final zone = switch (realData['sd_zone'] as String? ?? 'neutral') {
      'strongDemand' => ZoneType.strongDemand,
      'weakDemand'   => ZoneType.weakDemand,
      'weakSupply'   => ZoneType.weakSupply,
      'strongSupply' => ZoneType.strongSupply,
      _              => ZoneType.neutral,
    };
    switch (zone) {
      case ZoneType.strongDemand: score += 2.5; factors.add(s.sdStrongDemand);
      case ZoneType.weakDemand:   score += 1.0; factors.add(s.sdWeakDemand);
      case ZoneType.neutral:                    factors.add(s.sdNeutral);
      case ZoneType.weakSupply:   score -= 1.0; factors.add(s.sdWeakSupply);
      case ZoneType.strongSupply: score -= 2.5; factors.add(s.sdStrongSupply);
    }

    // Higher timeframe trend filter
    String htfLabel;
    if (htfBias > 0.3) {
      score += 1.5;
      htfLabel = 'Bullish';
      factors.add(s.htfBullish);
    } else if (htfBias < -0.3) {
      score -= 1.5;
      htfLabel = 'Bearish';
      factors.add(s.htfBearish);
    } else {
      htfLabel = 'Sideways';
      factors.add(s.htfRanging);
    }

    // ── Determine signal ───────────────────────────────────────────────────
    SignalType signal;
    if (score >= 3.5) {
      signal = SignalType.buy;
    } else if (score <= -3.5) {
      signal = SignalType.sell;
    } else {
      signal = SignalType.wait;
    }

    // ── Price levels ───────────────────────────────────────────────────────
    final spread    = asset.pipValue * 2;
    final slPips    = _slPips(asset, timeframe);
    final tpPips    = slPips * 2.0; // fixed 1:2 RRR
    // Use last real candle close as entry — basePrice is stale
    final _rawCandles = realData['candles'] as List<dynamic>? ?? [];
    final _lastClose  = _rawCandles.isNotEmpty
        ? ((_rawCandles.last as Map<String, dynamic>)['c'] as num).toDouble()
        : null;
    final entry = livePrice ?? _lastClose ?? asset.basePrice;
    double sl, tp;

    if (signal == SignalType.buy) {
      sl = entry - slPips + spread;
      tp = entry + tpPips;
    } else if (signal == SignalType.sell) {
      sl = entry + slPips;
      tp = entry - tpPips + spread;
    } else {
      sl = entry - slPips;
      tp = entry + tpPips;
    }

    final rrr = (tp - entry).abs() / (entry - sl).abs();

    // ── Parse candle data ──────────────────────────────────────────────────
    final candlesRaw = realData['candles'] as List<dynamic>? ?? [];
    final candles = candlesRaw.map((c) {
      final m = c as Map<String, dynamic>;
      return Candle(
        open:  (m['o'] as num).toDouble(),
        high:  (m['h'] as num).toDouble(),
        low:   (m['l'] as num).toDouble(),
        close: (m['c'] as num).toDouble(),
      );
    }).toList();
    final pivotHighs = (realData['pivot_highs'] as List<dynamic>? ?? [])
        .map((v) => (v as num).toDouble()).toList();
    final pivotLows = (realData['pivot_lows'] as List<dynamic>? ?? [])
        .map((v) => (v as num).toDouble()).toList();

    // ── Candlestick pattern + ATR ──────────────────────────────────────────
    final pattern = _detectPattern(candles);
    final atr     = _calculateAtr(candles);

    // ── Deep Analysis ──────────────────────────────────────────────────────
    final closesList = candles.map((c) => c.close).toList();
    final bb         = _calcBollinger(closesList);
    final rsiSeries  = _calcRsiSeries(closesList);
    final (bullDiv, bearDiv) = _detectDivergence(closesList, rsiSeries);
    final smc        = _detectSmc(candles, pivotHighs, pivotLows);
    final smcOB      = smc['orderBlock']!;
    final smcFvg     = smc['fvg']!;
    final smcBos     = smc['bos']!;
    final smcLiqSweep = smc['liqSweep']!;
    final currentPrice = candles.isNotEmpty ? candles.last.close : entry;

    // ── SMC / Divergence / BB added to confluence score ────────────────────
    if (smcBos.isNotEmpty) {
      if (smcBos.contains('↑')) {
        score += 1.0;
        factors.add('📈 BOS: $smcBos');
      } else {
        score -= 1.0;
        factors.add('📉 BOS: $smcBos');
      }
    }
    if (smcOB.isNotEmpty) {
      if (smcOB.contains('Bullish')) { score += 0.8; factors.add('🟩 SMC: $smcOB'); }
      else                          { score -= 0.8; factors.add('🟥 SMC: $smcOB'); }
    }
    if (smcLiqSweep.isNotEmpty) {
      if (smcLiqSweep.contains('Bullish')) { score += 0.5; factors.add('🎯 $smcLiqSweep'); }
      else                                { score -= 0.5; factors.add('🎯 $smcLiqSweep'); }
    }
    if (smcFvg.isNotEmpty) {
      if (smcFvg.contains('Bullish')) { score += 0.4; factors.add('⬛ FVG: $smcFvg'); }
      else                           { score -= 0.4; factors.add('⬛ FVG: $smcFvg'); }
    }
    if (bullDiv) {
      score += 0.8;
      factors.add(s.t(ar: '📊 انحراف RSI صاعد ✓', en: '📊 Bullish RSI Divergence ✓', tr: '📊 Yükseliş RSI Uyumsuzluğu ✓'));
    }
    if (bearDiv) {
      score -= 0.8;
      factors.add(s.t(ar: '📊 انحراف RSI هابط ✓', en: '📊 Bearish RSI Divergence ✓', tr: '📊 Düşüş RSI Uyumsuzluğu ✓'));
    }
    final bbRange = bb['upper']! - bb['lower']!;
    if (bbRange > 0) {
      final bbPos = (currentPrice - bb['lower']!) / bbRange;
      if (bbPos < 0.12) {
        score += 0.5;
        factors.add(s.t(ar: '📉 السعر عند نطاق بولينجر السفلي', en: '📉 Price at Lower Bollinger Band', tr: '📉 Alt Bollinger Bandında'));
      } else if (bbPos > 0.88) {
        score -= 0.5;
        factors.add(s.t(ar: '📈 السعر عند نطاق بولينجر العلوي', en: '📈 Price at Upper Bollinger Band', tr: '📈 Üst Bollinger Bandında'));
      }
    }

    // ── Re-evaluate signal after deep analysis ─────────────────────────────
    if (score >= 3.5)       signal = SignalType.buy;
    else if (score <= -3.5) signal = SignalType.sell;
    else                    signal = SignalType.wait;

    // ── Session warning + pattern + ATR factors ────────────────────────────
    if (session.warning.isNotEmpty) factors.add('⚠️ ${session.warning}');
    if (pattern.isNotEmpty && signal != SignalType.wait) {
      final pf = s.patternFactor(pattern, signal);
      if (pf.isNotEmpty) factors.add(pf);
    }
    final atrStr = s.atrFactor(atr, asset.pipValue);
    if (atrStr.isNotEmpty) factors.add(atrStr);

    // ── Dynamic accuracy (0-100%) ──────────────────────────────────────────
    final accuracy = _dynamicAccuracy(
      signal: signal,
      rsi: rsi,
      hasMacd: hasMacd,
      macdHisto: macdHisto,
      macdValue: macdValue,
      macdSignalLine: macdSignal,
      htfLabel: htfLabel,
      zone: zone,
      session: session,
      pattern: pattern,
      asset: asset,
      atr: atr,
      bullDiv: bullDiv,
      bearDiv: bearDiv,
      bb: bb,
      price: currentPrice,
      smcBos: smcBos,
      smcOb: smcOB,
      smcFvg: smcFvg,
      smcLiqSweep: smcLiqSweep,
    );

    // ── Build summary (عصارة التحليل) ─────────────────────────────────────
    final summary = _makeSummary(
      signal: signal,
      accuracy: accuracy,
      rsi: rsi,
      macdHisto: macdHisto,
      htfLabel: htfLabel,
      zone: zone,
      sessionName: session.name,
      sessionWarning: session.warning,
      pattern: pattern,
      s: s,
    );

    // ── AI narratives ──────────────────────────────────────────────────────
    final sentiment = _buildSentiment(signal, asset, htfLabel, score, s);
    final (claudeBox, aiTradeNote) = await _buildClaudeOpinion(
      asset: asset,
      timeframe: timeframe,
      signal: signal,
      accuracy: accuracy,
      score: score,
      rsi: rsi,
      macdHisto: macdHisto,
      htfLabel: htfLabel,
      zone: zone,
      session: session,
      bullDiv: bullDiv,
      bearDiv: bearDiv,
      bb: bb,
      price: currentPrice,
      smcBos: smcBos,
      smcOb: smcOB,
      smcFvg: smcFvg,
      smcLiqSweep: smcLiqSweep,
      pattern: pattern,
      atrPips: atr / asset.pipValue,
      entry: _roundPrice(entry, asset),
      sl: _roundPrice(sl, asset),
      tp: _roundPrice(tp, asset),
      s: s,
    );

    // Use AI trade note if returned, otherwise local smart note
    final localTradeNote = _buildTradeNote(
      signal: signal,
      timeframe: timeframe,
      accuracy: accuracy,
      bullDiv: bullDiv,
      bearDiv: bearDiv,
      bos: smcBos,
      fvg: smcFvg,
      orderBlock: smcOB,
      liqSweep: smcLiqSweep,
      pattern: pattern,
      bb: bb,
      price: currentPrice,
      rsi: rsi,
      atr: atr,
      asset: asset,
      s: s,
    );
    final tradeNote = aiTradeNote.isNotEmpty ? aiTradeNote : localTradeNote;

    return AnalysisResult(
      signal: signal,
      accuracy: accuracy,
      entryPoint: _roundPrice(entry, asset),
      stopLoss: _roundPrice(sl, asset),
      takeProfit: _roundPrice(tp, asset),
      riskRewardRatio: double.parse(rrr.toStringAsFixed(2)),
      rsi: double.parse(rsi.toStringAsFixed(1)),
      macdValue: macdValue,
      macdSignalLine: macdSignal,
      macdHistogram: macdHisto,
      zone: zone,
      confluenceFactors: factors,
      aiSentiment: sentiment,
      claudeOpinion: claudeBox,
      higherTfTrend: htfLabel,
      analysisTimestamp: _timestamp(),
      candles: candles,
      pivotHighs: pivotHighs,
      pivotLows: pivotLows,
      sessionName: session.name,
      sessionWarning: session.warning,
      summary: summary,
      candlePattern: pattern,
      atrValue: atr,
      bbUpper: bb['upper']!,
      bbMiddle: bb['middle']!,
      bbLower: bb['lower']!,
      rsiBullishDivergence: bullDiv,
      rsiBearishDivergence: bearDiv,
      smcOrderBlock: smcOB,
      smcFvg: smcFvg,
      smcBos: smcBos,
      smcLiqSweep: smcLiqSweep,
      tradeNote: tradeNote,
    );
  }

  // ── Helper builders ────────────────────────────────────────────────────────

  static AnalysisResult _buildMarketClosedResult(Asset asset, {required AppStrings s}) {
    return AnalysisResult(
      signal: SignalType.wait,
      accuracy: 0.0,
      entryPoint: asset.basePrice,
      stopLoss: asset.basePrice,
      takeProfit: asset.basePrice,
      riskRewardRatio: 0.0,
      rsi: 0.0,
      macdValue: 0,
      macdSignalLine: 0,
      macdHistogram: 0,
      zone: ZoneType.neutral,
      confluenceFactors: [s.marketClosedSignal],
      aiSentiment: s.marketClosedSentiment,
      claudeOpinion: s.marketClosedOpinion,
      higherTfTrend: 'Sideways',
      analysisTimestamp: _timestamp(),
    );
  }

  static AnalysisResult _buildDataErrorResult(Asset asset, {required AppStrings s}) {
    return AnalysisResult(
      signal: SignalType.wait,
      accuracy: 0.0,
      entryPoint: asset.basePrice,
      stopLoss: asset.basePrice,
      takeProfit: asset.basePrice,
      riskRewardRatio: 0.0,
      rsi: 0.0,
      macdValue: 0,
      macdSignalLine: 0,
      macdHistogram: 0,
      zone: ZoneType.neutral,
      confluenceFactors: [s.dataErrorSignal],
      aiSentiment: s.marketAmbiguous,
      claudeOpinion: s.dataErrorOpinion,
      higherTfTrend: 'Sideways',
      analysisTimestamp: _timestamp(),
    );
  }

  static AnalysisResult _buildWaitResult(Asset asset, {required AppStrings s}) {
    return AnalysisResult(
      signal: SignalType.wait,
      accuracy: 50.0,
      entryPoint: asset.basePrice,
      stopLoss: asset.basePrice - asset.pipValue * 20,
      takeProfit: asset.basePrice + asset.pipValue * 40,
      riskRewardRatio: 2.0,
      rsi: 50.0,
      macdValue: 0,
      macdSignalLine: 0,
      macdHistogram: 0,
      zone: ZoneType.neutral,
      confluenceFactors: [s.newsFreezeWait],
      aiSentiment: s.marketAmbiguous,
      claudeOpinion: s.claudeOpinion(asset.symbol, '0.00'),
      higherTfTrend: 'Sideways',
      analysisTimestamp: _timestamp(),
    );
  }

  static String _buildSentiment(SignalType sig, Asset asset, String htf, double score, AppStrings s) {
    if (sig == SignalType.buy) {
      return s.aiSentimentBuy(asset.symbol, s.htfTrendLabel(htf), score.toStringAsFixed(1));
    } else if (sig == SignalType.sell) {
      return s.aiSentimentSell(asset.symbol, s.htfTrendLabel(htf), score.abs().toStringAsFixed(1));
    } else {
      return s.aiSentimentWait(asset.symbol);
    }
  }

  static const _tdApiKey = 'a08efe8f43924f5d81688320cbc75a47';

  // Map app symbol (e.g. EURUSD, XAUUSD) → Twelve Data symbol (EUR/USD, XAU/USD)
  static String _toTwelveSymbol(String sym) {
    const map = {
      'EURUSD': 'EUR/USD', 'GBPUSD': 'GBP/USD', 'AUDUSD': 'AUD/USD',
      'NZDUSD': 'NZD/USD', 'USDJPY': 'USD/JPY', 'USDCHF': 'USD/CHF',
      'USDCAD': 'USD/CAD', 'USDCNH': 'USD/CNH',
      'EURGBP': 'EUR/GBP', 'EURJPY': 'EUR/JPY', 'EURCAD': 'EUR/CAD',
      'EURCHF': 'EUR/CHF', 'GBPJPY': 'GBP/JPY', 'GBPCAD': 'GBP/CAD',
      'GBPCHF': 'GBP/CHF', 'AUDJPY': 'AUD/JPY', 'AUDCAD': 'AUD/CAD',
      'AUDNZD': 'AUD/NZD', 'CADJPY': 'CAD/JPY', 'CHFJPY': 'CHF/JPY',
      'NZDJPY': 'NZD/JPY', 'GBPNZD': 'GBP/NZD', 'EURHUF': 'EUR/HUF',
      'USDMXN': 'USD/MXN', 'USDTRY': 'USD/TRY', 'USDPLN': 'USD/PLN',
      'USDZAR': 'USD/ZAR', 'USDSGD': 'USD/SGD',
      'XAUUSD': 'XAU/USD', 'XAGUSD': 'XAG/USD',
      'USOIL':  'WTI/USD', 'UKOIL':  'BRENT/USD', 'NGAS': 'NGAS/USD',
      'BTCUSD': 'BTC/USD', 'ETHUSD': 'ETH/USD',
    };
    final clean = sym.replaceAll('/', '').replaceAll('-', '').toUpperCase();
    return map[clean] ?? sym;
  }

  static Future<Map<String, dynamic>?> _fetchRealIndicators(Asset asset, Timeframe tf) async {
    final symbol = _toTwelveSymbol(asset.symbol);
    final interval = switch (tf) {
      Timeframe.m1  => '1min',
      Timeframe.m5  => '5min',
      Timeframe.m15 => '15min',
      Timeframe.m30 => '30min',
    };
    final base = 'https://api.twelvedata.com';
    final key  = _tdApiKey;

    try {
      // Fetch candles + RSI + MACD + HTF EMA in parallel
      final results = await Future.wait([
        http.get(Uri.parse('$base/time_series?symbol=$symbol&interval=$interval&outputsize=100&apikey=$key')).timeout(const Duration(seconds: 20)),
        http.get(Uri.parse('$base/rsi?symbol=$symbol&interval=$interval&time_period=14&outputsize=1&apikey=$key')).timeout(const Duration(seconds: 20)),
        http.get(Uri.parse('$base/macd?symbol=$symbol&interval=$interval&fast_period=12&slow_period=26&signal_period=9&outputsize=1&apikey=$key')).timeout(const Duration(seconds: 20)),
        http.get(Uri.parse('$base/ema?symbol=$symbol&interval=1h&time_period=50&outputsize=2&apikey=$key')).timeout(const Duration(seconds: 20)),
      ]);

      // ── Candles ──────────────────────────────────────────────────────────────
      final tsJson = json.decode(results[0].body) as Map<String, dynamic>;
      if (tsJson['status'] == 'error' || tsJson['values'] == null) return null;
      final rawValues = (tsJson['values'] as List).reversed.toList();
      final candles  = rawValues.map<Map<String, dynamic>>((v) => {
        'o': double.tryParse(v['open'].toString())  ?? 0.0,
        'h': double.tryParse(v['high'].toString())  ?? 0.0,
        'l': double.tryParse(v['low'].toString())   ?? 0.0,
        'c': double.tryParse(v['close'].toString()) ?? 0.0,
      }).toList();
      final closes = candles.map((c) => c['c'] as double).toList();
      final highs  = candles.map((c) => c['h'] as double).toList();
      final lows   = candles.map((c) => c['l'] as double).toList();

      // ── RSI ───────────────────────────────────────────────────────────────────
      final rsiJson = json.decode(results[1].body) as Map<String, dynamic>;
      final rsi = rsiJson['status'] == 'ok' && rsiJson['values'] != null
          ? (double.tryParse((rsiJson['values'] as List).first['rsi'].toString()) ?? 50.0)
          : 50.0;

      // ── MACD ──────────────────────────────────────────────────────────────────
      final macdJson = json.decode(results[2].body) as Map<String, dynamic>;
      double macdValue = 0, macdSignal = 0, macdHisto = 0;
      if (macdJson['status'] == 'ok' && macdJson['values'] != null) {
        final mv = (macdJson['values'] as List).first;
        macdValue  = double.tryParse(mv['macd'].toString())        ?? 0.0;
        macdSignal = double.tryParse(mv['macd_signal'].toString()) ?? 0.0;
        macdHisto  = double.tryParse(mv['macd_hist'].toString())   ?? 0.0;
      }

      // ── HTF EMA ───────────────────────────────────────────────────────────────
      final emaJson = json.decode(results[3].body) as Map<String, dynamic>;
      String htfTrend = 'Sideways';
      if (emaJson['status'] == 'ok' && emaJson['values'] != null) {
        final vals = emaJson['values'] as List;
        if (vals.length >= 2) {
          final e1 = double.tryParse(vals[0]['ema'].toString()) ?? 0.0;
          final e2 = double.tryParse(vals[1]['ema'].toString()) ?? 0.0;
          if (e2 > 0) {
            final p = (e1 - e2) / e2 * 100;
            if (p > 0.02)  htfTrend = 'Bullish';
            if (p < -0.02) htfTrend = 'Bearish';
          }
        }
      }

      // ── S/D Zones via pivot detection ─────────────────────────────────────────
      final price = closes.isNotEmpty ? closes.last : 0.0;
      final tol   = price * 0.002;
      final ph = <double>[], pl = <double>[];
      final n = closes.length;
      for (int i = 2; i < n - 2; i++) {
        if (highs[i] > highs[i-1] && highs[i] > highs[i-2] &&
            highs[i] > highs[i+1] && highs[i] > highs[i+2]) ph.add(highs[i]);
        if (lows[i]  < lows[i-1]  && lows[i]  < lows[i-2]  &&
            lows[i]  < lows[i+1]  && lows[i]  < lows[i+2])  pl.add(lows[i]);
      }
      final nl = pl.where((l) => (price - l).abs() < tol).toList();
      final nh = ph.where((h) => (price - h).abs() < tol).toList();
      final sd = nl.length >= 2 ? 'strongDemand'
               : nl.length == 1 ? 'weakDemand'
               : nh.length >= 2 ? 'strongSupply'
               : nh.length == 1 ? 'weakSupply'
               : 'neutral';

      return {
        'rsi': rsi, 'macd_value': macdValue,
        'macd_signal': macdSignal, 'macd_histogram': macdHisto,
        'htf_trend': htfTrend, 'sd_zone': sd,
        'candles': candles,
        'pivot_highs': ph.take(5).toList(),
        'pivot_lows':  pl.take(5).toList(),
      };
    } catch (_) {
      return null;
    }
  }

  static Future<(String, String)> _buildClaudeOpinion({
    required Asset asset,
    required Timeframe timeframe,
    required SignalType signal,
    required double accuracy,
    required double score,
    required double rsi,
    required double macdHisto,
    required String htfLabel,
    required ZoneType zone,
    required _SessionInfo session,
    required bool bullDiv,
    required bool bearDiv,
    required Map<String, double> bb,
    required double price,
    required String smcBos,
    required String smcOb,
    required String smcFvg,
    required String smcLiqSweep,
    required String pattern,
    required double atrPips,
    required double entry,
    required double sl,
    required double tp,
    required AppStrings s,
  }) async {
    final bbRange = bb['upper']! - bb['lower']!;
    final bbPos   = bbRange > 0 ? (price - bb['lower']!) / bbRange : 0.5;
    final bbDesc  = bbPos < 0.12 ? 'near lower band (potential bounce)'
                  : bbPos > 0.88 ? 'near upper band (potential reversal)'
                  : 'near midline';

    final divDesc = bullDiv  ? 'Bullish divergence detected'
                  : bearDiv  ? 'Bearish divergence detected'
                  : 'No divergence';

    final smcDesc = [
      if (smcBos.isNotEmpty) smcBos,
      if (smcOb.isNotEmpty) smcOb,
      if (smcFvg.isNotEmpty) smcFvg,
      if (smcLiqSweep.isNotEmpty) smcLiqSweep,
    ].join(' | ');

    try {
      const url = 'https://aixpkthloeafwakiijws.supabase.co/functions/v1/ai-analysis';
      const anonKey = 'sb_publishable_Jm9xmIjg1MHhajBFxAxSkw_6aluy7Sa';
      final res = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $anonKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'symbol': asset.symbol,
          'timeframe': timeframe.label,
          'signal': signal.label,
          'accuracy': accuracy.toStringAsFixed(0),
          'rsi': rsi.toStringAsFixed(1),
          'rsiDivergence': divDesc,
          'macd': macdHisto > 0 ? 'Bullish crossover' : macdHisto < 0 ? 'Bearish crossover' : 'Diverging',
          'htf': htfLabel,
          'zone': zone.name,
          'bb': bbDesc,
          'smc': smcDesc.isNotEmpty ? smcDesc : 'No SMC signals',
          'pattern': pattern.isNotEmpty ? pattern : 'None',
          'atrPips': atrPips.toStringAsFixed(1),
          'entry': entry.toString(),
          'sl': sl.toString(),
          'tp': tp.toString(),
          'score': score.toStringAsFixed(1),
          'session': session.name,
          'sessionQuality': session.quality.toStringAsFixed(2),
          'sessionWarning': session.warning,
          'lang': s.lang,
          'responseFormat': 'Return JSON with keys: "analysis" (2-3 sentence expert opinion in the user language) and "trade_note" (ONE sentence in the user language starting with ⏱ about how many minutes to close the trade if TP is not reached, based on the specific indicators provided).',
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = res.body.trim();
        // Try to parse as JSON with both fields
        try {
          final data = json.decode(body) as Map<String, dynamic>;
          final analysis  = (data['analysis']   as String?) ?? '';
          final tradeNote = (data['trade_note']  as String?) ?? '';
          if (analysis.isNotEmpty) return (analysis, tradeNote);
        } catch (_) {
          // Edge function returned plain string
          if (body.isNotEmpty) return (body, '');
        }
      }
    } catch (_) {}
    return (s.claudeOpinion(asset.symbol, score.toStringAsFixed(2)), '');
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  static double _slPips(Asset asset, Timeframe tf) {
    final base = switch (tf) {
      Timeframe.m1  => 4,
      Timeframe.m5  => 8,
      Timeframe.m15 => 15,
      Timeframe.m30 => 22,
    };
    return asset.pipValue * base;
  }

  static double _roundPrice(double price, Asset asset) {
    final decimals = asset.pipValue < 0.01 ? 5 : (asset.pipValue < 0.1 ? 3 : 2);
    final factor = math.pow(10, decimals).toDouble();
    return (price * factor).round() / factor;
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')} UTC';
  }
}
