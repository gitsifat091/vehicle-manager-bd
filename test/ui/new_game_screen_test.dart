import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/ui/screens/new_game_screen.dart';
import 'package:vehicle_manager_bd/ui/shell/app_shell.dart';

import '../support/app_harness.dart';

void main() {
  late AppHarness h;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    h = AppHarness();
  });

  testWidgets('explains the start and asks for a company name', (tester) async {
    await h.open(tester);
    await h.pump(tester);

    expect(find.byType(NewGameScreen), findsOneWidget);
    expect(find.text('Start your company'), findsOneWidget);
    expect(
      find.text(
        'You start with Tk 15,00,000 and one free Sathi Plus. '
        'Send it to work and reinvest what it earns.',
      ),
      findsOneWidget,
    );
    expect(find.text('Company name'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('an empty or blank name is refused', (tester) async {
    await h.open(tester);
    await h.pump(tester);

    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Enter a company name'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '    ');
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Enter a company name'), findsOneWidget);
    expect(h.engine.company, isNull, reason: 'no game was started');
  });

  testWidgets('Start creates the company and opens the shell', (tester) async {
    await h.open(tester);
    await h.pump(tester);

    await tester.enterText(find.byType(TextFormField), '  Padma Transport  ');
    await tester.tap(find.text('Start'));
    await h.settle(tester);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(NewGameScreen), findsNothing);
    expect(find.text('Padma Transport'), findsOneWidget);
    expect(h.engine.company!.name, 'Padma Transport', reason: 'trimmed');
    expect(h.db.vehicles.count, 1, reason: 'the free starter vehicle');
  });

  testWidgets('the Enter key on the keyboard starts the game too', (
    tester,
  ) async {
    await h.open(tester);
    await h.pump(tester);

    await tester.enterText(find.byType(TextFormField), 'Keyboard Ltd');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await h.settle(tester);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('the name field stops at 30 characters', (tester) async {
    await h.open(tester);
    await h.pump(tester);

    await tester.enterText(find.byType(TextFormField), 'x' * 40);
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, NewGameScreen.maxNameLength);
  });

  testWidgets('Bangla: Bangla text, digits and the starter name', (
    tester,
  ) async {
    await h.open(tester, language: 'bn');
    await h.pump(tester);

    expect(find.text('আপনার কোম্পানি শুরু করুন'), findsOneWidget);
    expect(
      find.text(
        'আপনি ৳ ১৫,০০,০০০ আর একটি বিনামূল্যের সাথী প্লাস নিয়ে শুরু করছেন। '
        'এটিকে কাজে পাঠান আর আয় থেকে আবার বিনিয়োগ করুন।',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('শুরু করুন'));
    await tester.pump();
    expect(find.text('কোম্পানির নাম লিখুন'), findsOneWidget);
  });

  testWidgets('a saved game skips the screen', (tester) async {
    await h.open(tester, company: 'Saved Ltd');
    await h.pump(tester);
    expect(find.byType(NewGameScreen), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('the start button is at least 44 px tall', (tester) async {
    await h.open(tester);
    await h.pump(tester);
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
