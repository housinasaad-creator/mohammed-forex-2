import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum AssetCategory {
  forexMajor,
  forexMinor,
  forexExotic,
  metals,
  energy,
  commodities,
}

enum Timeframe { m1, m5, m15, m30 }

// ── Extensions ────────────────────────────────────────────────────────────────

extension AssetCategoryExtension on AssetCategory {
  String get label {
    switch (this) {
      case AssetCategory.forexMajor:  return 'Major Pairs';
      case AssetCategory.forexMinor:  return 'Cross / Minor Pairs';
      case AssetCategory.forexExotic: return 'Exotic Pairs';
      case AssetCategory.metals:      return 'Precious Metals';
      case AssetCategory.energy:      return 'Energies & Oil';
      case AssetCategory.commodities: return 'Agricultural';
    }
  }

  IconData get icon {
    switch (this) {
      case AssetCategory.forexMajor:  return Icons.currency_exchange_rounded;
      case AssetCategory.forexMinor:  return Icons.swap_horiz_rounded;
      case AssetCategory.forexExotic: return Icons.public_rounded;
      case AssetCategory.metals:      return Icons.diamond_rounded;
      case AssetCategory.energy:      return Icons.bolt_rounded;
      case AssetCategory.commodities: return Icons.grass_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case AssetCategory.forexMajor:  return AppColors.gold;
      case AssetCategory.forexMinor:  return const Color(0xFF6EC6FF);
      case AssetCategory.forexExotic: return const Color(0xFFFF8C42);
      case AssetCategory.metals:      return const Color(0xFFE8C97B);
      case AssetCategory.energy:      return const Color(0xFFFF6B35);
      case AssetCategory.commodities: return const Color(0xFF7BC67E);
    }
  }
}

extension TimeframeExtension on Timeframe {
  String get label {
    switch (this) {
      case Timeframe.m1:  return 'M1';
      case Timeframe.m5:  return 'M5';
      case Timeframe.m15: return 'M15';
      case Timeframe.m30: return 'M30';
    }
  }

  String get description {
    switch (this) {
      case Timeframe.m1:  return '1 Minute';
      case Timeframe.m5:  return '5 Minutes';
      case Timeframe.m15: return '15 Minutes';
      case Timeframe.m30: return '30 Minutes';
    }
  }
}

// ── Asset Model ───────────────────────────────────────────────────────────────

class Asset {
  final String symbol;
  final String displayName;
  final AssetCategory category;
  final String abbreviation;
  final Color logoColor;
  final double pipValue;
  final double basePrice;

  const Asset({
    required this.symbol,
    required this.displayName,
    required this.category,
    required this.abbreviation,
    required this.logoColor,
    required this.pipValue,
    required this.basePrice,
  });
}

// ── Asset Catalogue ───────────────────────────────────────────────────────────

class AssetCatalogue {

  // ════════════════════════════════════════════════════════════════════════════
  // FOREX MAJORS
  // ════════════════════════════════════════════════════════════════════════════

  static const List<Asset> forexMajor = [
    Asset(symbol: 'EUR/USD', displayName: 'Euro / US Dollar',
          category: AssetCategory.forexMajor, abbreviation: '€\$',
          logoColor: Color(0xFF4A9EFF), pipValue: 0.0001, basePrice: 1.0862),
    Asset(symbol: 'GBP/USD', displayName: 'British Pound / US Dollar',
          category: AssetCategory.forexMajor, abbreviation: '£\$',
          logoColor: Color(0xFF9B59B6), pipValue: 0.0001, basePrice: 1.2734),
    Asset(symbol: 'USD/JPY', displayName: 'US Dollar / Japanese Yen',
          category: AssetCategory.forexMajor, abbreviation: '\$¥',
          logoColor: Color(0xFFE74C3C), pipValue: 0.01,   basePrice: 149.82),
    Asset(symbol: 'USD/CHF', displayName: 'US Dollar / Swiss Franc',
          category: AssetCategory.forexMajor, abbreviation: '\$Fr',
          logoColor: Color(0xFFFF4D4D), pipValue: 0.0001, basePrice: 0.9123),
    Asset(symbol: 'AUD/USD', displayName: 'Australian Dollar / US Dollar',
          category: AssetCategory.forexMajor, abbreviation: 'A\$',
          logoColor: Color(0xFF1ABC9C), pipValue: 0.0001, basePrice: 0.6548),
    Asset(symbol: 'USD/CAD', displayName: 'US Dollar / Canadian Dollar',
          category: AssetCategory.forexMajor, abbreviation: '\$C',
          logoColor: Color(0xFFE67E22), pipValue: 0.0001, basePrice: 1.3614),
    Asset(symbol: 'NZD/USD', displayName: 'New Zealand Dollar / US Dollar',
          category: AssetCategory.forexMajor, abbreviation: 'NZ\$',
          logoColor: Color(0xFF2ECC71), pipValue: 0.0001, basePrice: 0.6012),
  ];

