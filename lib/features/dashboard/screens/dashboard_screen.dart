import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/locale_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/header_widget.dart';
import '../widgets/technical_gauges_widget.dart';
import '../widgets/ai_execution_chamber_widget.dart';
import '../widgets/candlestick_chart_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.showBackButton = false});
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final chartH   = isMobile ? 240.0 : 340.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Sidebar slides in as a drawer on mobile
      drawer: isMobile
          ? Drawer(
              width: 262,
              backgroundColor: AppColors.sidebarBg,
              child: const SidebarWidget(),
            )
          : null,
      body: Stack(
        children: [
          const _AmbientGlow(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sidebar — desktop only (mobile uses drawer)
              if (!isMobile) const SidebarWidget(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HeaderWidget(showBackButton: showBackButton),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: chartH,
                              child: Stack(
                                children: [
                                  const CandlestickChartWidget(),
                                  // Floating analyze button — mobile only
                                  if (isMobile)
                                    const Positioned(
                                      bottom: 14,
                                      left: 0,
                                      right: 0,
                                      child: Center(child: _MobileAnalyzeButton()),
                                    ),
                                ],
                              ),
                            ),
                            const _TradeNoteBanner(),
                            // Gauges + Chamber: side-by-side on desktop, stacked on mobile
                            isMobile
                                ? const Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TechnicalGaugesWidget(scrollable: false),
                                      AiExecutionChamberWidget(scrollable: false),
                                    ],
                                  )
                                : const IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Flexible(
                                          flex: 4,
                                          child: TechnicalGaugesWidget(scrollable: false),
                                        ),
                                        Flexible(
                                          flex: 6,
                                          child: AiExecutionChamberWidget(scrollable: false),
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const _BottomBar(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Mobile Floating Analyze Button ────────────────────────────────────────────

class _MobileAnalyzeButton extends StatelessWidget {
  const _MobileAnalyzeButton();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final lp      = context.watch<LocaleProvider>();
    final s       = lp.s;

    if (provider.isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.sidebarBg.withOpacity(0.93),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              s.analysingLabel,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => provider.runAnalysis(lang: lp.lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withOpacity(0.45),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.background, size: 18),
            const SizedBox(width: 7),
            Text(
              s.analyzeNowBtn,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.background,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trade Note Banner ──────────────────────────────────────────────────────────

class _TradeNoteBanner extends StatelessWidget {
  const _TradeNoteBanner();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final note = provider.result?.tradeNote ?? '';
    if (note.isEmpty) return const SizedBox.shrink();

    final isWait   = note.startsWith('⏸');
    final color    = isWait ? AppColors.waitAmber : AppColors.gold;
    final icon     = isWait ? Icons.pause_circle_outline_rounded : Icons.timer_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border(
          bottom: BorderSide(color: color.withOpacity(0.25), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: color.withOpacity(0.9),
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ambient Background Glow ────────────────────────────────────────────────────

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Top-left gold glow near sidebar
            Positioned(
              top: -120,
              left: -80,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withOpacity(0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Center-right subtle glow
            Positioned(
              bottom: -100,
              right: 100,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.neonGreen.withOpacity(0.025),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Status Bar ──────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Container(
      height: 30,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: isMobile
          ? Center(
              child: Text(
                'mohammed forex  ·  ${s.advancedDashboard}',
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.3),
              ),
            )
          : Row(
              children: [
                Text(
                  'mohammed forex  ·  ${s.advancedDashboard}  ·  ${s.confluenceEngine}',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.3),
                ),
                const Spacer(),
                Text(
                  'Portfolio Build  ·  Claude Sonnet 4.6 API Ready  ·  MT5 Bridge Ready',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.3),
                ),
              ],
            ),
    );
  }
}
