// Widget test for Candy Kids Quest app.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kids_app/main.dart';

void main() {
  testWidgets('App loads and shows name entry for new player', (WidgetTester tester) async {
    // Set up fake shared preferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = GameStorageService(prefs);

    await tester.pumpWidget(CandyKidsApp(storage: storage));
    await tester.pumpAndSettle();

    // New player should see name entry screen
    expect(find.text('Welcome to\nCandy Quest!'), findsOneWidget);
    expect(find.text("Let's Play! 🎮"), findsOneWidget);
  });
  
  testWidgets('Returning player sees level map', (WidgetTester tester) async {
    // Set up fake shared preferences with existing player
    SharedPreferences.setMockInitialValues({
      'candy_kids_game_state': '{"playerName":"TestKid","currentLevel":1,"totalStars":0,"coins":0,"levelStars":{},"weeklyStreak":[false,false,false,false,false,false,false],"lastPlayedDate":"2026-02-06T10:00:00.000"}'
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = GameStorageService(prefs);

    await tester.pumpWidget(CandyKidsApp(storage: storage));
    await tester.pumpAndSettle();

    // Returning player should see level map with greeting
    expect(find.textContaining('Hi, TestKid!'), findsOneWidget);
  });
}