  // ════════════════════════════════════════════════════════════════════════════
  // FOREX MINORS / CROSSES
  // ════════════════════════════════════════════════════════════════════════════

  static const List<Asset> forexMinor = [
    // EUR Crosses
    Asset(symbol: 'EUR/GBP', displayName: 'Euro / British Pound',
          category: AssetCategory.forexMinor, abbreviation: '€£',
          logoColor: Color(0xFF5DADE2), pipValue: 0.0001, basePrice: 0.8534),
    Asset(symbol: 'EUR/JPY', displayName: 'Euro / Japanese Yen',
          category: AssetCategory.forexMinor, abbreviation: '€¥',
          logoColor: Color(0xFF5DADE2), pipValue: 0.01,   basePrice: 162.78),
    Asset(symbol: 'EUR/CHF', displayName: 'Euro / Swiss Franc',
          category: AssetCategory.forexMinor, abbreviation: '€Fr',
          logoColor: Color(0xFF5DADE2), pipValue: 0.0001, basePrice: 0.9847),
    Asset(symbol: 'EUR/AUD', displayName: 'Euro / Australian Dollar',
          category: AssetCategory.forexMinor, abbreviation: '€A',
          logoColor: Color(0xFF5DADE2), pipValue: 0.0001, basePrice: 1.6583),
    Asset(symbol: 'EUR/CAD', displayName: 'Euro / Canadian Dollar',
          category: AssetCategory.forexMinor, abbreviation: '€C',
          logoColor: Color(0xFF5DADE2), pipValue: 0.0001, basePrice: 1.4782),
    Asset(symbol: 'EUR/NZD', displayName: 'Euro / New Zealand Dollar',
          category: AssetCategory.forexMinor, abbreviation: '€NZ',
          logoColor: Color(0xFF5DADE2), pipValue: 0.0001, basePrice: 1.8062),
    // GBP Crosses
    Asset(symbol: 'GBP/JPY', displayName: 'British Pound / Japanese Yen',
          category: AssetCategory.forexMinor, abbreviation: '£¥',
          logoColor: Color(0xFFAF7AC5), pipValue: 0.01,   basePrice: 190.45),
    Asset(symbol: 'GBP/CHF', displayName: 'British Pound / Swiss Franc',
          category: AssetCategory.forexMinor, abbreviation: '£Fr',
          logoColor: Color(0xFFAF7AC5), pipValue: 0.0001, basePrice: 1.1532),
    Asset(symbol: 'GBP/AUD', displayName: 'British Pound / Australian Dollar',
          category: AssetCategory.forexMinor, abbreviation: '£A',
          logoColor: Color(0xFFAF7AC5), pipValue: 0.0001, basePrice: 1.9445),
    Asset(symbol: 'GBP/CAD', displayName: 'British Pound / Canadian Dollar',
          category: AssetCategory.forexMinor, abbreviation: '£C',
          logoColor: Color(0xFFAF7AC5), pipValue: 0.0001, basePrice: 1.7312),
    Asset(symbol: 'GBP/NZD', displayName: 'British Pound / New Zealand Dollar',
          category: AssetCategory.forexMinor, abbreviation: '£NZ',
          logoColor: Color(0xFFAF7AC5), pipValue: 0.0001, basePrice: 2.1178),
    // AUD Crosses
    Asset(symbol: 'AUD/JPY', displayName: 'Australian Dollar / Japanese Yen',
          category: AssetCategory.forexMinor, abbreviation: 'A¥',
          logoColor: Color(0xFF45B39D), pipValue: 0.01,   basePrice: 98.12),
    Asset(symbol: 'AUD/CAD', displayName: 'Australian Dollar / Canadian Dollar',
          category: AssetCategory.forexMinor, abbreviation: 'AC',
          logoColor: Color(0xFF45B39D), pipValue: 0.0001, basePrice: 0.8942),
    Asset(symbol: 'AUD/NZD', displayName: 'Australian Dollar / New Zealand Dollar',
          category: AssetCategory.forexMinor, abbreviation: 'ANZ',
          logoColor: Color(0xFF45B39D), pipValue: 0.0001, basePrice: 1.0853),
    Asset(symbol: 'AUD/CHF', displayName: 'Australian Dollar / Swiss Franc',
          category: AssetCategory.forexMinor, abbreviation: 'AFr',
          logoColor: Color(0xFF45B39D), pipValue: 0.0001, basePrice: 0.5992),
    // CAD Crosses
    Asset(symbol: 'CAD/JPY', displayName: 'Canadian Dollar / Japanese Yen',
          category: AssetCategory.forexMinor, abbreviation: 'C¥',
          logoColor: Color(0xFFCA6F1E), pipValue: 0.01,   basePrice: 110.21),
    Asset(symbol: 'CAD/CHF', displayName: 'Canadian Dollar / Swiss Franc',
          category: AssetCategory.forexMinor, abbreviation: 'CFr',
          logoColor: Color(0xFFCA6F1E), pipValue: 0.0001, basePrice: 0.6703),
    // CHF Crosses
    Asset(symbol: 'CHF/JPY', displayName: 'Swiss Franc / Japanese Yen',
          category: AssetCategory.forexMinor, abbreviation: 'Fr¥',
          logoColor: Color(0xFFEC7063), pipValue: 0.01,   basePrice: 164.35),
    // NZD Crosses
    Asset(symbol: 'NZD/JPY', displayName: 'New Zealand Dollar / Japanese Yen',
          category: AssetCategory.forexMinor, abbreviation: 'NZ¥',
          logoColor: Color(0xFF52BE80), pipValue: 0.01,   basePrice: 90.43),
    Asset(symbol: 'NZD/CAD', displayName: 'New Zealand Dollar / Canadian Dollar',
          category: AssetCategory.forexMinor, abbreviation: 'NZC',
          logoColor: Color(0xFF52BE80), pipValue: 0.0001, basePrice: 0.8234),
    Asset(symbol: 'NZD/CHF', displayName: 'New Zealand Dollar / Swiss Franc',
          category: AssetCategory.forexMinor, abbreviation: 'NZF',
          logoColor: Color(0xFF52BE80), pipValue: 0.0001, basePrice: 0.5523),
  ];

