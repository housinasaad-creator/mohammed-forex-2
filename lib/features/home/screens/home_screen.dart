import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/economic_calendar_service.dart';
import '../../../core/services/forex_service.dart';
import '../../../core/services/sparkline_service.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../dashboard/widgets/animated_hover_button.dart';

// ══════════════════════════════════════════════════════════════════════════════
// HOME SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollCtrl = ScrollController();
  double _scrollY = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (mounted) setState(() => _scrollY = _scrollCtrl.offset);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _launchTool() {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => const DashboardScreen(showBackButton: true),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollCtrl,
            child: Column(
              children: [
                const SizedBox(height: 72),
                _HeroSection(onLaunch: _launchTool),
                _MarketTickerStrip(),
                _FeaturesSection(onLaunch: _launchTool),
                _ToolShowcase(onLaunch: _launchTool),
                _WhyUsSection(),
                _NewsSection(),
                _Footer(),
              ],
            ),
          ),
          _StickyNav(scrollY: _scrollY, onLaunch: _launchTool),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STICKY NAVIGATION BAR
// ══════════════════════════════════════════════════════════════════════════════

class _StickyNav extends StatefulWidget {
  const _StickyNav({required this.scrollY, required this.onLaunch});
  final double scrollY;
  final VoidCallback onLaunch;

  @override
  State<_StickyNav> createState() => _StickyNavState();
}

class _StickyNavState extends State<_StickyNav> {
  String? _hoveredLink;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    final scrolled = widget.scrollY > 20;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final links = [
      (s.markets,  'markets'),
      (s.platforms, 'platforms'),
      (s.education, 'education'),
      (s.about,     'about'),
      (s.contact,   'contact'),
    ];

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 64,
        decoration: BoxDecoration(
          color: scrolled
              ? AppColors.sidebarBg.withOpacity(0.97)
              : Colors.transparent,
          border: scrolled
              ? const Border(
                  bottom: BorderSide(color: AppColors.border, width: 1))
              : null,
          boxShadow: scrolled
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2)
                ]
              : [],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
          child: Row(
            children: [
              _NavLogo(),
              const Spacer(),
              if (!isMobile) ...[
                Row(
                  children: links
                      .map((l) => _NavLink(
                            label: l.$1,
                            linkId: l.$2,
                            isHovered: _hoveredLink == l.$2,
                            onHover: (v) => setState(
                                () => _hoveredLink = v ? l.$2 : null),
                          ))
                      .toList(),
                ),
                const SizedBox(width: 20),
              ],
              _HomeLangSwitcher(),
              if (!isMobile) ...[
                const SizedBox(width: 20),
                _NavAuthButtons(onLaunch: widget.onLaunch),
              ] else ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onLaunch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gold, AppColors.goldLight],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.ctaStart,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.background,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final circle = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
            colors: [AppColors.goldLight, AppColors.gold]),
        boxShadow: [
          BoxShadow(
              color: AppColors.gold.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 1)
        ],
      ),
      child: Center(
        child: Text('MF',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.background)),
      ),
    );
    if (isMobile) return circle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(children: [
            TextSpan(
                text: 'mohammed ',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold)),
            TextSpan(
                text: 'forex',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textSecondary)),
          ]),
        ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.linkId,
    required this.isHovered,
    required this.onHover,
  });

  final String label;
  final String linkId;
  final bool isHovered;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isHovered ? FontWeight.w600 : FontWeight.w400,
            color: isHovered ? AppColors.gold : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _NavAuthButtons extends StatelessWidget {
  const _NavAuthButtons({required this.onLaunch});
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedHoverOutlinedButton(
          label: s.login,
          borderColor: AppColors.border,
          textColor: AppColors.textSecondary,
          glowColor: AppColors.textMuted,
          height: 38,
          fontSize: 12,
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        AnimatedHoverButton(
          label: s.openAccount,
          height: 38,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          glowColor: AppColors.gold,
          onPressed: onLaunch,
        ),
      ],
    );
  }
}

// ── Home Language Switcher ────────────────────────────────────────────────────

class _HomeLangSwitcher extends StatelessWidget {
  const _HomeLangSwitcher();

