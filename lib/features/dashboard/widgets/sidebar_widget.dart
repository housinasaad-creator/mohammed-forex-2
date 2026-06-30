import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/dashboard_provider.dart';

// Single-pair focus mode: the asset picker is gone on purpose. Testing one
// pair (EUR/USD) at a time gives a clean read on whether the system has real
// edge, without the noise of switching between assets with very different
// volatility profiles.
class SidebarWidget extends StatelessWidget {
  const SidebarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 262,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          _buildLogo(),
          const Divider(color: AppColors.border, height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFocusPanel(context),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  // ── Logo Panel ─────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Row(
        children: [
          _GoldCircleLogo(size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'mohammed',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                    letterSpacing: 0.3,
                    height: 1.1,
                  ),
                ),
                Text(
                  'forex',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Locked single-asset panel ───────────────────────────────────────────────

  Widget _buildFocusPanel(BuildContext context) {
    final asset = context.watch<DashboardProvider>().selectedAsset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FOCUS MODE',
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderGold, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: asset.logoColor.withOpacity(0.15),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    asset.abbreviation,
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.symbol,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold)),
                    Text(asset.displayName,
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'الأداة مخصصة حالياً لتحليل EUR/USD فقط — لتقييم نظيف ودقيق لمدى نجاحها قبل توسيعها لأزواج أخرى.',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, height: 1.6),
        ),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            'v2.0.0 · Multi-Agent Engine',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _GoldCircleLogo extends StatelessWidget {
  const _GoldCircleLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDim],
          stops: [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'MF',
          style: GoogleFonts.inter(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w900,
            color: AppColors.background,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
