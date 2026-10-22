import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/ui/screens/vehicle_detail.dart';

import '../support/app_harness.dart';
import '../support/sim_support.dart';

void main() {
  late AppHarness h;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    h = AppHarness();
  });

  const phone = Size(390, 844);
  const startWorking = 'Start working (temporary)';
  const cannotSell = 'Cannot sell now';
  const starterNote =
      "This is your company's starter vehicle. It sells for a fixed "
      'Tk 1,50,000.';

  final detail = find.byType(VehicleDetail);
  final dialog = find.byType(AlertDialog);

  Finder inDialog(String text) =>
      find.descendant(of: dialog, matching: find.text(text));

  /// Opens a game on a phone with Turbo Start over. [before] runs on the save
  /// before the first frame.
  Future<void> openGame(
    WidgetTester tester, {
    String? language,
    Future<void> Function()? before,
  }) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await h.open(tester, company: 'A', language: language);
    h.clock.advance(const Duration(minutes: 61));
    await tester.runAsync(() async {
      await h.engine.tick();
      await before?.call();
    });
    await h.pump(tester);
  }

  Future<void> openTile(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).last);
    await tester.pump();
  }

  /// Scrolls the detail to its Sell button and taps it. The button first
  /// asks the engine whether the sale would go through.
  Future<void> tapSell(WidgetTester tester, {String label = 'Sell'}) async {
    final button = find.descendant(of: detail, matching: find.text(label));
    final scrollable = find
        .descendant(of: detail, matching: find.byType(Scrollable))
        .first;
    // From the top, because the content above the button can change.
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(button, 200, scrollable: scrollable);
    // Fully on screen, not half under the bottom bar.
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await h.settle(tester);
    await tester.pump();
  }

  /// Lets a snack bar run out, so no timer is left at the end of the test.
  Future<void> letSnackBarGo(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('selling the starter: confirmation with the note, then sold', (
    tester,
  ) async {
    await openGame(tester);
    await openTile(tester, 'Sathi Plus');
    await tapSell(tester);

    expect(find.text('Sell Sathi Plus?'), findsOneWidget);
    expect(inDialog('You get'), findsOneWidget);
    expect(inDialog('Tk 1,50,000'), findsOneWidget);
    expect(inDialog(starterNote), findsOneWidget);

    await tester.tap(inDialog('Sell'));
    await h.settle(tester);
    await tester.pump();

    expect(h.engine.snapshot.vehicles, isEmpty);
    expect(h.engine.company!.cash, 1650000);
    expect(dialog, findsNothing);
    expect(detail, findsNothing, reason: 'the sold vehicle closes');
    expect(find.text('0 of 6 garage slots used'), findsOneWidget);
    expect(find.text('Cash: Tk 16,50,000'), findsOneWidget);
    expect(find.text('Sathi Plus sold. You got Tk 1,50,000.'), findsOneWidget);
    await letSnackBarGo(tester);
  });

  testWidgets('cancel sells nothing', (tester) async {
    await openGame(tester);
    await openTile(tester, 'Sathi Plus');
    await tapSell(tester);

    await tester.tap(inDialog('Cancel'));
    await tester.pump();

    expect(dialog, findsNothing);
    expect(h.engine.snapshot.vehicles, hasLength(1));
    expect(h.engine.company!.cash, 1500000);
    expect(detail, findsOneWidget);
  });

  testWidgets('a bought vehicle: resale value and no starter note', (
    tester,
  ) async {
    await openGame(tester, before: () => h.engine.buyVehicle(4));
    await openTile(tester, 'Sathi Plus');
    await tapSell(tester);

    expect(inDialog('Tk 7,80,000'), findsOneWidget);
    expect(find.textContaining('starter vehicle'), findsNothing);

    await tester.tap(inDialog('Sell'));
    await h.settle(tester);
    await tester.pump();

    expect(h.engine.snapshot.vehicles.single.isStarter, isTrue);
    expect(h.engine.company!.cash, 1500000 - 1300000 + 780000);
    await letSnackBarGo(tester);
  });

  testWidgets('on the road: refused, with Unassign offered', (tester) async {
    await openGame(tester);
    await tester.tap(find.text(startWorking));
    await h.settle(tester);
    await openTile(tester, 'Sathi Plus');
    await tapSell(tester);

    expect(find.text('Sell Sathi Plus?'), findsNothing, reason: 'no confirm');
    expect(inDialog(cannotSell), findsOneWidget);
    expect(
      inDialog(
        'This vehicle is on a trip. Unassign it so it does not start '
        'another one. It can be sold once the trip ends.',
      ),
      findsOneWidget,
    );

    await tester.tap(inDialog('Unassign'));
    await h.settle(tester);
    await tester.pump();

    expect(dialog, findsNothing);
    expect(h.engine.snapshot.vehicles.single.isAssigned, isFalse);
    expect(h.engine.snapshot.vehicles, hasLength(1), reason: 'not sold');

    // Still on its last trip: the reason changes and Unassign is gone.
    await tapSell(tester);
    expect(
      inDialog(
        'This vehicle is on its last trip. It can be sold once the trip ends.',
      ),
      findsOneWidget,
    );
    expect(inDialog('Unassign'), findsNothing);
    await tester.tap(inDialog('Close'));
    await tester.pump();

    // Once the trip is paid it sells.
    h.clock.advance(const Duration(seconds: 90));
    await h.tick(tester);
    await tapSell(tester);
    expect(find.text('Sell Sathi Plus?'), findsOneWidget);
  });

  testWidgets('the last vehicle is refused when cash would not buy another', (
    tester,
  ) async {
    // The Sonar Van, Tk 20,000, is the cheapest open vehicle. With a starter
    // that sells for nothing, Tk 19,999 is one Taka short.
    h = AppHarness(
      config: quietConfig((j) {
        j['settings']['startingCash'] = 19999;
        j['settings']['starterSaleValue'] = 0;
      }),
    );
    await openGame(tester);
    await openTile(tester, 'Sathi Plus');
    await tapSell(tester);

    expect(find.text('Sell Sathi Plus?'), findsNothing);
    expect(inDialog(cannotSell), findsOneWidget);
    expect(
      inDialog(
        'This is your last vehicle. After the sale your cash would not buy '
        'another one, and the company would have nothing left to earn with.',
      ),
      findsOneWidget,
    );
    expect(inDialog('Unassign'), findsNothing);

    await tester.tap(inDialog('Close'));
    await tester.pump();
    expect(dialog, findsNothing);
    expect(h.engine.snapshot.vehicles, hasLength(1));
  });

  testWidgets('already sold (a second tap): the dialog just closes', (
    tester,
  ) async {
    await openGame(tester);
    await openTile(tester, 'Sathi Plus');
    await tapSell(tester);
    expect(find.text('Sell Sathi Plus?'), findsOneWidget);

    // The vehicle is sold while the confirmation is open.
    unawaited(h.engine.sellVehicle(h.engine.snapshot.vehicles.single.id));
    await h.settle(tester);
    await tester.tap(inDialog('Sell'));
    await h.settle(tester);
    // The dialog's closing animation.
    await tester.pump(const Duration(seconds: 1));

    expect(dialog, findsNothing);
    expect(find.text(cannotSell), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(h.engine.company!.cash, 1650000, reason: 'paid once');
  });

  testWidgets('Bangla: the starter note', (tester) async {
    await openGame(tester, language: 'bn');
    await openTile(tester, 'সাথী প্লাস');
    await tapSell(tester, label: 'বিক্রি করুন');

    expect(find.text('সাথী প্লাস বিক্রি করবেন?'), findsOneWidget);
    expect(
      inDialog(
        'এটি আপনার কোম্পানির শুরুর যানবাহন। বিক্রি করলে নির্দিষ্ট '
        '৳ ১,৫০,০০০ পাবেন।',
      ),
      findsOneWidget,
    );
  });
}