  static const _langs = [('AR', 'ar'), ('EN', 'en'), ('TR', 'tr')];

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _langs.map((l) {
          final active = lp.lang == l.$2;
          return GestureDetector(
            onTap: () => context.read<LocaleProvider>().setLang(l.$2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active ? AppColors.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                l.$1,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.background : AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HERO SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _HeroSection extends StatefulWidget {
  const _HeroSection({required this.onLaunch});
  final VoidCallback onLaunch;

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return SizedBox(
      height: isMobile ? 580 : 580,
      child: Stack(
        children: [
          // Background — always Positioned.fill to avoid unbounded size
          const Positioned.fill(child: _WorldMapBackground()),
          // Content
          Positioned.fill(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Builder(builder: (ctx) {
                  final s = ctx.watch<LocaleProvider>().s;
                  return Center(
                    child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 0,
                      vertical: isMobile ? 20 : 0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AiBadge(),
                        SizedBox(height: isMobile ? 16 : 24),
                        _HeroHeadline(),
                        SizedBox(height: isMobile ? 12 : 16),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 80),
                          child: Text(
                            s.heroSubtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 14 : 16,
                              color: AppColors.textSecondary,
                              height: 1.7,
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 24 : 36),
                        if (isMobile)
                          Column(
                            children: [
                              AnimatedHoverButton(
                                label: s.ctaStart,
                                icon: Icons.rocket_launch_rounded,
                                height: 50,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                glowColor: AppColors.gold,
                                width: double.infinity,
                                onPressed: widget.onLaunch,
                              ),
                              const SizedBox(height: 10),
                              AnimatedHoverOutlinedButton(
                                label: s.ctaTry,
                                icon: Icons.bar_chart_rounded,
                                height: 50,
                                glowColor: AppColors.neonGreen,
                                borderColor: AppColors.neonGreen,
                                textColor: AppColors.neonGreen,
                                fontSize: 14,
                                onPressed: widget.onLaunch,
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedHoverButton(
                                label: s.ctaStart,
                                icon: Icons.rocket_launch_rounded,
                                height: 54,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                glowColor: AppColors.gold,
                                width: 220,
                                onPressed: widget.onLaunch,
                              ),
                              const SizedBox(width: 14),
                              AnimatedHoverOutlinedButton(
                                label: s.ctaTry,
                                icon: Icons.bar_chart_rounded,
                                height: 54,
                                glowColor: AppColors.neonGreen,
                                borderColor: AppColors.neonGreen,
                                textColor: AppColors.neonGreen,
                                fontSize: 15,
                                onPressed: widget.onLaunch,
                              ),
                            ],
                          ),
                        SizedBox(height: isMobile ? 28 : 44),
                        _HeroStats(),
                      ],
                    ),
                  ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.borderGold, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 14, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(
            context.watch<LocaleProvider>().s.aiBadge,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.gold,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _HeroHeadline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [AppColors.gold, AppColors.goldLight, AppColors.gold],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bounds),
      child: Text(
        context.watch<LocaleProvider>().s.heroHeadline,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: isMobile ? 28 : 44,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.2,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _HeroStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final stats = [
      ('58+',  s.statAssets),
      ('87%+', s.statAccuracy),
      ('3',    s.statTimeframes),
      ('MT5',  s.statMt5Ready),
    ];
    if (isMobile) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        runSpacing: 12,
        children: stats.map((e) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.$1,
                style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.gold)),
            Text(e.$2,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.3)),
          ],
        )).toList(),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: stats.asMap().entries.map((e) {
        final isLast = e.key == stats.length - 1;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                Text(e.value.$1,
                    style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold)),
                Text(e.value.$2,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        letterSpacing: 0.3)),
              ],
            ),
            if (!isLast)
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 28),
                color: AppColors.border,
              ),
          ],
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LIVE CANDLESTICK CHART BACKGROUND
// ══════════════════════════════════════════════════════════════════════════════
// WORLD MAP BACKGROUND
// ══════════════════════════════════════════════════════════════════════════════

class _WorldMapBackground extends StatelessWidget {
  const _WorldMapBackground();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.78,
      child: Image.asset(
        'assets/images/world_network.jpg',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

// _WorldMapPainter removed — replaced by Image.asset in _WorldMapBackground

// ignore: unused_element
class _WorldMapPainter extends CustomPainter {
  final double t;
  const _WorldMapPainter({required this.t});

  // Major financial cities [x_norm, y_norm] — equirectangular projection
  // x = (lon + 180) / 360,  y = (90 - lat) / 180
  static const List<List<double>> _cities = [
    [0.294, 0.274], // 0  New York
    [0.172, 0.311], // 1  Los Angeles
    [0.257, 0.278], // 2  Chicago
    [0.280, 0.258], // 3  Toronto
    [0.224, 0.390], // 4  Mexico City
    [0.212, 0.267], // 5  Vancouver
    [0.371, 0.631], // 6  São Paulo
    [0.338, 0.692], // 7  Buenos Aires
    [0.362, 0.537], // 8  Bogotá
    [0.499, 0.271], // 9  London
    [0.506, 0.284], // 10 Paris
    [0.537, 0.264], // 11 Berlin
    [0.514, 0.265], // 12 Amsterdam
    [0.524, 0.277], // 13 Frankfurt
    [0.580, 0.303], // 14 Istanbul
    [0.587, 0.333], // 15 Cairo
    [0.509, 0.482], // 16 Lagos
    [0.578, 0.645], // 17 Johannesburg
    [0.604, 0.248], // 18 Moscow
    [0.654, 0.347], // 19 Dubai
    [0.703, 0.391], // 20 Mumbai
    [0.779, 0.428], // 21 Bangkok
    [0.782, 0.491], // 22 Kuala Lumpur
    [0.788, 0.496], // 23 Singapore
    [0.823, 0.278], // 24 Beijing
    [0.837, 0.330], // 25 Shanghai
    [0.817, 0.382], // 26 Hong Kong
    [0.853, 0.312], // 27 Seoul
    [0.888, 0.317], // 28 Tokyo
    [0.906, 0.643], // 29 Melbourne
    [0.920, 0.622], // 30 Sydney
    [0.524, 0.241], // 31 Zurich
    [0.568, 0.269], // 32 Warsaw
    [0.468, 0.295], // 33 Madrid
  ];

  static const List<List<int>> _connections = [
    [0, 9],   [0, 2],   [3, 0],   [9, 10],  [9, 11],  [9, 12],
    [10, 13], [11, 18], [14, 15], [15, 19], [15, 16], [16, 17],
    [18, 14], [18, 32], [19, 20], [20, 21], [21, 22], [22, 23],
    [23, 26], [24, 25], [24, 27], [25, 26], [27, 28], [28, 25],
    [28, 30], [6, 7],   [0, 6],   [9, 18],  [19, 23], [9, 31],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawContinents(canvas, size);
    _drawConnections(canvas, size);
    _drawCities(canvas, size);
    _drawVignette(canvas, size);
  }

  Offset _pos(int idx, Size size) => Offset(
        _cities[idx][0] * size.width,
        _cities[idx][1] * size.height,
      );

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF080C1E), Color(0xFF060810), Color(0xFF0A0D1F)],
        ).createShader(Offset.zero & size),
    );
  }

  void _drawConnections(Canvas canvas, Size size) {
    for (int i = 0; i < _connections.length; i++) {
      final conn = _connections[i];
      final phase = i / _connections.length;
      final cycleT = (t + phase) % 1.0;
      double opacity;
      if (cycleT < 0.08) {
        opacity = cycleT / 0.08;
      } else if (cycleT < 0.45) {
        opacity = 1.0;
      } else if (cycleT < 0.60) {
        opacity = 1.0 - (cycleT - 0.45) / 0.15;
      } else {
        opacity = 0.0;
      }
      if (opacity < 0.01) continue;

      final a = _pos(conn[0], size);
      final b = _pos(conn[1], size);

      canvas.drawLine(a, b,
          Paint()
            ..color = Color.fromARGB((opacity * 35).round(), 212, 175, 55)
            ..strokeWidth = 2.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawLine(a, b,
          Paint()
            ..color = Color.fromARGB((opacity * 70).round(), 212, 175, 55)
            ..strokeWidth = 0.7);

      final travel = (t * 2.5 + phase * 4.7) % 1.0;
      final dotPos = Offset.lerp(a, b, travel)!;
      canvas.drawCircle(
          dotPos,
          2.2,
          Paint()
            ..color = Color.fromARGB((opacity * 220).round(), 255, 225, 110)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }

  void _drawCities(Canvas canvas, Size size) {
    for (int i = 0; i < _cities.length; i++) {
      final pos = _pos(i, size);
      final phase = (i * 0.37) % 1.0;
      final pulse =
          (math.sin((t * 2 * math.pi * 1.4) + phase * 2 * math.pi) + 1) / 2;

      canvas.drawCircle(
          pos,
          3.5 + pulse * 4.0,
          Paint()
            ..color = Color.fromARGB((pulse * 55).round(), 212, 175, 55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(
          pos,
          2.5,
          Paint()
            ..color = Color.fromARGB(
                (180 + (pulse * 50).round()).clamp(0, 255).toInt(), 212, 175, 55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawCircle(pos, 1.6, Paint()..color = const Color(0xFFD4AF37));
      canvas.drawCircle(pos, 0.7, Paint()..color = const Color(0xFFFFF4CC));
    }
  }

  void _drawVignette(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.88,
          colors: [Colors.transparent, const Color(0xCC060810)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.62, 1.0],
          colors: [Colors.transparent, Color(0xFF060810)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.10],
          colors: [Color(0xAA060810), Colors.transparent],
        ).createShader(Offset.zero & size),
    );
  }

  void _drawContinents(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0x1E7BAFC8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0x0A9EC5D8)
      ..style = PaintingStyle.fill;

    Offset p(double x, double y) =>
        Offset(x * size.width, y * size.height);

    void draw(List<Offset> pts) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) path.lineTo(pts[i].dx, pts[i].dy);
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }

    // North America
    draw([
      p(0.122,0.145), p(0.145,0.118), p(0.175,0.108), p(0.220,0.112),
      p(0.270,0.118), p(0.325,0.138), p(0.360,0.178), p(0.355,0.228),
      p(0.340,0.268), p(0.318,0.305), p(0.300,0.338), p(0.278,0.358),
      p(0.260,0.398), p(0.240,0.430), p(0.228,0.450), p(0.215,0.438),
      p(0.200,0.415), p(0.188,0.390), p(0.172,0.368), p(0.158,0.338),
      p(0.138,0.305), p(0.115,0.268), p(0.100,0.235), p(0.098,0.200),
      p(0.108,0.175),
    ]);

    // Greenland
    draw([
      p(0.388,0.095), p(0.408,0.085), p(0.430,0.092), p(0.445,0.110),
      p(0.440,0.128), p(0.420,0.140), p(0.400,0.138), p(0.385,0.122),
    ]);

    // South America
    draw([
      p(0.262,0.478), p(0.288,0.462), p(0.315,0.458), p(0.345,0.462),
      p(0.375,0.488), p(0.398,0.518), p(0.415,0.552), p(0.418,0.595),
      p(0.412,0.638), p(0.395,0.678), p(0.372,0.715), p(0.348,0.748),
      p(0.325,0.778), p(0.308,0.802), p(0.295,0.790), p(0.280,0.762),
      p(0.265,0.725), p(0.252,0.688), p(0.245,0.645), p(0.242,0.598),
      p(0.245,0.552), p(0.250,0.510),
    ]);

    // Europe
    draw([
      p(0.455,0.195), p(0.478,0.182), p(0.505,0.175), p(0.535,0.178),
      p(0.560,0.185), p(0.590,0.195), p(0.615,0.208), p(0.618,0.228),
      p(0.602,0.248), p(0.588,0.268), p(0.572,0.285), p(0.558,0.298),
      p(0.542,0.315), p(0.528,0.328), p(0.510,0.342), p(0.492,0.348),
      p(0.475,0.340), p(0.460,0.325), p(0.448,0.308), p(0.440,0.288),
      p(0.442,0.262), p(0.448,0.238), p(0.450,0.218),
    ]);

    // Africa
    draw([
      p(0.458,0.352), p(0.482,0.342), p(0.520,0.338), p(0.552,0.338),
      p(0.582,0.342), p(0.610,0.352), p(0.628,0.370), p(0.638,0.398),
      p(0.640,0.432), p(0.635,0.468), p(0.628,0.502), p(0.618,0.538),
      p(0.604,0.572), p(0.588,0.605), p(0.568,0.635), p(0.548,0.658),
      p(0.528,0.672), p(0.510,0.668), p(0.492,0.652), p(0.475,0.628),
      p(0.460,0.598), p(0.448,0.562), p(0.442,0.522), p(0.440,0.478),
      p(0.442,0.435), p(0.448,0.398), p(0.452,0.372),
    ]);

    // Asia (main landmass)
    draw([
      p(0.595,0.132), p(0.635,0.108), p(0.680,0.095), p(0.730,0.092),
      p(0.780,0.098), p(0.828,0.105), p(0.872,0.112), p(0.912,0.125),
      p(0.945,0.145), p(0.962,0.172), p(0.958,0.202), p(0.942,0.232),
      p(0.920,0.255), p(0.898,0.272), p(0.875,0.288), p(0.855,0.308),
      p(0.838,0.328), p(0.818,0.348), p(0.798,0.368), p(0.778,0.388),
      p(0.758,0.412), p(0.738,0.438), p(0.718,0.462), p(0.698,0.480),
      p(0.678,0.468), p(0.658,0.448), p(0.638,0.428), p(0.618,0.405),
      p(0.600,0.378), p(0.582,0.352), p(0.578,0.318), p(0.582,0.285),
      p(0.588,0.258), p(0.592,0.225), p(0.592,0.192), p(0.592,0.162),
    ]);

    // Indian subcontinent
    draw([
      p(0.658,0.340), p(0.678,0.338), p(0.698,0.348), p(0.712,0.368),
      p(0.718,0.395), p(0.710,0.422), p(0.698,0.445), p(0.682,0.458),
      p(0.665,0.448), p(0.652,0.430), p(0.645,0.408), p(0.645,0.382),
      p(0.648,0.360),
    ]);

    // Southeast Asia
    draw([
      p(0.738,0.410), p(0.758,0.402), p(0.778,0.408), p(0.798,0.425),
      p(0.808,0.448), p(0.805,0.472), p(0.792,0.492), p(0.775,0.498),
      p(0.758,0.488), p(0.742,0.468), p(0.735,0.445),
    ]);

    // Australia
    draw([
      p(0.838,0.565), p(0.865,0.552), p(0.895,0.555), p(0.922,0.562),
      p(0.945,0.578), p(0.962,0.602), p(0.965,0.632), p(0.958,0.662),
      p(0.942,0.688), p(0.918,0.705), p(0.892,0.712), p(0.865,0.708),
      p(0.840,0.692), p(0.820,0.668), p(0.808,0.638), p(0.808,0.605),
      p(0.818,0.582),
    ]);

    // Japan
    draw([
      p(0.882,0.278), p(0.892,0.270), p(0.902,0.275), p(0.908,0.292),
      p(0.905,0.310), p(0.895,0.322), p(0.882,0.318), p(0.875,0.305),
      p(0.875,0.290),
    ]);

    // UK (simplified outline)
    draw([
      p(0.488,0.220), p(0.496,0.212), p(0.505,0.215), p(0.510,0.228),
      p(0.508,0.245), p(0.498,0.252), p(0.488,0.245), p(0.484,0.232),
    ]);
  }

  @override
  bool shouldRepaint(_WorldMapPainter old) => old.t != t;
}


// ══════════════════════════════════════════════════════════════════════════════
// MARKET TICKER STRIP
// ══════════════════════════════════════════════════════════════════════════════

class _MarketTickerStrip extends StatefulWidget {
  @override
  State<_MarketTickerStrip> createState() => _MarketTickerStripState();
}

class _MarketTickerStripState extends State<_MarketTickerStrip> {
  Timer? _liveTimer;
  bool  _marketClosed = false;

  static const _symbols = [
    'EUR/USD', 'GBP/USD', 'USD/JPY', 'XAU/USD', 'XAG/USD',
    'USOIL', 'UKOIL', 'NGAS',
    'AUD/USD', 'USD/CAD', 'NZD/USD', 'USD/CHF', 'EUR/GBP',
    'GBP/JPY', 'EUR/JPY', 'USD/TRY',
  ];

  // Fallback base prices used until real data arrives
  static const _base = {
    'EUR/USD': 1.0862, 'GBP/USD': 1.2734, 'USD/JPY': 149.82,
    'XAU/USD': 3320.00, 'XAG/USD': 32.50,
    'USOIL': 78.60,  'UKOIL': 82.30,  'NGAS': 2.45,
    'AUD/USD': 0.6548, 'USD/CAD': 1.3614, 'NZD/USD': 0.6120,
    'USD/CHF': 0.8950, 'EUR/GBP': 0.8520,
    'GBP/JPY': 190.45, 'EUR/JPY': 162.78, 'USD/TRY': 38.20,
  };

  final Map<String, double>       _prices     = {};
  final Map<String, double>       _changes    = {};
  final Map<String, bool>         _up         = {};
  final Map<String, List<double>> _sparklines = {};

  @override
  void initState() {
    super.initState();
    for (final s in _symbols) {
      _prices[s]  = _base[s]!;
      _changes[s] = 0.0;
      _up[s]      = true;
    }
    _marketClosed = _isMarketClosed();
  }

  Future<void> _fetchSparklines() async {
    final data = await SparklineService.fetch();
    if (!mounted || data.isEmpty) return;
    setState(() {
      for (final entry in data.entries) {
        _sparklines[entry.key] = entry.value;
      }
    });
  }

  Future<void> _fetchLive() async {
    final data = await ForexService.fetchPrices();
    if (!mounted || data.isEmpty) return;
    setState(() {
      for (final s in _symbols) {
        if (data.containsKey(s)) {
          final prev = _prices[s]!;
          _prices[s] = data[s]!;
          _up[s]     = data[s]! >= prev;
          _changes[s] = ((_prices[s]! - _base[s]!) / _base[s]!) * 100;
          // Append new price to sparkline history
          final hist = _sparklines[s] ?? [];
          hist.add(data[s]!);
          if (hist.length > 50) hist.removeAt(0);
          _sparklines[s] = hist;
        }
      }
    });
  }

  static bool _isMarketClosed() {
    final now = DateTime.now().toUtc();
    final wd  = now.weekday;
    if (wd == DateTime.saturday) return true;
    if (wd == DateTime.sunday  && now.hour < 21)  return true;
    if (wd == DateTime.friday  && now.hour >= 22) return true;
    return false;
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  String _fmt(String s, double p) {
    if (s.contains('JPY') || s == 'USD/TRY') return p.toStringAsFixed(2);
    if (s == 'XAU/USD') return p.toStringAsFixed(2);
    if (s == 'XAG/USD') return p.toStringAsFixed(2);
    if (s.contains('OIL') || s == 'NGAS') return p.toStringAsFixed(2);
    return p.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: _marketClosed
          ? Builder(builder: (ctx) {
              final isMobileT = MediaQuery.of(ctx).size.width < 768;
              return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.neonRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                    isMobileT
                      ? 'السوق مغلق  ·  Market Closed'
                      : 'السوق مغلق  ·  Market Closed  ·  Piyasa Kapalı  —  يفتح الأحد 21:00 UTC',
                    style: GoogleFonts.inter(
                      fontSize: isMobileT ? 12 : 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.neonRed,
                      letterSpacing: 0.5,
                    ),
                  ),
                  ),
                ],
              ),
            );
          })
          : SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _symbols.map((s) {
            final price = _prices[s]!;
            final change = _changes[s]!;
            final isUp = _up[s]!;
            final color = isUp ? AppColors.neonGreen : AppColors.neonRed;
            return _TickerItem(
              symbol: s,
              price: _fmt(s, price),
              change: change,
              color: color,
              isUp: isUp,
              history: List<double>.from(_sparklines[s] ?? []),
            );
          }).toList(),
        ),
      ),
    );
  }
}
class _TickerItem extends StatefulWidget {
  const _TickerItem({
    required this.symbol,
    required this.price,
    required this.change,
    required this.color,
    required this.isUp,
    required this.history,
  });

