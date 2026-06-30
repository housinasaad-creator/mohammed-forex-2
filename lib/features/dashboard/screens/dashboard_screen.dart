import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/locale_provider.dart';
import '../models/analysis_result.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/header_widget.dart';
import '../widgets/candlestick_chart_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.showBackButton = false});
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
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
              if (!isMobile) const SidebarWidget(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HeaderWidget(showBackButton: showBackButton),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Use almost all available space — no wasted margins
                          final maxW   = math.min(constraints.maxWidth * 0.96, 1280.0);
                          final chartH = isMobile
                              ? 280.0
                              : (constraints.maxHeight * 0.62).clamp(420.0, 760.0);
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxW),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const _LowLiquidityBanner(),
                                    _ChartSection(chartH: chartH),
                                    const SizedBox(height: 22),
                                    const _DecisionBadge(),
                                    const SizedBox(height: 22),
                                    const _ConfidenceGauge(),
                                    const SizedBox(height: 18),
                                    const _ExportImageButton(),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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

// ── Chart Section: live plain chart (idle) → composed AI chart (after result) ──
//
// Two distinct layouts, not one Stack squeezed into a fixed box:
//  - Idle/loading: fixed-height placeholder chart with an overlay button —
//    nothing baked-in to protect, so overlaying is fine.
//  - Result ready: the composed PNG (chart + decision band + Entry/SL/TP
//    footer, all baked into the image) is shown at its NATURAL aspect ratio
//    (full width, auto height) so its text never gets squeezed unreadably
//    small on narrow screens, and the re-run button sits BELOW it instead of
//    floating on top — it must never cover the footer numbers.

class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.chartH});
  final double chartH;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final result   = provider.result;
    final bytes    = result?.chartImageBytes;
    final loading  = provider.isLoading;

    if (!loading && bytes != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              color: AppColors.sidebarBg,
              child: Image.memory(bytes, width: double.infinity, fit: BoxFit.fitWidth, gaplessPlayback: true),
            ),
          ),
          const SizedBox(height: 14),
          const Center(child: _AnalyzeButton()),
        ],
      );
    }

    return SizedBox(
      height: chartH,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (loading) Container(color: AppColors.sidebarBg) else const CandlestickChartWidget(),
            if (!loading)
              const Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Center(child: _AnalyzeButton()),
              ),
            if (loading) const Positioned.fill(child: _LoadingOverlay()),
          ],
        ),
      ),
    );
  }
}

// ── Loading Overlay — spinner + live elapsed-time counter ──────────────────────

class _LoadingOverlay extends StatefulWidget {
  const _LoadingOverlay();

  @override
  State<_LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<_LoadingOverlay> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    return Container(
      color: AppColors.background.withOpacity(0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26, height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.gold),
            ),
            const SizedBox(height: 14),
            Text(
              '${s.analysingLabel}  ·  ${_seconds}s',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                s.t(
                  ar: 'قد يستغرق حتى دقيقة — 4 وكلاء يحللون السوق والأخبار الحية بالتوازي',
                  en: 'May take up to a minute — 4 agents analyzing market & live news in parallel',
                  tr: 'Bir dakikaya kadar sürebilir — 4 ajan paralel olarak piyasayı ve canlı haberleri analiz ediyor',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Analyze Button (floating) ───────────────────────────────────────────────────

class _AnalyzeButton extends StatelessWidget {
  const _AnalyzeButton({this.loadingOverride = false});
  final bool loadingOverride;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final lp = context.watch<LocaleProvider>();
    final s = lp.s;

    if (provider.isLoading || loadingOverride) {
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
              child: CircularProgressIndicator(strokeWidth: 1.8, color: AppColors.gold),
            ),
            const SizedBox(width: 10),
            Text(s.analysingLabel,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gold)),
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
          boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.45), blurRadius: 20, spreadRadius: 1)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.background, size: 18),
            const SizedBox(width: 7),
            Text(s.analyzeNowBtn,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.background, letterSpacing: 0.4)),
          ],
        ),
      ),
    );
  }
}

// ── Low-Liquidity Banner — Asian session 00:00-09:00 Turkey time ───────────────
// Independent of any analysis result — a live clock check, always in sync
// with the same window baked into the exported image.

class _LowLiquidityBanner extends StatefulWidget {
  const _LowLiquidityBanner();