  // ════════════════════════════════════════════════════════════════════════════
  // FOREX EXOTICS
  // ════════════════════════════════════════════════════════════════════════════

  static const List<Asset> forexExotic = [
    Asset(symbol: 'USD/TRY', displayName: 'US Dollar / Turkish Lira',
          category: AssetCategory.forexExotic, abbreviation: '\$₺',
          logoColor: Color(0xFFE74C3C), pipValue: 0.0001, basePrice: 32.45),
    Asset(symbol: 'USD/ZAR', displayName: 'US Dollar / South African Rand',
          category: AssetCategory.forexExotic, abbreviation: '\$R',
          logoColor: Color(0xFF27AE60), pipValue: 0.0001, basePrice: 18.78),
    Asset(symbol: 'USD/MXN', displayName: 'US Dollar / Mexican Peso',
          category: AssetCategory.forexExotic, abbreviation: '\$M',
          logoColor: Color(0xFF16A085), pipValue: 0.0001, basePrice: 17.21),
    Asset(symbol: 'USD/SEK', displayName: 'US Dollar / Swedish Krona',
          category: AssetCategory.forexExotic, abbreviation: '\$SK',
          logoColor: Color(0xFF2980B9), pipValue: 0.0001, basePrice: 10.68),
    Asset(symbol: 'USD/NOK', displayName: 'US Dollar / Norwegian Krone',
          category: AssetCategory.forexExotic, abbreviation: '\$NK',
          logoColor: Color(0xFF8E44AD), pipValue: 0.0001, basePrice: 10.54),
    Asset(symbol: 'USD/DKK', displayName: 'US Dollar / Danish Krone',
          category: AssetCategory.forexExotic, abbreviation: '\$DK',
          logoColor: Color(0xFFC0392B), pipValue: 0.0001, basePrice: 6.87),
    Asset(symbol: 'USD/SGD', displayName: 'US Dollar / Singapore Dollar',
          category: AssetCategory.forexExotic, abbreviation: '\$SG',
          logoColor: Color(0xFFE74C3C), pipValue: 0.0001, basePrice: 1.3512),
    Asset(symbol: 'USD/HKD', displayName: 'US Dollar / Hong Kong Dollar',
          category: AssetCategory.forexExotic, abbreviation: 'HK\$',
          logoColor: Color(0xFFE74C3C), pipValue: 0.0001, basePrice: 7.8234),
    Asset(symbol: 'USD/CNH', displayName: 'US Dollar / Chinese Yuan (Offshore)',
          category: AssetCategory.forexExotic, abbreviation: '\$¥',
          logoColor: Color(0xFFC0392B), pipValue: 0.0001, basePrice: 7.2456),
    Asset(symbol: 'USD/PLN', displayName: 'US Dollar / Polish Zloty',
          category: AssetCategory.forexExotic, abbreviation: '\$zł',
          logoColor: Color(0xFFE74C3C), pipValue: 0.0001, basePrice: 4.0123),
    Asset(symbol: 'USD/CZK', displayName: 'US Dollar / Czech Koruna',
          category: AssetCategory.forexExotic, abbreviation: '\$Kč',
          logoColor: Color(0xFF2471A3), pipValue: 0.001,  basePrice: 23.45),
    Asset(symbol: 'USD/HUF', displayName: 'US Dollar / Hungarian Forint',
          category: AssetCategory.forexExotic, abbreviation: '\$Ft',
          logoColor: Color(0xFF1F618D), pipValue: 0.01,   basePrice: 361.80),
    Asset(symbol: 'EUR/TRY', displayName: 'Euro / Turkish Lira',
          category: AssetCategory.forexExotic, abbreviation: '€₺',
          logoColor: Color(0xFF2E86C1), pipValue: 0.0001, basePrice: 35.23),
    Asset(symbol: 'GBP/TRY', displayName: 'British Pound / Turkish Lira',
          category: AssetCategory.forexExotic, abbreviation: '£₺',
          logoColor: Color(0xFF8E44AD), pipValue: 0.0001, basePrice: 41.65),
    Asset(symbol: 'USD/THB', displayName: 'US Dollar / Thai Baht',
          category: AssetCategory.forexExotic, abbreviation: '\$฿',
          logoColor: Color(0xFF2980B9), pipValue: 0.001,  basePrice: 36.82),
    Asset(symbol: 'USD/INR', displayName: 'US Dollar / Indian Rupee',
          category: AssetCategory.forexExotic, abbreviation: '\$₹',
          logoColor: Color(0xFFFF8C00), pipValue: 0.001,  basePrice: 83.45),
  ];

