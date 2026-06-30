import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/localization/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/dashboard/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MohammedForexApp());
}

class MohammedForexApp extends StatelessWidget {
  const MohammedForexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (_, lp, __) => MaterialApp(
          title: 'mohammed forex',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          scrollBehavior: const _SmoothScroll(),
          builder: (ctx, child) => Directionality(
            textDirection: TextDirection.ltr,
            child: child!,
          ),
          home: const DashboardScreen(),
        ),
      ),
    );
  }
}

/// Enable mouse-wheel and touch scrolling together on web
class _SmoothScroll extends ScrollBehavior {
  const _SmoothScroll();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