  final String symbol;
  final String price;
  final double change;
  final Color color;
  final bool isUp;
  final List<double> history;

  @override
  State<_TickerItem> createState() => _TickerItemState();
}

class _TickerItemState extends State<_TickerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _flash;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void didUpdateWidget(_TickerItem old) {
    super.didUpdateWidget(old);
    if (old.price != widget.price) {
      _flash.forward().then((_) => _flash.reverse());
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSparkline = widget.history.length >= 2;
    return AnimatedBuilder(
      animation: _flash,
      builder: (_, __) => Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_flash.value * 0.08),
          border: const Border(
              right: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              widget.isUp
                  ? Icons.arrow_drop_up_rounded
                  : Icons.arrow_drop_down_rounded,
              color: widget.color,
              size: 16,
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.symbol,
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                ),
                Row(
                  children: [
                    Text(
                      widget.price,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${widget.change >= 0 ? '+' : ''}${widget.change.toStringAsFixed(2)}%',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: widget.color),
                    ),
                  ],
                ),
              ],
            ),
            if (hasSparkline) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                height: 28,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    data: widget.history,
                    color: widget.color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.data, required this.color});
  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range  = (maxVal - minVal).abs();
    if (range == 0) return;

    double xStep = size.width / (data.length - 1);

    Offset point(int i) {
      final x = i * xStep;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      return Offset(x, y);
    }

    // Gradient fill
    final path = Path()..moveTo(0, size.height);
    for (int i = 0; i < data.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }
    path..lineTo(size.width, size.height)..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    final linePath = Path()..moveTo(point(0).dx, point(0).dy);
    for (int i = 1; i < data.length; i++) {
      linePath.lineTo(point(i).dx, point(i).dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dot at last point
    canvas.drawCircle(
      point(data.length - 1),
      2.0,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.data != data || old.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURES SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({required this.onLaunch});
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final features = [
      (Icons.monitor_rounded,      s.feat1Title, s.feat1Desc, AppColors.gold,             false),
      (Icons.psychology_rounded,   s.feat2Title, s.feat2Desc, AppColors.neonGreen,        true),
      (Icons.support_agent_rounded,s.feat3Title, s.feat3Desc, const Color(0xFF6EC6FF),   false),
    ];
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 48 : 80, horizontal: isMobile ? 20 : 60),
      child: Column(
        children: [
          _SectionHeader(
            tag: s.featuresTag,
            title: s.featuresTitle,
            subtitle: s.featuresSubtitle,
          ),
          SizedBox(height: isMobile ? 28 : 48),
          if (isMobile)
            Column(
              children: features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _FeatureCard(
                  icon: f.$1,
                  title: f.$2,
                  description: f.$3,
                  color: f.$4,
                  isHighlighted: f.$5,
                  onTap: f.$5 ? onLaunch : null,
                ),
              )).toList(),
            )
          else
            Row(
              children: features
                  .map((f) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _FeatureCard(
                            icon: f.$1,
                            title: f.$2,
                            description: f.$3,
                            color: f.$4,
                            isHighlighted: f.$5,
                            onTap: f.$5 ? onLaunch : null,
                          ),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.isHighlighted,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _lift;
  late Animation<double> _glow;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _lift = Tween<double>(begin: 0, end: -6).animate(_ctrl);
    _glow = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        setState(() => _hovered = true);
        _ctrl.forward();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _ctrl.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, _lift.value),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: widget.isHighlighted
                    ? widget.color.withOpacity(0.07)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hovered || widget.isHighlighted
                      ? widget.color.withOpacity(0.4)
                      : AppColors.border,
                  width: widget.isHighlighted ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color
                        .withOpacity(0.04 + _glow.value * 0.12),
                    blurRadius: 20 + _glow.value * 20,
                    spreadRadius: _glow.value * 2,
                  )
                ],
              ),
              child: child,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: widget.color.withOpacity(0.3), width: 1),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 24),
                ),
                const SizedBox(height: 18),
                Text(widget.title,
                    style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                Text(widget.description,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.65)),
                if (widget.onTap != null) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(context.watch<LocaleProvider>().s.feat2Cta,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.color)),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: widget.color),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TOOL SHOWCASE SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _ToolShowcase extends StatelessWidget {
  const _ToolShowcase({required this.onLaunch});
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 60),
      padding: EdgeInsets.all(isMobile ? 24 : 60),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.gold.withOpacity(0.08),
            AppColors.surfaceHigh,
            AppColors.neonGreen.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderGold, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.gold.withOpacity(0.06),
              blurRadius: 40,
              spreadRadius: 4)
        ],
      ),
      child: Builder(builder: (ctx) {
        final s = ctx.watch<LocaleProvider>().s;
        final textSide = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(s.toolTag,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                      letterSpacing: 0.8)),
            ),
            const SizedBox(height: 16),
            Text(
              s.toolTitle,
              style: GoogleFonts.inter(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.2),
            ),
            const SizedBox(height: 16),
            Text(
              s.toolDesc,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.7),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                'RSI + MACD', 'Supply & Demand',
                'Multi-Timeframe', '58+ Assets',
                'AI Sentiment', 'Claude API Ready',
              ]
                  .map((l) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Text(l,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 32),
            AnimatedHoverButton(
              label: s.toolLaunchBtn,
              height: 58,
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              glowColor: AppColors.gold,
              width: isMobile ? double.infinity : 320,
              onPressed: onLaunch,
            ),
          ],
        );
        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textSide,
              const SizedBox(height: 28),
              _DashboardPreviewCard(),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 5, child: textSide),
            const SizedBox(width: 60),
            Expanded(flex: 4, child: _DashboardPreviewCard()),
          ],
        );
      }),
    );
  }
}