  // ════════════════════════════════════════════════════════════════════════════
  // PRECIOUS METALS
  // ════════════════════════════════════════════════════════════════════════════

  static const List<Asset> metals = [
    Asset(symbol: 'XAU/USD', displayName: 'Gold / US Dollar',
          category: AssetCategory.metals, abbreviation: 'Au',
          logoColor: Color(0xFFD4AF37), pipValue: 0.01,   basePrice: 2342.50),
    Asset(symbol: 'XAG/USD', displayName: 'Silver / US Dollar',
          category: AssetCategory.metals, abbreviation: 'Ag',
          logoColor: Color(0xFFC0C0C0), pipValue: 0.001,  basePrice: 29.45),
    Asset(symbol: 'XPT/USD', displayName: 'Platinum / US Dollar',
          category: AssetCategory.metals, abbreviation: 'Pt',
          logoColor: Color(0xFFB0C4DE), pipValue: 0.01,   basePrice: 994.50),
    Asset(symbol: 'XPD/USD', displayName: 'Palladium / US Dollar',
          category: AssetCategory.metals, abbreviation: 'Pd',
          logoColor: Color(0xFF8FBC8F), pipValue: 0.01,   basePrice: 1045.00),
    Asset(symbol: 'XCU/USD', displayName: 'Copper / US Dollar',
          category: AssetCategory.metals, abbreviation: 'Cu',
          logoColor: Color(0xFFB87333), pipValue: 0.0001, basePrice: 4.45),
  ];

