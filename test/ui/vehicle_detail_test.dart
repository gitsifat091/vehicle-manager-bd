import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/core/economy/route_economics.dart';
import 'package:vehicle_manager_bd/core/format/formats.dart';
import 'package:vehicle_manager_bd/data/models/models.dart';
import 'package:vehicle_manager_bd/ui/screens/vehicle_detail.dart';
import 'package:vehicle_manager_bd/ui/shell/app_shell.dart';

import '../support/app_harness.dart';

void main() {
  late AppHarness h;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    h = AppHarness();
  });

  const en = Formats(bangla: false);
  const phone = Size(390, 844);
  const tablet = Size(700, 1000);
  const desktop = Size(1280, 800);

  const startWorking = 'Start working (temporary)';
  const back = 'Back to garage';
  const r01 = 'Tejgaon to Dhaka city, General dry goods';

  final detail = find.byType(VehicleDetail);
  final sidePanel = find.byKey(AppShell.sidePanelKey);

  void useWindow(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Opens a game at [size] with Turbo Start over, so an R01 trip of the
  /// starter takes its normal 84 seconds. [before] runs on the save before
  /// the first frame.
  Future<void> openGame(
    WidgetTester tester, {
    Size size = phone,
    String? language,
    Future<void> Function()? before,
  }) async {
    useWindow(tester, size);
    await h.open(tester, company: 'A', language: language);
    h.clock.advance(const Duration(minutes: 61));
    await tester.runAsync(() async {
      await h.engine.tick();
      await before?.call();
    });
    await h.pump(tester);
  }

  Future<void> startStarter(WidgetTester tester) async {
    await tester.tap(find.text(startWorking).first);
    await h.settle(tester);
  }

  Future<void> openTile(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).first);
    await tester.pump();
  }

  /// Scrolls the detail until [finder] is built and on screen.
  Future<void> reveal(WidgetTester tester, Finder finder) {
    return tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(of: detail, matching: find.byType(Scrollable))
          .first,
    );
  }

  int profitPerHourOfStarterOnR01() {
    final config = h.config;
    return routeEconomics(
      config: config,
      vehicle: config.vehicleByTier(4),
      route: config.routeById('R01'),
      cargo: config.cargoByName('General dry'),
    ).profitPerRealHour.round();
  }

  group('garage list', () {
    testWidgets('an idle vehicle shows its tier and no profit line', (
      tester,
    ) async {
      await openGame(tester);

      expect(find.text('Sathi Plus'), findsOneWidget);
      expect(find.text('Tier 4'), findsOneWidget);
      expect(find.text('Not assigned'), findsOneWidget);
      expect(find.textContaining('Expected profit'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('on the road: route, progress, time left and profit an hour', (
      tester,
    ) async {
      await openGame(tester);
      await startStarter(tester);

      expect(find.text('On the road'), findsOneWidget);
      expect(find.text(r01), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Arrives in 1:24'), findsOneWidget);
      final perHour = en.money(profitPerHourOfStarterOnR01());
      expect(find.text('Expected profit $perHour an hour'), findsOneWidget);
    });

    testWidgets('waiting for demand shows when it goes again', (tester) async {
      await openGame(
        tester,
        before: () => h.db.routeStates.put(
          RouteState(
            routeId: 'R01',
            demandRemainingT: 0,
            updatedAt: h.clock.now(),
          ),
        ),
      );
      await startStarter(tester);

      expect(find.text('Waiting for demand'), findsOneWidget);
      expect(find.textContaining('Goes again in'), findsOneWidget);
      expect(find.textContaining('Expected profit'), findsOneWidget);
    });
  });

  group('time left', () {
    double barValue(WidgetTester tester) => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    testWidgets('under one second left rounds up to 0:01', (tester) async {
      await openGame(tester);
      await startStarter(tester);

      // 0.8 of the 84 seconds left.
      h.clock.advance(const Duration(milliseconds: 83200));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Arrives in 0:01'), findsOneWidget);
      expect(find.text('Arrives in 0:00'), findsNothing);

      await openTile(tester, 'Sathi Plus');
      expect(find.text('Arrives in 0:01'), findsOneWidget);
    });

    testWidgets('a part second rounds up to the next whole second', (
      tester,
    ) async {
      await openGame(tester);
      await startStarter(tester);

      h.clock.advance(const Duration(milliseconds: 41500));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Arrives in 0:43'), findsOneWidget);
    });

    testWidgets('past arriveAt but not settled shows Arriving, bar full', (
      tester,
    ) async {
      await openGame(tester);
      await startStarter(tester);

      // Arrived, but the settle tick has not run yet.
      h.clock.advance(const Duration(seconds: 85));
      await tester.pump(const Duration(seconds: 1));
      expect(h.engine.snapshot.activeTripByVehicle, isNotEmpty);
      expect(find.text('Arriving'), findsOneWidget);
      expect(find.textContaining('Arrives in'), findsNothing);
      expect(barValue(tester), 1);

      await openTile(tester, 'Sathi Plus');
      expect(find.text('Arriving'), findsOneWidget);
      expect(barValue(tester), 1);
    });

    testWidgets('Bangla: Arriving', (tester) async {
      await openGame(tester, language: 'bn');
      await tester.tap(find.text('কাজে পাঠান (সাময়িক)'));
      await h.settle(tester);

      h.clock.advance(const Duration(seconds: 85));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('পৌঁছাচ্ছে'), findsOneWidget);
    });
  });

  group('vehicle detail', () {
    testWidgets('tapping a tile opens the detail in the page area', (
      tester,
    ) async {
      await openGame(tester);
      await openTile(tester, 'Sathi Plus');

      expect(detail, findsOneWidget);
      expect(find.text('Vehicles'), findsNothing);
      expect(find.text(back), findsOneWidget);
      expect(find.text('Tier 4'), findsOneWidget);
      expect(find.text('Not assigned'), findsOneWidget);
      // The free starter sells for the fixed starter value.
      expect(find.text('Sells for'), findsOneWidget);
      expect(find.text('Tk 1,50,000'), findsOneWidget);
      // The header stays on the page.
      expect(find.text('Cash: Tk 15,00,000'), findsOneWidget);

      await reveal(tester, find.text('Specifications'));
      await reveal(tester, find.text('Average speed'));
      expect(find.text('Tk 13,00,000'), findsOneWidget);
      expect(find.text('1.5 t'), findsOneWidget);
      expect(find.text('3 t'), findsOneWidget);
      expect(find.text('50 km/h'), findsOneWidget);
      expect(find.text('12 km per litre'), findsOneWidget);
    });

    testWidgets('a bought vehicle sells for the resale share of its price', (
      tester,
    ) async {
      await openGame(tester, before: () => h.engine.buyVehicle(4));
      expect(find.text('Sathi Plus'), findsNWidgets(2));

      await tester.tap(find.text('Sathi Plus').last);
      await tester.pump();

      // Tk 13 lakh x 0.6.
      expect(find.text('Tk 7,80,000'), findsOneWidget);
    });

    testWidgets('on the road: progress, profit an hour and the trip money', (
      tester,
    ) async {
      await openGame(tester);
      await startStarter(tester);
      await openTile(tester, 'Sathi Plus');

      final trip = h.engine.snapshot.activeTripByVehicle.values.single;
      expect(find.text('On the road'), findsOneWidget);
      expect(find.text(r01), findsOneWidget);
      expect(find.text('Arrives in 1:24'), findsOneWidget);
      expect(find.text('Expected profit per hour'), findsOneWidget);
      expect(
        find.text(en.money(profitPerHourOfStarterOnR01())),
        findsOneWidget,
      );

      await reveal(tester, find.text('Profit (expected)'));
      expect(find.text('Current trip'), findsOneWidget);
      expect(find.text(en.money(trip.revenue)), findsOneWidget);
      expect(find.text(en.money(-trip.costs.energy)), findsOneWidget);
      expect(find.text(en.money(trip.profit)), findsOneWidget);
    });

    testWidgets('a settled trip is listed under recent trips', (tester) async {
      await openGame(tester);
      await startStarter(tester);
      await openTile(tester, 'Sathi Plus');

      // Unassigned, the trip still finishes and the vehicle stays home, so
      // the only money on screen is the settled trip's.
      await tester.tap(find.text('Unassign'));
      await h.settle(tester);
      await reveal(tester, find.text('No finished trips yet.'));
      h.clock.advance(const Duration(seconds: 90));
      await h.tick(tester);

      final settled = h.engine.snapshot.recentTripsOf(
        h.engine.snapshot.vehicles.single.id,
      );
      expect(settled, hasLength(1));
      await reveal(tester, find.text('Recent trips'));
      expect(find.text('No finished trips yet.'), findsNothing);
      expect(find.text('Only the most recent trips are kept.'), findsOneWidget);
      expect(find.text(r01), findsOneWidget);
      expect(find.text(en.money(settled.single.profit)), findsOneWidget);
    });

    testWidgets('the in-page back button returns to the list', (tester) async {
      await openGame(tester);
      await openTile(tester, 'Sathi Plus');

      await tester.tap(find.text(back));
      await tester.pump();

      expect(detail, findsNothing);
      expect(find.text('Vehicles'), findsOneWidget);
    });

    testWidgets('the system back button closes the detail first', (
      tester,
    ) async {
      await openGame(tester);
      await openTile(tester, 'Sathi Plus');

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(detail, findsNothing);
      expect(find.text('Vehicles'), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('choosing the garage again goes back to the list', (
      tester,
    ) async {
      await openGame(tester);
      await openTile(tester, 'Sathi Plus');

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Garage'),
        ),
      );
      await tester.pump();

      expect(detail, findsNothing);
    });

    testWidgets('the detail stays open across a resize', (tester) async {
      await openGame(tester);
      await openTile(tester, 'Sathi Plus');
      expect(find.text(back), findsOneWidget);

      // Expanded: the detail sits in the side panel next to the map.
      useWindow(tester, desktop);
      await tester.pump();
      expect(sidePanel, findsOneWidget);
      expect(
        find.descendant(of: sidePanel, matching: find.text(back)),
        findsOneWidget,
      );

      // Medium: it fills the page area beside the rail.
      useWindow(tester, tablet);
      await tester.pump();
      expect(sidePanel, findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text(back), findsOneWidget);

      // Back on a phone it is still open.
      useWindow(tester, phone);
      await tester.pump();
      expect(find.text(back), findsOneWidget);
    });

    testWidgets('on a wide window the detail opens in the side panel', (
      tester,
    ) async {
      await openGame(tester, size: desktop);
      await tester.tap(
        find.descendant(of: sidePanel, matching: find.text('Sathi Plus')),
      );
      await tester.pump();

      expect(
        find.descendant(of: sidePanel, matching: find.byType(VehicleDetail)),
        findsOneWidget,
      );
      expect(find.byKey(AppShell.mapAreaKey), findsOneWidget);
    });

    testWidgets('unassign on the road: the trip finishes, then it stays home', (
      tester,
    ) async {
      await openGame(tester);
      await startStarter(tester);
      await openTile(tester, 'Sathi Plus');

      await tester.tap(find.text('Unassign'));
      await h.settle(tester);

      expect(h.engine.snapshot.vehicles.single.isAssigned, isFalse);
      expect(find.text('On the road'), findsOneWidget);
      expect(find.text(r01), findsOneWidget);
      expect(
        find.text('Not assigned any more. It comes home after this trip.'),
        findsOneWidget,
      );
      expect(find.text('Unassign'), findsNothing);
      expect(find.text('Expected profit per hour'), findsNothing);

      h.clock.advance(const Duration(seconds: 90));
      await h.tick(tester);
      expect(find.text('Not assigned'), findsOneWidget);
      expect(find.text(startWorking), findsOneWidget);
    });

    testWidgets('unassign while waiting for demand makes it idle', (
      tester,
    ) async {
      await openGame(
        tester,
        before: () => h.db.routeStates.put(
          RouteState(
            routeId: 'R01',
            demandRemainingT: 0,
            updatedAt: h.clock.now(),
          ),
        ),
      );
      await startStarter(tester);
      await openTile(tester, 'Sathi Plus');
      expect(find.text('Waiting for demand'), findsOneWidget);

      await tester.tap(find.text('Unassign'));
      await h.settle(tester);

      expect(find.text('Not assigned'), findsOneWidget);
      expect(find.textContaining('Goes again in'), findsNothing);
    });

    testWidgets('Bangla: tier, sale value and digits', (tester) async {
      await openGame(tester, language: 'bn');
      await openTile(tester, 'সাথী প্লাস');

      expect(find.text('গ্যারেজে ফিরুন'), findsOneWidget);
      expect(find.text('স্তর ৪'), findsOneWidget);
      expect(find.text('৳ ১,৫০,০০০'), findsOneWidget);
    });
  });
}
