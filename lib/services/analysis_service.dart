import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/localization/app_strings.dart';
import '../features/dashboard/models/asset_model.dart';
import '../features/dashboard/models/analysis_result.dart';
import '../features/dashboard/models/candle_model.dart';
import 'chart_image_renderer.dart';
import 'news_calendar_service.dart';

class _SessionInfo {
  final String name;    // 'London/NY', 'London', 'New York', 'Tokyo', 'Sydney', 'London Lunch'
  final String warning; // '' = no warning; non-empty = warning text
  final double quality; // 0.0-1.0
  const _SessionInfo(this.name, this.warning, this.quality);
}

class AnalysisService {
  AnalysisService._();

  // ══════════════════════════════════════════════════════════════════════════
  // UNCHANGED — data fetch & raw indicator math (do not touch per spec)
  // ══════════════════════════════════════════════════════════════════════════

  // ── Risk management constants ──────────────────────────────────────────────

  static const _spreadBufferPips = 30.0; // extra protective distance added to every SL

  // ── Turkey-time helpers (UTC+3, fixed year-round since 2016) ──────────────

  static DateTime _turkeyNow() => DateTime.now().toUtc().add(const Duration(hours: 3));

  // Asian session 00:00–09:00 Turkey time — thin liquidity, wider/erratic spreads.
  static bool _isLowLiquidityWindow() {
    final h = _turkeyNow().hour;
    return h >= 0 && h < 9;
  }

