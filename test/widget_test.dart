// Widget test for Tiny Science Play app.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kids_app/main.dart';

void main() {
  testWidgets('Play map shows and games tab loads', (WidgetTester tester) async {
    // Set up fake shared preferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = GameStorageService(prefs);

    await tester.pumpWidget(KidsScienceApp(storage: storage));
    await tester.pumpAndSettle();

    expect(find.text('Play Zones'), findsOneWidget);

    await tester.tap(find.text('Games'));
    await tester.pumpAndSettle();

    expect(find.text('Color Match Party'), findsOneWidget);
  });
}
