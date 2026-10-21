import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/format/formats.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';

import '../support/app_harness.dart';

void main() {
  late AppHarness h;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    h = AppHarness();
  });

  /// Lets Turbo Start run out so a Tier 4 trip on R01 takes its normal 84 s.
  Future<void> finishTurbo(WidgetTester tester) async {
    h.clock.advance(const Duration(minutes: 61));
    await tester.runAsync(() => h.engine.tick());
  }

  testWidgets('shows the company, cash, turbo speed and garage slots', (
    tester,
  ) async {
    await h.open(tester, company: 'Sifat Ltd');
    await h.pump(tester);

    expect(find.text('Sifat Ltd'), findsOneWidget);
    expect(find.text('Cash: Tk 15,00,000'), findsOneWidget);
    expect(find.text('Turbo Start speed: 20 times'), findsOneWidget);
    expect(find.text('Vehicles'), findsOneWidget);
    expect(find.text('1 of 6 garage slots used'), findsOneWidget);
  });

  testWidgets('the free starter vehicle is listed and not assigned', (
    tester,
  ) async {
    await h.open(tester, company: 'A');
    await h.pump(tester);

    expect(find.text('Sathi Plus'), findsOneWidget);
    expect(find.text('Not assigned'), findsOneWidget);
    expect(find.text('Start working (temporary)'), findsOneWidget);
  });

  testWidgets('the temporary button sends the vehicle on a trip', (
    tester,
  ) async {
    await h.open(tester, company: 'A');
    await finishTurbo(tester);
    await h.pump(tester);

    await tester.tap(find.text('Start working (temporary)'));
    await h.settle(tester);

    expect(find.text('Start working (temporary)'), findsNothing);
    expect(find.text('On the road'), findsOneWidget);
    expect(
      find.text('Tejgaon to Dhaka city, General dry goods'),
      findsOneWidget,
    );
    expect(find.text('Arrives in 1:24'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0);
  });

  testWidgets('progress and the timer follow the UI clock', (tester) async {
    await h.open(tester, company: 'A');
    await finishTurbo(tester);
    await h.pump(tester);
    await tester.tap(find.text('Start working (temporary)'));
    await h.settle(tester);

    // 42 of the 84 seconds later.
    h.clock.advance(const Duration(seconds: 42));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Arrives in 0:42'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.5, 1e-9));
  });

  testWidgets('a paid trip raises the cash on screen', (tester) async {
    await h.open(tester, company: 'A');
    await finishTurbo(tester);
    await h.pump(tester);
    await tester.tap(find.text('Start working (temporary)'));
    await h.settle(tester);

    h.clock.advance(const Duration(seconds: 90));
    await h.tick(tester);

    final cash = h.engine.company!.cash;
    expect(cash, greaterThan(1500000));
    const en = Formats(bangla: false);
    expect(find.text('Cash: ${en.money(cash)}'), findsOneWidget);
  });

  testWidgets('the vehicle shows as waiting when the route has no demand', (
    tester,
  ) async {
    await h.open(tester, company: 'A');
    await finishTurbo(tester);
    await tester.runAsync(
      () => h.db.routeStates.put(
        RouteState(
          routeId: 'R01',
          demandRemainingT: 0,
          updatedAt: h.clock.now(),
        ),
      ),
    );
    await h.pump(tester);
    await tester.tap(find.text('Start working (temporary)'));
    await h.settle(tester);

    expect(find.text('Waiting for demand'), findsOneWidget);
    expect(find.textContaining('Goes again in'), findsOneWidget);
  });

  testWidgets('Bangla: names, status, timer and digits', (tester) async {
    await h.open(tester, company: 'বাংলা', language: 'bn');
    await finishTurbo(tester);
    await h.pump(tester);

    expect(find.text('সাথী প্লাস'), findsOneWidget);
    expect(find.text('কাজ দেওয়া হয়নি'), findsOneWidget);
    expect(find.text('গ্যারেজের ৬টি জায়গার মধ্যে ১টি ভরা'), findsOneWidget);

    await tester.tap(find.text('কাজে পাঠান (সাময়িক)'));
    await h.settle(tester);
    expect(find.text('পথে আছে'), findsOneWidget);
    expect(
      find.text('তেজগাঁও থেকে ঢাকা শহর, সাধারণ শুকনো মাল'),
      findsOneWidget,
    );
    expect(find.text('পৌঁছাতে বাকি ১:২৪'), findsOneWidget);
  });
}
