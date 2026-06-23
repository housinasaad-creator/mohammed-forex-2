import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_provider.dart';
import '../models/analysis_result.dart';
import '../models/asset_model.dart';

class AnalysisResultCard extends StatefulWidget {
  const AnalysisResultCard({
    super.key,
    required this.result,
    required this.asset,
    required this.timeframe,
  });

  final AnalysisResult result;
  final Asset asset;
  final Timeframe timeframe;

  @override
  State<AnalysisResultCard> createState() => _AnalysisResultCardState();
}

class _AnalysisResultCardState extends State<AnalysisResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late AppStrings _s;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _s = context.watch<LocaleProvider>().s;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSignalHeader(),
            if (widget.result.summary.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildSummaryCard(),
            ],
            const SizedBox(height: 14),
            _buildPriceLevels(),
            const SizedBox(height: 14),
            _buildDeepAnalysisPanel(),
            const SizedBox(height: 14),
            _buildConfluence(),
            const SizedBox(height: 14),
            _buildClaudeBox(),
          ],
        ),
      ),
    );
  }

  // ── Signal Header ──────────────────────────────────────────────────────────

  Widget _buildSignalHeader() {
    final sig = widget.result.signal;
    final color = sig.primaryColor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Signal badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(sig.icon, color: AppColors.background, size: 20),
                const SizedBox(width: 8),
                Text(
                  _s.signalLabel(sig),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.background,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.asset.symbol,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${widget.timeframe.label} · ${widget.result.analysisTimestamp}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Accuracy
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.result.accuracy.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                _s.accuracyLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'R:R ${widget.result.riskRewardRatio.toStringAsFixed(1)}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Summary Card (عصارة التحليل) ──────────────────────────────────────────

  Widget _buildSummaryCard() {
    final result  = widget.result;
    final hasWarn = result.sessionWarning.isNotEmpty;
    final hasPat  = result.candlePattern.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasWarn
              ? AppColors.waitAmber.withOpacity(0.5)
              : AppColors.gold.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.gold),
              const SizedBox(width: 6),
              Text(
                _s.summaryLabel.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              // Session chip
              _SessionChip(
                name: result.sessionName,
                hasWarning: hasWarn,
              ),
              if (hasPat) ...[
                const SizedBox(width: 6),
                _PatternChip(
                  pattern: result.candlePattern,
                  signal: result.signal,
                  s: _s,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Summary text
          Text(
            result.summary,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  // ── Price Levels ───────────────────────────────────────────────────────────

  Widget _buildPriceLevels() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(_s.tradeParameters, Icons.tune_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PriceLevel(
                  label: _s.entryLabel,
                  value: _fmtPrice(widget.result.entryPoint, widget.asset),
                  color: AppColors.gold,
                  icon: Icons.my_location_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PriceLevel(
                  label: _s.stopLossLabel,
                  value: _fmtPrice(widget.result.stopLoss, widget.asset),
                  color: AppColors.neonRed,
                  icon: Icons.shield_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PriceLevel(
                  label: _s.takeProfitLabel,
                  value: _fmtPrice(widget.result.takeProfit, widget.asset),
                  color: AppColors.neonGreen,
                  icon: Icons.flag_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Deep Analysis Panel (SMC + BB + Divergence) ───────────────────────────

  Widget _buildDeepAnalysisPanel() {
    final r = widget.result;
    final isBuy = r.signal == SignalType.buy;

    // BB position
    final bbRange = r.bbUpper - r.bbLower;
    final bbPos   = bbRange > 0 ? (r.entryPoint - r.bbLower) / bbRange : 0.5;
    final bbLabel = bbPos < 0.12 ? _s.t(ar: 'عند النطاق السفلي ↔ فرصة', en: 'Near Lower Band ↔ Opportunity', tr: 'Alt Bant Yakını ↔ Fırsat')
                  : bbPos > 0.88 ? _s.t(ar: 'عند النطاق العلوي ↔ تحذير', en: 'Near Upper Band ↔ Caution', tr: 'Üst Bant Yakını ↔ Dikkat')
                  : _s.t(ar: 'في منتصف النطاق', en: 'Near Midline', tr: 'Orta Çizgi Yakını');
    final bbColor = bbPos < 0.12 ? AppColors.neonGreen
                  : bbPos > 0.88 ? AppColors.neonRed
                  : AppColors.textMuted;

    final rows = <_DeepRow>[];

    // SMC rows
    if (r.smcBos.isNotEmpty) {
      final isBull = r.smcBos.contains('↑');
      rows.add(_DeepRow(
        label: 'BOS/CHoCH',
        value: r.smcBos,
        color: isBull ? AppColors.neonGreen : AppColors.neonRed,
        icon: isBull ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      ));
    }
    if (r.smcOrderBlock.isNotEmpty) {
      final isBullOb = r.smcOrderBlock.contains('Bullish');
      rows.add(_DeepRow(
        label: 'Order Block',
        value: r.smcOrderBlock,
        color: isBullOb ? AppColors.neonGreen : AppColors.neonRed,
        icon: Icons.crop_square_rounded,
      ));
    }
    if (r.smcLiqSweep.isNotEmpty) {
      final isBullSweep = r.smcLiqSweep.contains('Bullish');
      rows.add(_DeepRow(
        label: _s.t(ar: 'اصطياد سيولة', en: 'Liquidity Sweep', tr: 'Likidite Süpürmesi'),
        value: r.smcLiqSweep,
        color: isBullSweep ? AppColors.neonGreen : AppColors.neonRed,
        icon: Icons.waves_rounded,
      ));
    }
    if (r.smcFvg.isNotEmpty) {
      final isBullFvg = r.smcFvg.contains('Bullish');
      rows.add(_DeepRow(
        label: 'FVG',
        value: r.smcFvg,
        color: isBullFvg ? AppColors.neonGreen.withOpacity(0.8) : AppColors.neonRed.withOpacity(0.8),
        icon: Icons.space_bar_rounded,
      ));
    }

    // Bollinger row (only if we have real BB data)
    if (r.bbUpper > 0) {
      rows.add(_DeepRow(
        label: 'Bollinger Bands',
        value: bbLabel,
        color: bbColor,
        icon: Icons.show_chart_rounded,
      ));
    }

    // RSI Divergence
    if (r.rsiBullishDivergence) {
      rows.add(_DeepRow(
        label: _s.t(ar: 'انحراف RSI', en: 'RSI Divergence', tr: 'RSI Uyumsuzluğu'),
        value: _s.t(ar: 'انحراف صاعد ✓ — السعر أدنى، RSI أعلى', en: 'Bullish Div. ✓ — Price lower, RSI higher', tr: 'Yükseliş Div. ✓ — Fiyat altta, RSI yukarıda'),
        color: AppColors.neonGreen,
        icon: Icons.show_chart_rounded,
      ));
    } else if (r.rsiBearishDivergence) {
      rows.add(_DeepRow(
        label: _s.t(ar: 'انحراف RSI', en: 'RSI Divergence', tr: 'RSI Uyumsuzluğu'),
        value: _s.t(ar: 'انحراف هابط ✓ — السعر أعلى، RSI أدنى', en: 'Bearish Div. ✓ — Price higher, RSI lower', tr: 'Düşüş Div. ✓ — Fiyat yukarıda, RSI altta'),
        color: AppColors.neonRed,
        icon: Icons.show_chart_rounded,
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle(
                _s.t(ar: 'التحليل المعمّق', en: 'DEEP ANALYSIS', tr: 'DERİN ANALİZ'),
                Icons.hub_rounded,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.gold.withOpacity(0.25)),
                ),
                child: Text(
                  'SMC + BB + DIV',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: row.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: row.color.withOpacity(0.3), width: 0.8),
                  ),
                  child: Icon(row.icon, size: 11, color: row.color),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: Text(
                    row.label,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: row.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── Confluence ─────────────────────────────────────────────────────────────

  Widget _buildConfluence() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(_s.technicalConfluence, Icons.layers_rounded),
          const SizedBox(height: 12),
          ...widget.result.confluenceFactors.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.value,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Sentiment ───────────────────────────────────────────────────────────

  Widget _buildAiSentiment() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(_s.aiMarketSentiment, Icons.psychology_rounded),
          const SizedBox(height: 10),
          Text(
            widget.result.aiSentiment,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  // ── Claude Box ─────────────────────────────────────────────────────────────

  Widget _buildClaudeBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'CLAUDE AI',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.background,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _s.claudeExpertLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.waitAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.waitAmber.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  'API Ready',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: AppColors.waitAmber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.result.claudeOpinion,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.gold),
        const SizedBox(width: 7),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  String _fmtPrice(double price, Asset asset) {
    if (asset.pipValue < 0.01) return price.toStringAsFixed(5);
    if (asset.pipValue < 0.1) return price.toStringAsFixed(3);
    return price.toStringAsFixed(2);
  }
}

// ── Session chip ──────────────────────────────────────────────────────────────

class _SessionChip extends StatelessWidget {
  const _SessionChip({required this.name, required this.hasWarning});
  final String name;
  final bool   hasWarning;

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();
    final color = hasWarning ? AppColors.waitAmber : AppColors.neonGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasWarning ? Icons.warning_amber_rounded : Icons.public_rounded,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pattern chip ───────────────────────────────────────────────────────────────

class _PatternChip extends StatelessWidget {
  const _PatternChip({
    required this.pattern,
    required this.signal,
    required this.s,
  });
  final String      pattern;
  final SignalType  signal;
  final AppStrings  s;

  @override
  Widget build(BuildContext context) {
    final isBull = pattern.startsWith('Bullish');
    final color  = isBull ? AppColors.neonGreen : AppColors.neonRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.candlestick_chart_outlined, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            s.patternName(pattern),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Deep Row data class ────────────────────────────────────────────────────────

class _DeepRow {
  const _DeepRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String  label;
  final String  value;
  final Color   color;
  final IconData icon;
}

// ── Price Level chip ───────────────────────────────────────────────────────────

class _PriceLevel extends StatelessWidget {
  const _PriceLevel({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
