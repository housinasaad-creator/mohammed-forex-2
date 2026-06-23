import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/locale_provider.dart';
import '../models/asset_model.dart';
import '../providers/dashboard_provider.dart';

class HeaderWidget extends StatefulWidget {
  const HeaderWidget({super.key, this.showBackButton = false});
  final bool showBackButton;

  @override
  State<HeaderWidget> createState() => _HeaderWidgetState();
}

class _HeaderWidgetState extends State<HeaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final lp = context.watch<LocaleProvider>();
    final s = lp.s;

    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      final connected = provider.mt5Connected;
      final dotColor = connected ? AppColors.neonGreen : AppColors.neonRed;
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.headerBg,
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: menu | back | spacer | pair+dot | lang
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Hamburger — opens sidebar drawer
                  Builder(builder: (ctx) => GestureDetector(
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.menu_rounded,
                          size: 18, color: AppColors.textSecondary),
                    ),
                  )),
                  const SizedBox(width: 8),
                  if (widget.showBackButton) ...[
                    _BackHomeButton(label: s.backHome),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  // Active pair compact — tap to open asset picker
                  GestureDetector(
                    onTap: () => _showAssetPicker(context, provider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppColors.borderGold, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, __) => Container(
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                                boxShadow: connected ? [BoxShadow(
                                  color: dotColor.withOpacity(_pulseAnim.value * 0.6),
                                  blurRadius: 5, spreadRadius: 1,
                                )] : [],
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            provider.selectedAsset.symbol,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 14, color: AppColors.gold),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _LangSwitcher(current: lp.lang, onSelect: lp.setLang),
                ],
              ),
            ),
            // Row 2: Timeframe selector (scrollable)
            Container(
              height: 36,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: Row(
                  children: [
                    Text(s.timeframeLabel,
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppColors.textMuted)),
                    const SizedBox(width: 6),
                    ...Timeframe.values.map((tf) => _TimeframeChip(
                          tf: tf,
                          isSelected: provider.selectedTimeframe == tf,
                          onTap: () => provider.selectTimeframe(tf),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final screenW = MediaQuery.of(context).size.width;
    final compact = screenW < 1000;

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.headerBg,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
      child: Row(
        children: [
          if (!compact) _buildBrand(),
          if (!compact) const Spacer(),
          _buildActivePair(provider),
          SizedBox(width: compact ? 10 : 20),
          _buildMt5Status(provider, s),
          SizedBox(width: compact ? 10 : 20),
          _buildTimeframeSelector(provider, s),
          SizedBox(width: compact ? 8 : 16),
          _LangSwitcher(current: lp.lang, onSelect: lp.setLang),
          if (widget.showBackButton) ...[
            SizedBox(width: compact ? 8 : 16),
            _BackHomeButton(label: s.backHome),
          ],
        ],
      ),
    );
  }

  // ── Brand block ────────────────────────────────────────────────────────────

  Widget _buildBrand() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Compact gold circle
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [AppColors.goldLight, AppColors.gold],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.35),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'MF',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.background,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'mohammed ',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                  letterSpacing: 0.2,
                ),
              ),
              TextSpan(
                text: 'forex',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Active pair ────────────────────────────────────────────────────────────

  Widget _buildActivePair(DashboardProvider provider) {
    final asset = provider.selectedAsset;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGold, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: asset.logoColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            asset.symbol,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── MT5 Status ─────────────────────────────────────────────────────────────

  Widget _buildMt5Status(DashboardProvider provider, s) {
    final connected = provider.mt5Connected;
    final statusColor = connected ? AppColors.neonGreen : AppColors.neonRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing dot
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? AppColors.neonGreen : AppColors.neonRed,
                boxShadow: connected
                    ? [
                        BoxShadow(
                          color: AppColors.neonGreen
                              .withOpacity(_pulseAnim.value * 0.7),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            connected ? s.mt5Connected : s.mt5Offline,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Timeframe Selector ─────────────────────────────────────────────────────

  Widget _buildTimeframeSelector(DashboardProvider provider, s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          s.timeframeLabel,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        ...Timeframe.values.map(
          (tf) => _TimeframeChip(
            tf: tf,
            isSelected: provider.selectedTimeframe == tf,
            onTap: () => provider.selectTimeframe(tf),
          ),
        ),
      ],
    );
  }

  void _showAssetPicker(BuildContext context, DashboardProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MobileAssetSheet(provider: provider),
    );
  }
}

// ── Timeframe Chip ─────────────────────────────────────────────────────────────

class _TimeframeChip extends StatefulWidget {
  const _TimeframeChip({
    required this.tf,
    required this.isSelected,
    required this.onTap,
  });

  final Timeframe tf;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_TimeframeChip> createState() => _TimeframeChipState();
}

class _TimeframeChipState extends State<_TimeframeChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: widget.isSelected
                ? AppColors.gold
                : _hovered
                    ? AppColors.surfaceHigh
                    : AppColors.surface,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Text(
            widget.tf.label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.isSelected
                  ? AppColors.background
                  : AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Language Switcher ──────────────────────────────────────────────────────────

class _LangSwitcher extends StatelessWidget {
  const _LangSwitcher({required this.current, required this.onSelect});
  final String current;
  final ValueChanged<String> onSelect;

  static const _langs = [('AR', 'ar'), ('EN', 'en'), ('TR', 'tr')];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _langs.map((l) {
          final isActive = l.$2 == current;
          return _LangBtn(code: l.$1, lang: l.$2, isActive: isActive, onTap: () => onSelect(l.$2));
        }).toList(),
      ),
    );
  }
}