class _DashboardPreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          // Mini header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                        colors: [AppColors.goldLight, AppColors.gold]),
                  ),
                  child: Center(
                    child: Text('MF',
                        style: GoogleFonts.inter(
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            color: AppColors.background)),
                  ),
                ),
                const SizedBox(width: 8),
                Text('mohammed forex',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.neonGreen)),
                      const SizedBox(width: 4),
                      Text('LIVE',
                          style: GoogleFonts.inter(
                              fontSize: 8,
                              color: AppColors.neonGreen,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Mini signal preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Signal card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.neonGreen.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.neonGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.neonGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('BUY',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.background)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EUR/USD · M15',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            Text('Confluence Score: High',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                        const Spacer(),
                        Text('87.4%',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.neonGreen)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Params row
                  Row(
                    children: [
                      _MiniParam('Entry', '1.0862', AppColors.gold),
                      const SizedBox(width: 8),
                      _MiniParam('SL', '1.0844', AppColors.neonRed),
                      const SizedBox(width: 8),
                      _MiniParam('TP', '1.0898', AppColors.neonGreen),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // RSI mini gauge placeholder
                  _MiniGaugeRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniParam extends StatelessWidget {
  const _MiniParam(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 8,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _MiniGaugeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('RSI 14',
                  style: GoogleFonts.inter(
                      fontSize: 9, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: 0.28,
                  backgroundColor: AppColors.gaugeTrack,
                  valueColor: const AlwaysStoppedAnimation(AppColors.neonGreen),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 2),
              Text('28.4 — Oversold',
                  style: GoogleFonts.inter(
                      fontSize: 9, color: AppColors.neonGreen)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MACD',
                  style: GoogleFonts.inter(
                      fontSize: 9, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: 0.72,
                  backgroundColor: AppColors.gaugeTrack,
                  valueColor: const AlwaysStoppedAnimation(AppColors.neonGreen),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 2),
              Text('Bullish Cross ↑',
                  style: GoogleFonts.inter(
                      fontSize: 9, color: AppColors.neonGreen)),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WHY US SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _WhyUsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    final cards = [
      (Icons.trending_up_rounded, '58+',  s.why1Label, s.why1Desc, AppColors.gold),
      (Icons.verified_rounded,    '87%+', s.why2Label, s.why2Desc, AppColors.neonGreen),
      (Icons.speed_rounded,       '3',    s.why3Label, s.why3Desc, const Color(0xFF6EC6FF)),
      (Icons.link_rounded,        'MT5',  s.why4Label, s.why4Desc, AppColors.waitAmber),
    ];
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 48 : 80, horizontal: isMobile ? 20 : 60),
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          _SectionHeader(
            tag: s.whyTag,
            title: s.whyTitle,
            subtitle: s.whySubtitle,
          ),
          SizedBox(height: isMobile ? 28 : 48),
          if (isMobile)
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _WhyCard(icon: cards[0].$1, stat: cards[0].$2, label: cards[0].$3, description: cards[0].$4, color: cards[0].$5)),
                    const SizedBox(width: 12),
                    Expanded(child: _WhyCard(icon: cards[1].$1, stat: cards[1].$2, label: cards[1].$3, description: cards[1].$4, color: cards[1].$5)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _WhyCard(icon: cards[2].$1, stat: cards[2].$2, label: cards[2].$3, description: cards[2].$4, color: cards[2].$5)),
                    const SizedBox(width: 12),
                    Expanded(child: _WhyCard(icon: cards[3].$1, stat: cards[3].$2, label: cards[3].$3, description: cards[3].$4, color: cards[3].$5)),
                  ],
                ),
              ],
            )
          else
            Row(
              children: cards
                  .map((c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _WhyCard(
                            icon: c.$1,
                            stat: c.$2,
                            label: c.$3,
                            description: c.$4,
                            color: c.$5,
                          ),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _WhyCard extends StatefulWidget {
  const _WhyCard({
    required this.icon,
    required this.stat,
    required this.label,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String stat;
  final String label;
  final String description;
  final Color color;

  @override
  State<_WhyCard> createState() => _WhyCardState();
}

class _WhyCardState extends State<_WhyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _lift;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _lift =
        Tween<double>(begin: 0, end: -5).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _ctrl.forward(),
      onExit: (_) => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _lift.value),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: widget.color
                      .withOpacity(0.1 + _ctrl.value * 0.3),
                  width: 1),
              boxShadow: [
                BoxShadow(
                    color: widget.color
                        .withOpacity(_ctrl.value * 0.1),
                    blurRadius: 20)
              ],
            ),
            child: child,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, color: widget.color, size: 28),
            const SizedBox(height: 14),
            Text(widget.stat,
                style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: widget.color)),
            Text(widget.label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(widget.description,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// NEWS / ECONOMIC EVENTS SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _NewsSection extends StatefulWidget {
  @override
  State<_NewsSection> createState() => _NewsSectionState();
}

class _NewsSectionState extends State<_NewsSection> {
  List<EconomicEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    EconomicCalendarService.fetchEvents().then((events) {
      if (mounted) setState(() { _events = events; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final newsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          tag: s.newsTag,
          title: s.newsTitle,
          subtitle: s.newsSubtitle,
          compact: true,
        ),
        const SizedBox(height: 24),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2))
        else if (_events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'لا توجد أحداث اقتصادية قادمة  ·  No upcoming events',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
            ),
          )
        else
          ..._events.map((e) => _NewsItem(
                title: e.name,
                impact: e.isHigh ? s.highImpact : s.mediumImpact,
                time: '${e.displayDate}  ${e.displayTime}  ${e.currency}',
                color: e.isHigh ? AppColors.neonRed : AppColors.waitAmber,
              )),
      ],
    );

    final freezeBox = Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.waitAmber.withOpacity(0.08), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.waitAmber.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.waitAmber, size: 20),
              const SizedBox(width: 8),
              Text(s.newsFreezeTitle,
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.waitAmber)),
            ],
          ),
          const SizedBox(height: 14),
          Text(s.newsFreezeDesc,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.7)),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 15, color: AppColors.waitAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.newsFreezeAutoCheck,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary, height: 1.6)),
              ),
            ],
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 48 : 80, horizontal: isMobile ? 20 : 60),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              newsColumn,
              const SizedBox(height: 28),
              freezeBox,
            ])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: newsColumn),
                const SizedBox(width: 60),
                Expanded(flex: 2, child: freezeBox),
              ],
            ),
    );
  }
}

