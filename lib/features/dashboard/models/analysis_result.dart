import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'candle_model.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum SignalType { buy, sell, wait }

enum ZoneType { strongDemand, weakDemand, neutral, weakSupply, strongSupply }

// ── Extensions ────────────────────────────────────────────────────────────────

extension SignalTypeExtension on SignalType {
  String get label {
    switch (this) {
      case SignalType.buy:  return 'BUY';
      case SignalType.sell: return 'SELL';
      case SignalType.wait: return 'WAIT';
    }
  }

  Color get primaryColor {
    switch (this) {
      case SignalType.buy:  return AppColors.neonGreen;
      case SignalType.sell: return AppColors.neonRed;
      case SignalType.wait: return AppColors.waitAmber;
    }
  }

  Color get glowColor {
    switch (this) {
      case SignalType.buy:  return AppColors.glowGreen;
      case SignalType.sell: return AppColors.glowRed;
      case SignalType.wait: return AppColors.glowAmber;
    }
  }

  IconData get icon {
    switch (this) {
      case SignalType.buy:  return Icons.trending_up_rounded;
      case SignalType.sell: return Icons.trending_down_rounded;
      case SignalType.wait: return Icons.pause_circle_outline_rounded;
    }
  }
}

extension ZoneTypeExtension on ZoneType {
  String get label {
    switch (this) {
      case ZoneType.strongDemand: return 'Strong Demand Zone';
      case ZoneType.weakDemand:   return 'Weak Demand Zone';
      case ZoneType.neutral:      return 'Neutral Territory';
      case ZoneType.weakSupply:   return 'Weak Supply Zone';
      case ZoneType.strongSupply: return 'Strong Supply Zone';
    }
  }

  Color get color {
    switch (this) {
      case ZoneType.strongDemand: return AppColors.neonGreen;
      case ZoneType.weakDemand:   return AppColors.neonGreenDim;
      case ZoneType.neutral:      return AppColors.textSecondary;
      case ZoneType.weakSupply:   return AppColors.neonRedDim;
      case ZoneType.strongSupply: return AppColors.neonRed;
    }
  }

  double get strength {
    switch (this) {
      case ZoneType.strongDemand: return 0.9;
      case ZoneType.weakDemand:   return 0.6;
      case ZoneType.neutral:      return 0.5;
      case ZoneType.weakSupply:   return 0.4;
      case ZoneType.strongSupply: return 0.1;
    }
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

class AnalysisResult {
  final SignalType signal;
  final double accuracy;            // 0–100
  final double entryPoint;
  final double stopLoss;
  final double takeProfit;
  final double riskRewardRatio;
  final double rsi;
  final double macdValue;
  final double macdSignalLine;
  final double macdHistogram;
  final ZoneType zone;
  final List<String> confluenceFactors;
  final String aiSentiment;
  final String claudeOpinion;
  final String higherTfTrend;       // "Bullish", "Bearish", "Sideways"
  final String analysisTimestamp;
  final List<Candle> candles;
  final List<double> pivotHighs;
  final List<double> pivotLows;

  final String sessionName;     // 'London/NY', 'London', 'New York', 'Tokyo', 'Sydney', 'London Lunch'
  final String sessionWarning;  // '' = good session; non-empty = warning text
  final String summary;         // عصارة التحليل — concise verdict
  final String candlePattern;   // 'BullishPinBar', 'BearishPinBar', 'BullishEngulfing', 'BearishEngulfing', 'Doji', ''
  final double atrValue;        // ATR(14) absolute value

  // ── Deep Analysis ─────────────────────────────────────────────────────────
  final double bbUpper;             // Bollinger Band upper (20-period, 2σ)
  final double bbMiddle;            // Bollinger Band middle (SMA-20)
  final double bbLower;             // Bollinger Band lower
  final bool rsiBullishDivergence;  // price lower-low but RSI higher-low
  final bool rsiBearishDivergence;  // price higher-high but RSI lower-high
  final String smcOrderBlock;       // e.g. 'Bullish OB @ 1.0850–1.0855'
  final String smcFvg;              // e.g. 'Bullish FVG 1.0820–1.0830'
  final String smcBos;              // e.g. 'BOS ↑ (Bullish Break)'
  final String smcLiqSweep;         // e.g. 'Bullish Sweep @ 1.0800'
  final String tradeNote;           // AI-generated or rule-based trade management note

  const AnalysisResult({
    required this.signal,
    required this.accuracy,
    required this.entryPoint,
    required this.stopLoss,
    required this.takeProfit,
    required this.riskRewardRatio,
    required this.rsi,
    required this.macdValue,
    required this.macdSignalLine,
    required this.macdHistogram,
    required this.zone,
    required this.confluenceFactors,
    required this.aiSentiment,
    required this.claudeOpinion,
    required this.higherTfTrend,
    required this.analysisTimestamp,
    this.candles = const [],
    this.pivotHighs = const [],
    this.pivotLows = const [],
    this.sessionName = '',
    this.sessionWarning = '',
    this.summary = '',
    this.candlePattern = '',
    this.atrValue = 0.0,
    this.bbUpper = 0.0,
    this.bbMiddle = 0.0,
    this.bbLower = 0.0,
    this.rsiBullishDivergence = false,
    this.rsiBearishDivergence = false,
    this.smcOrderBlock = '',
    this.smcFvg = '',
    this.smcBos = '',
    this.smcLiqSweep = '',
    this.tradeNote = '',
  });
}