class _LangBtn extends StatefulWidget {
  const _LangBtn({required this.code, required this.lang, required this.isActive, required this.onTap});
  final String code, lang;
  final bool isActive;
  final VoidCallback onTap;
  @override
  State<_LangBtn> createState() => _LangBtnState();
}
class _LangBtnState extends State<_LangBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isActive ? AppColors.gold : (_hov ? AppColors.surfaceHigh : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
            boxShadow: widget.isActive ? [BoxShadow(color: AppColors.gold.withOpacity(0.3), blurRadius: 8)] : [],
          ),
          child: Text(
            widget.code,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: widget.isActive ? AppColors.background : (_hov ? AppColors.gold : AppColors.textSecondary),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Back to Home Button ────────────────────────────────────────────────────────

class _BackHomeButton extends StatefulWidget {
  const _BackHomeButton({required this.label});
  final String label;
  @override
  State<_BackHomeButton> createState() => _BackHomeButtonState();
}

class _BackHomeButtonState extends State<_BackHomeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHigh : AppColors.surface,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded,
                  size: 14,
                  color: _hovered ? AppColors.gold : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? AppColors.gold : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile Asset Picker Sheet ──────────────────────────────────────────────────

class _MobileAssetSheet extends StatefulWidget {
  const _MobileAssetSheet({required this.provider});
  final DashboardProvider provider;

  @override
  State<_MobileAssetSheet> createState() => _MobileAssetSheetState();
}

class _MobileAssetSheetState extends State<_MobileAssetSheet> {
  final Set<AssetCategory> _expanded = {AssetCategory.forexMajor};

  static const _categories = [
    (AssetCategory.forexMajor,  AssetCatalogue.forexMajor),
    (AssetCategory.forexMinor,  AssetCatalogue.forexMinor),
    (AssetCategory.forexExotic, AssetCatalogue.forexExotic),
    (AssetCategory.metals,      AssetCatalogue.metals),
    (AssetCategory.energy,      AssetCatalogue.energy),
    (AssetCategory.commodities, AssetCatalogue.commodities),
  ];


  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Text(
                  s.selectAssetHint,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // Asset list
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: _categories.map((entry) {
                  final cat = entry.$1;
                  final assets = entry.$2;
                  final isOpen = _expanded.contains(cat);
                  return Column(
                    children: [
                      // Category header
                      GestureDetector(
                        onTap: () => setState(() {
                          if (isOpen) _expanded.remove(cat);
                          else _expanded.add(cat);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              Text(
                                s.categoryLabel(cat),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                isOpen
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isOpen)
                        ...assets.map((asset) {
                          final isSelected =
                              widget.provider.selectedAsset.symbol == asset.symbol;
                          return GestureDetector(
                            onTap: () {
                              widget.provider.selectAsset(asset);
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.gold.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.gold.withOpacity(0.4)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: asset.logoColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    asset.symbol,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.gold
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isSelected) ...[
                                    const Spacer(),
                                    const Icon(Icons.check_rounded,
                                        size: 14, color: AppColors.gold),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