  @override
  State<_LowLiquidityBanner> createState() => _LowLiquidityBannerState();
}

class _LowLiquidityBannerState extends State<_LowLiquidityBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isLowLiquidity {
    final turkeyNow = DateTime.now().toUtc().add(const Duration(hours: 3));
    return turkeyNow.hour >= 0 && turkeyNow.hour < 9;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLowLiquidity) return const SizedBox.shrink();
    final s = context.watch<LocaleProvider>().s;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.waitAmber.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.waitAmber.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.waitAmber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.t(
                ar: '⚠️ تحذير: سيولة ضعيفة - تجنّب الدخول الآن',
                en: '⚠️ Warning: Weak Liquidity - No Entry',
                tr: '⚠️ Uyarı: Zayıf Likidite - Giriş Yapma',
              ),
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.waitAmber),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Decision Badge — the single most important element on screen ──────────────

class _DecisionBadge extends StatelessWidget {
  const _DecisionBadge();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final s = context.watch<LocaleProvider>().s;
    final result = provider.result;

    if (result == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(s.selectAssetHint,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
        ),
      );
    }

    final sig = result.signal;
    final color = sig.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 30, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(sig.icon, color: color, size: 38),
              const SizedBox(width: 14),
              Text(
                s.signalLabel(sig),
                style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.5),
              ),
            ],
          ),
          if (result.sessionName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.textMuted.withOpacity(0.3)),
              ),
              child: Text(
                '${s.t(ar: "الجلسة الحالية", en: "Current Session", tr: "Mevcut Seans")}: ${result.sessionName}',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ),
          ],
          if (sig != SignalType.wait && (result.riskPercent > 0 || result.hardExitTime.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                if (result.riskPercent > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                    ),
                    child: Text(
                      '${s.t(ar: "نسبة المخاطرة المقترحة", en: "Suggested Risk", tr: "Önerilen Risk")}: ${result.riskPercent.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.gold),
                    ),
                  ),
                if (result.hardExitTime.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Text(
                      '🔒 ${s.t(ar: "وقت الخروج الإجباري", en: "Hard Exit Time", tr: "Zorunlu Çıkış Saati")}: ${result.hardExitTime}',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
              ],
            ),
          ],
          if (result.exitNote.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              result.exitNote,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Confidence Gauge — static circular meter, updates only on new analysis ─────

class _ConfidenceGauge extends StatelessWidget {
  const _ConfidenceGauge();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final s = context.watch<LocaleProvider>().s;
    final result = provider.result;
    final pct = result?.accuracy ?? 0.0;
    final color = result?.signal.primaryColor ?? AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _GaugePainter(percent: pct / 100, color: color),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${pct.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
                    Text(s.accuracyLabel,
                        style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted, letterSpacing: 0.8)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.percent, required this.color});
  final double percent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = 2.35619; // 135°
    const sweepFull  = 4.71239; // 270°

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepFull, false,
      Paint()
        ..color = AppColors.gaugeTrack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepFull * percent.clamp(0, 1), false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.percent != percent || old.color != color;
}

// ── Export Image Button ─────────────────────────────────────────────────────────

class _ExportImageButton extends StatelessWidget {
  const _ExportImageButton();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final s = context.watch<LocaleProvider>().s;
    final bytes = provider.result?.chartImageBytes;
    if (bytes == null) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: () => _download(bytes, provider.selectedAsset.symbol),
      icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.gold),
      label: Text(s.t(ar: 'تصدير صورة التحليل', en: 'Export Analysis Image', tr: 'Analiz Görselini İndir'),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gold)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.borderGold),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _download(Uint8List bytes, String symbol) {
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '${symbol.replaceAll('/', '')}_analysis.png')
      ..click();
    html.Url.revokeObjectUrl(url);
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
            Positioned(
              top: -120,
              left: -80,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.gold.withOpacity(0.04), Colors.transparent]),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: 100,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.neonGreen.withOpacity(0.025), Colors.transparent]),
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
              child: Text('mohammed forex  ·  ${s.advancedDashboard}',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.3)),
            )
          : Row(
              children: [
                Text('mohammed forex  ·  ${s.advancedDashboard}',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.3)),
                const Spacer(),
                Text('Multi-Agent Engine  ·  30m Trade Window  ·  MT5 Bridge Ready',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.3)),
              ],
            ),
    );
  }
}