class _NewsItem extends StatefulWidget {
  const _NewsItem({
    required this.title,
    required this.impact,
    required this.time,
    required this.color,
  });

  final String title;
  final String impact;
  final String time;
  final Color color;

  @override
  State<_NewsItem> createState() => _NewsItemState();
}

class _NewsItemState extends State<_NewsItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceHigh : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _hovered
                  ? widget.color.withOpacity(0.3)
                  : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: widget.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.title,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 10),
            Text(widget.time,
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.textMuted)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(widget.impact,
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      color: widget.color,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FOOTER
// ══════════════════════════════════════════════════════════════════════════════

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final logoBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.goldLight, AppColors.gold]),
              ),
              child: Center(
                child: Text('MF',
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.background)),
              ),
            ),
            const SizedBox(width: 10),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: 'mohammed ',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.gold)),
                TextSpan(
                    text: 'forex',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w300, color: AppColors.textSecondary)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(s.footerTagline,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, height: 1.7)),
        const SizedBox(height: 18),
        Row(
          children: [Icons.email_outlined, Icons.telegram_rounded, Icons.language_rounded]
              .map((icon) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(icon, size: 18, color: AppColors.textMuted),
                  ))
              .toList(),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 60, vertical: 48),
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                logoBlock,
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _FooterLinks(title: s.footerCol1Title, links: s.footerCol1Items)),
                    const SizedBox(width: 16),
                    Expanded(child: _FooterLinks(title: s.footerCol2Title, links: s.footerCol2Items)),
                  ],
                ),
                const SizedBox(height: 20),
                _FooterLinks(title: s.footerCol3Title, links: s.footerCol3Items),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: logoBlock),
                Expanded(flex: 2, child: _FooterLinks(title: s.footerCol1Title, links: s.footerCol1Items)),
                Expanded(flex: 2, child: _FooterLinks(title: s.footerCol2Title, links: s.footerCol2Items)),
                Expanded(flex: 2, child: _FooterLinks(title: s.footerCol3Title, links: s.footerCol3Items)),
              ],
            ),
          const SizedBox(height: 36),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 20),
          if (isMobile)
            Column(
              children: [
                Text(s.footerCopyright,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('Built with Flutter/Dart · Claude Sonnet 4.6',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                    textAlign: TextAlign.center),
              ],
            )
          else
            Row(
              children: [
                Text(s.footerCopyright,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                const Spacer(),
                Text('Built with Flutter/Dart · Claude Sonnet 4.6 API Ready · MT5 Bridge Ready',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            s.footerRisk,
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.textMuted.withOpacity(0.6), height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({required this.title, required this.links});
  final String title;
  final List<String> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.gold)),
        const SizedBox(height: 14),
        ...links.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(l,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textMuted)),
            )),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.tag,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String tag;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderGold),
          ),
          child: Text(tag,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                  letterSpacing: 0.5)),
        ),
        SizedBox(height: compact ? 10 : 14),
        Text(title,
            style: GoogleFonts.inter(
                fontSize: compact ? 22 : 32,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.2)),
        SizedBox(height: compact ? 6 : 10),
        Text(subtitle,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6)),
      ],
    );
  }
}