  // ════════════════════════════════════════════════════════════════════════════
  // ENERGIES & OIL
  // ════════════════════════════════════════════════════════════════════════════

  static const List<Asset> energy = [
    Asset(symbol: 'USOIL',    displayName: 'WTI Crude Oil',
          category: AssetCategory.energy, abbreviation: 'WTI',
          logoColor: Color(0xFFFF8C00), pipValue: 0.01,   basePrice: 78.60),
    Asset(symbol: 'UKOIL',    displayName: 'Brent Crude Oil',
          category: AssetCategory.energy, abbreviation: 'BRT',
          logoColor: Color(0xFFFF6A00), pipValue: 0.01,   basePrice: 82.30),
    Asset(symbol: 'NGAS',     displayName: 'Natural Gas',
          category: AssetCategory.energy, abbreviation: 'GAS',
          logoColor: Color(0xFF4FC3F7), pipValue: 0.001,  basePrice: 2.45),
    Asset(symbol: 'GASOLINE', displayName: 'RBOB Gasoline',
          category: AssetCategory.energy, abbreviation: 'GSL',
          logoColor: Color(0xFFFFB300), pipValue: 0.0001, basePrice: 2.32),
    Asset(symbol: 'HEATING',  displayName: 'Heating Oil',
          category: AssetCategory.energy, abbreviation: 'HTO',
          logoColor: Color(0xFFFF5722), pipValue: 0.0001, basePrice: 2.68),
  ];

  // ════════════════════════════════════════════════════════════════════════════
  // AGRICULTURAL COMMODITIES
  // ════════════════════════════════════════════════════════════════════════════

  static const List<Asset> commodities = [
    Asset(symbol: 'WHEAT',    displayName: 'Wheat (CBOT)',
          category: AssetCategory.commodities, abbreviation: 'WHT',
          logoColor: Color(0xFFF0E68C), pipValue: 0.25,   basePrice: 545.00),
    Asset(symbol: 'CORN',     displayName: 'Corn (CBOT)',
          category: AssetCategory.commodities, abbreviation: 'CRN',
          logoColor: Color(0xFFFFD700), pipValue: 0.25,   basePrice: 428.00),
    Asset(symbol: 'SOYBEANS', displayName: 'Soybeans (CBOT)',
          category: AssetCategory.commodities, abbreviation: 'SOY',
          logoColor: Color(0xFF8BC34A), pipValue: 0.25,   basePrice: 1165.00),
    Asset(symbol: 'COFFEE',   displayName: 'Coffee (Arabica)',
          category: AssetCategory.commodities, abbreviation: 'CFE',
          logoColor: Color(0xFF795548), pipValue: 0.01,   basePrice: 182.50),
    Asset(symbol: 'COTTON',   displayName: 'Cotton No. 2',
          category: AssetCategory.commodities, abbreviation: 'CTN',
          logoColor: Color(0xFFF5F5F5), pipValue: 0.01,   basePrice: 81.25),
    Asset(symbol: 'SUGAR',    displayName: 'Raw Sugar No. 11',
          category: AssetCategory.commodities, abbreviation: 'SGR',
          logoColor: Color(0xFFFFE0B2), pipValue: 0.001,  basePrice: 19.45),
    Asset(symbol: 'COCOA',    displayName: 'Cocoa (ICE)',
          category: AssetCategory.commodities, abbreviation: 'CCO',
          logoColor: Color(0xFF6D4C41), pipValue: 1.0,    basePrice: 8200.00),
    Asset(symbol: 'LUMBER',   displayName: 'Lumber (CME)',
          category: AssetCategory.commodities, abbreviation: 'LMB',
          logoColor: Color(0xFFAD8451), pipValue: 0.1,    basePrice: 548.00),
    Asset(symbol: 'OJ',       displayName: 'Orange Juice (FCOJ)',
          category: AssetCategory.commodities, abbreviation: 'OJ',
          logoColor: Color(0xFFFF9800), pipValue: 0.01,   basePrice: 321.00),
  ];

  // ── All assets combined ────────────────────────────────────────────────────

  static List<Asset> get all => [
    ...forexMajor,
    ...forexMinor,
    ...forexExotic,
    ...metals,
    ...energy,
    ...commodities,
  ];
}