  static String _fmtTurkeyTime(DateTime utc) {
    final t = utc.add(const Duration(hours: 3));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  static String _hardExitTime() => _fmtTurkeyTime(DateTime.now().toUtc().add(const Duration(hours: 2)));

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

  static _SessionInfo _sessionInfo(AppStrings s) {
    final now = DateTime.now().toUtc();
    final h   = now.hour + now.minute / 60.0;

    if (h >= 13.0 && h < 17.0) return const _SessionInfo('London/NY', '', 1.0);
    if (h >= 8.0 && h < 12.0)  return const _SessionInfo('London', '', 0.85);
    if (h >= 12.0 && h < 13.0) return _SessionInfo('London Lunch', s.sessionLunchWarning, 0.4);
    if (h >= 17.0 && h < 22.0) return const _SessionInfo('New York', '', 0.75);
    if (h < 8.0)               return _SessionInfo('Tokyo', s.sessionTokyoWarning, 0.3);
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

    if (bodyRatio < 0.05 && upperRatio > 0.1 && lowerRatio > 0.1) return 'Doji';
    if (lowerRatio >= 0.6 && bodyRatio <= 0.3) return 'BullishPinBar';
    if (upperRatio >= 0.6 && bodyRatio <= 0.3) return 'BearishPinBar';

    final prevBody = (prev.close - prev.open).abs();
    if (prevBody <= 0) return '';
    final currHigh = math.max(curr.open, curr.close);
    final currLow  = math.min(curr.open, curr.close);
    final prevHigh = math.max(prev.open, prev.close);
    final prevLow  = math.min(prev.open, prev.close);

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

  // ── RSI series (Wilder's smoothing) ───────────────────────────────────────

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

    bool bullDiv = false;
    if (lows.length >= 2) {
      final i1 = lows[lows.length - 2], i2 = lows.last;
      bullDiv = closes[i2] < closes[i1] && rsiSeries[i2] > rsiSeries[i1] + 2;
    }

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
    final price = candles.last.close;
    final start = math.max(0, candles.length - 35);

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

    String fvg = '';
    for (int i = math.max(0, candles.length - 20); i < candles.length - 2 && fvg.isEmpty; i++) {
      final c0 = candles[i], c2 = candles[i + 2];
      if (c0.high < c2.low) {
        fvg = 'Bullish FVG ${_fmtLv(c0.high)}–${_fmtLv(c2.low)}';
      } else if (c0.low > c2.high) {
        fvg = 'Bearish FVG ${_fmtLv(c2.high)}–${_fmtLv(c0.low)}';
      }
    }

    String bos = '';
    if (pivotHighs.length >= 2 && pivotLows.length >= 2) {
      final lastH = pivotHighs.last, prevH = pivotHighs[pivotHighs.length - 2];
      final lastL = pivotLows.last,  prevL = pivotLows[pivotLows.length - 2];
      if (price > lastH && lastH > prevH)         bos = 'BOS ↑ (Bullish Break)';
      else if (price < lastL && lastL < prevL)    bos = 'BOS ↓ (Bearish Break)';
      else if (price > prevH && lastH < prevH)    bos = 'CHoCH ↑ (Bullish Flip)';
      else if (price < prevL && lastL > prevL)    bos = 'CHoCH ↓ (Bearish Flip)';
    }

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

  static const _tdApiKey = 'a08efe8f43924f5d81688320cbc75a47';

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
      Timeframe.m30 => '30min',
    };
    final base = 'https://api.twelvedata.com';
    final key  = _tdApiKey;

    Future<http.Response> tracked(String label, String path) async {
      final sw = Stopwatch()..start();
      try {
        final r = await http.get(Uri.parse(path)).timeout(const Duration(seconds: 35));
        debugPrint('[AnalysisService] $label done in ${sw.elapsedMilliseconds}ms (status ${r.statusCode})');
        return r;
      } catch (e) {
        debugPrint('[AnalysisService] $label FAILED after ${sw.elapsedMilliseconds}ms: $e');
        rethrow;
      }
    }

    try {
      final results = await Future.wait([
        tracked('time_series', '$base/time_series?symbol=$symbol&interval=$interval&outputsize=100&apikey=$key'),
        tracked('rsi',         '$base/rsi?symbol=$symbol&interval=$interval&time_period=14&outputsize=1&apikey=$key'),
        tracked('macd',        '$base/macd?symbol=$symbol&interval=$interval&fast_period=12&slow_period=26&signal_period=9&outputsize=1&apikey=$key'),
        tracked('ema',         '$base/ema?symbol=$symbol&interval=1h&time_period=50&outputsize=2&apikey=$key'),
      ]);

      final tsJson = json.decode(results[0].body) as Map<String, dynamic>;
      if (tsJson['status'] == 'error' || tsJson['values'] == null) {
        debugPrint('[AnalysisService] time_series error: ${results[0].statusCode} ${results[0].body}');
        return null;
      }
      final rawValues = (tsJson['values'] as List).reversed.toList();
      final candles = rawValues.map<Map<String, dynamic>>((v) => {
        'o': double.tryParse(v['open'].toString())  ?? 0.0,
        'h': double.tryParse(v['high'].toString())  ?? 0.0,
        'l': double.tryParse(v['low'].toString())   ?? 0.0,
        'c': double.tryParse(v['close'].toString()) ?? 0.0,
      }).toList();
      final closes = candles.map((c) => c['c'] as double).toList();
      final highs  = candles.map((c) => c['h'] as double).toList();
      final lows   = candles.map((c) => c['l'] as double).toList();

      final rsiJson = json.decode(results[1].body) as Map<String, dynamic>;
      final rsi = rsiJson['status'] == 'ok' && rsiJson['values'] != null
          ? (double.tryParse((rsiJson['values'] as List).first['rsi'].toString()) ?? 50.0)
          : 50.0;

      final macdJson = json.decode(results[2].body) as Map<String, dynamic>;
      double macdValue = 0, macdSignal = 0, macdHisto = 0;
      if (macdJson['status'] == 'ok' && macdJson['values'] != null) {
        final mv = (macdJson['values'] as List).first;
        macdValue  = double.tryParse(mv['macd'].toString())        ?? 0.0;
        macdSignal = double.tryParse(mv['macd_signal'].toString()) ?? 0.0;
        macdHisto  = double.tryParse(mv['macd_hist'].toString())   ?? 0.0;
      }

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

      final price = closes.isNotEmpty ? closes.last : 0.0;
      final tol = price * 0.002;
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
    } catch (e, st) {
      debugPrint('[AnalysisService] _fetchRealIndicators exception: $e\n$st');
      return null;
    }
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

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════════════════════════════════

  static Future<AnalysisResult> analyze({
    required Asset asset,
    required Timeframe timeframe,
    String lang = 'en',
    double? livePrice,
  }) async {
    final s = AppStrings.of(lang);

    if (_isMarketClosed()) return _buildMarketClosedResult(asset, s: s);

    final newsFrozen = await NewsCalendarService.checkEconomicCalendarNews(
      tradeTime: DateTime.now(),
      symbol: asset.symbol,
    );
    if (newsFrozen) return _buildWaitResult(asset, s: s);

    return await _computeSignal(asset, timeframe, s, livePrice);
  }

  // ── Core: fetch indicators (unchanged) → 4-agent decision → final result ──

  static Future<AnalysisResult> _computeSignal(
      Asset asset, Timeframe timeframe, AppStrings s, double? livePrice) async {
    final realData = await _fetchRealIndicators(asset, timeframe);
    if (realData == null) return _buildDataErrorResult(asset, s: s);

    final rsi = (realData['rsi'] as num).toDouble().clamp(0.0, 100.0);
    final macdValue  = (realData['macd_value']     as num).toDouble();
    final macdSignal = (realData['macd_signal']    as num).toDouble();
    final macdHisto  = (realData['macd_histogram'] as num).toDouble();
    final htfTrend   = realData['htf_trend'] as String? ?? 'Sideways';
    final sdZone     = realData['sd_zone'] as String? ?? 'neutral';
    final session    = _sessionInfo(s);

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

    final pattern = _detectPattern(candles);
    final atr     = _calculateAtr(candles);
    final atrPips = asset.pipValue > 0 ? atr / asset.pipValue : 0.0;

    final closesList = candles.map((c) => c.close).toList();
    final bb        = _calcBollinger(closesList);
    final rsiSeries = _calcRsiSeries(closesList);
    final (bullDiv, bearDiv) = _detectDivergence(closesList, rsiSeries);
    final smc = _detectSmc(candles, pivotHighs, pivotLows);

    final lastClose = candles.isNotEmpty ? candles.last.close : asset.basePrice;
    final entry = livePrice ?? lastClose;

    // ── Plain chart image (pre-decision) for the Chart_Vision_Agent ────────
    final plainImageBytes = await ChartImageRenderer.render(
      candles: candles, pivotHighs: pivotHighs, pivotLows: pivotLows,
    );

    final bbRange = bb['upper']! - bb['lower']!;
    final bbPos   = bbRange > 0 ? (entry - bb['lower']!) / bbRange : 0.5;
    final indicatorSnapshot = {
      'rsi': double.parse(rsi.toStringAsFixed(1)),
      'rsi_divergence': bullDiv ? 'Bullish' : bearDiv ? 'Bearish' : 'None',
      'macd_value': macdValue, 'macd_signal': macdSignal, 'macd_histogram': macdHisto,
      'higher_timeframe_trend_h1': htfTrend,
      'supply_demand_zone': sdZone,
      'bollinger_position_0to1': double.parse(bbPos.clamp(0, 1).toStringAsFixed(2)),
      'smc_order_block': smc['orderBlock'],
      'smc_fvg': smc['fvg'],
      'smc_bos_choch': smc['bos'],
      'smc_liquidity_sweep': smc['liqSweep'],
      'candle_pattern': pattern,
      'atr_pips': double.parse(atrPips.toStringAsFixed(1)),
      'session': session.name,
      'session_quality_0to1': session.quality,
      'session_warning': session.warning,
    };

    final decision = await _callMultiAgent(
      asset: asset,
      lang: s.lang,
      indicatorSnapshot: indicatorSnapshot,
      atrPips: atrPips,
      plainImageBytes: plainImageBytes,
    );

    if (decision == null) return _buildDataErrorResult(asset, s: s);

    final signal = switch (decision['signal'] as String? ?? 'WAIT') {
      'BUY'  => SignalType.buy,
      'SELL' => SignalType.sell,
      _      => SignalType.wait,
    };
    final confidence = ((decision['confidence_pct'] as num?) ?? 50).toDouble().clamp(0.0, 100.0);
    final reasons = (decision['reasons'] as String?) ?? '';
    final exitNote = (decision['exit_note'] as String?) ?? '';
    final slPips = ((decision['sl_pips'] as num?) ?? 0).toDouble().clamp(2.0, 400.0);
    final tpPips = ((decision['tp_pips'] as num?) ?? 0).toDouble().clamp(2.0, 800.0);
    final riskPct = ((decision['risk_pct'] as num?) ?? 0).toDouble().clamp(0.0, 3.0);

    // Spread Buffer — push SL an extra 30 pips further away from entry so a
    // sudden spread widening (news spike, session open) doesn't tag the stop
    // before price actually reverses. TP is scaled by the SAME factor so the
    // AI's intended risk:reward ratio is preserved — widening only the SL
    // would otherwise silently turn a good 1:1.67 setup into a losing-side
    // 1:0.56 one.
    final bufferedSlPips = slPips + _spreadBufferPips;
    final bufferedTpPips = tpPips * (bufferedSlPips / slPips);

    double sl = entry, tp = entry;
    if (signal == SignalType.buy) {
      sl = entry - bufferedSlPips * asset.pipValue;
      tp = entry + bufferedTpPips * asset.pipValue;
    } else if (signal == SignalType.sell) {
      sl = entry + bufferedSlPips * asset.pipValue;
      tp = entry - bufferedTpPips * asset.pipValue;
    }
    final rrr = signal == SignalType.wait || (entry - sl).abs() == 0
        ? 0.0
        : (tp - entry).abs() / (entry - sl).abs();

    final roundedEntry = _roundPrice(entry, asset);
    final roundedSl    = _roundPrice(sl, asset);
    final roundedTp    = _roundPrice(tp, asset);

    final lowLiquidityWarning = _isLowLiquidityWindow();
    final hardExitTime = _hardExitTime();

    // ── Composed chart image (post-decision) — what the UI shows + exports ─
    final composedImageBytes = await ChartImageRenderer.render(
      candles: candles, pivotHighs: pivotHighs, pivotLows: pivotLows,
      entry: signal == SignalType.wait ? null : roundedEntry,
      sl: signal == SignalType.wait ? null : roundedSl,
      tp: signal == SignalType.wait ? null : roundedTp,
      riskPercent: signal == SignalType.wait ? null : riskPct,
      signal: signal.label,
      confidence: confidence,
      reasonsText: reasons,
      exitNote: exitNote,
      lowLiquidityWarning: lowLiquidityWarning,
      hardExitTime: hardExitTime,
      sessionName: session.name,
      lang: s.lang,
    );

    return AnalysisResult(
      signal: signal,
      accuracy: confidence,
      entryPoint: roundedEntry,
      stopLoss: roundedSl,
      takeProfit: roundedTp,
      riskRewardRatio: double.parse(rrr.toStringAsFixed(2)),
      rsi: double.parse(rsi.toStringAsFixed(1)),
      macdValue: macdValue,
      macdSignalLine: macdSignal,
      macdHistogram: macdHisto,
      zone: switch (sdZone) {
        'strongDemand' => ZoneType.strongDemand,
        'weakDemand'   => ZoneType.weakDemand,
        'weakSupply'   => ZoneType.weakSupply,
        'strongSupply' => ZoneType.strongSupply,
        _ => ZoneType.neutral,
      },
      confluenceFactors: const [],
      aiSentiment: reasons,
      claudeOpinion: reasons,
      higherTfTrend: htfTrend,
      analysisTimestamp: _timestamp(),
      candles: candles,
      pivotHighs: pivotHighs,
      pivotLows: pivotLows,
      sessionName: session.name,
      sessionWarning: session.warning,
      candlePattern: pattern,
      atrValue: atr,
      bbUpper: bb['upper']!,
      bbMiddle: bb['middle']!,
      bbLower: bb['lower']!,
      rsiBullishDivergence: bullDiv,
      rsiBearishDivergence: bearDiv,
      smcOrderBlock: smc['orderBlock']!,
      smcFvg: smc['fvg']!,
      smcBos: smc['bos']!,
      smcLiqSweep: smc['liqSweep']!,
      aiReasons: reasons,
      exitNote: exitNote,
      riskPercent: riskPct,
      chartImageBytes: composedImageBytes,
      lowLiquidityWarning: lowLiquidityWarning,
      hardExitTime: hardExitTime,
    );
  }

  // ── Multi-Agent orchestration call ─────────────────────────────────────────

  static Future<Map<String, dynamic>?> _callMultiAgent({
    required Asset asset,
    required String lang,
    required Map<String, dynamic> indicatorSnapshot,
    required double atrPips,
    required List<int> plainImageBytes,
  }) async {
    try {
      const url = 'https://aixpkthloeafwakiijws.supabase.co/functions/v1/multi-agent-analysis';
      const anonKey = 'sb_publishable_Jm9xmIjg1MHhajBFxAxSkw_6aluy7Sa';
      final res = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $anonKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'symbol': asset.symbol,
          'lang': lang,
          'indicators': indicatorSnapshot,
          'atrPips': atrPips,
          'chartImageBase64': base64Encode(plainImageBytes),
        }),
      ).timeout(const Duration(seconds: 120));

      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
      debugPrint('[AnalysisService] multi-agent-analysis HTTP ${res.statusCode}: ${res.body}');
    } catch (e, st) {
      debugPrint('[AnalysisService] multi-agent-analysis exception: $e\n$st');
    }
    return null;
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
      aiReasons: s.marketClosedSentiment,
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
      aiReasons: s.dataErrorOpinion,
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
      aiReasons: s.newsFreezeWait,
    );
  }
}
