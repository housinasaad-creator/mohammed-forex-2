import 'package:flutter_test/flutter_test.dart';
import 'package:mohammed_forex/main.dart';

void main() {
  testWidgets('Dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MohammedForexApp());
    expect(find.byType(MohammedForexApp), findsOneWidget);
  });
}
