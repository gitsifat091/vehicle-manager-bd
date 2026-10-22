import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/ui/layout.dart';
import 'package:vehicle_manager_bd/ui/shell/app_shell.dart';

import '../support/app_harness.dart';

void main() {
  late AppHarness h;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    h = AppHarness();
  });

  const phone = Size(390, 844);
  const desktop = Size(1280, 800);
  const comingLater = 'This screen comes in a later update.';

  /// Sets the window size in logical pixels. Can be called again mid-test to
  /// resize the window.
  void useWindow(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openAt(
    WidgetTester tester,
    Size size, {
    String? language,
  }) async {
    useWindow(tester, size);
    await h.open(tester, company: 'Padma Transport', language: language);
    await h.pump(tester);
  }

  final mapArea = find.byKey(AppShell.mapAreaKey);
  final sidePanel = find.byKey(AppShell.sidePanelKey);

  /// A place in the rail. On the wide layout a placeholder page repeats its
  /// name, so a plain text finder can match twice.
  Finder inRail(String label) => find.descendant(
    of: find.byType(NavigationRail),
    matching: find.text(label),
  );

  group('phone layout', () {
    testWidgets('a bottom bar with the four places, the garage first', (
      tester,
    ) async {
      await openAt(tester, phone);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      for (final label in ['Map', 'Garage', 'Finance', 'Settings']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, ShellDestination.garage.index);
      expect(find.text('Vehicles'), findsOneWidget);
      expect(find.text('Sathi Plus'), findsOneWidget);
      expect(mapArea, findsNothing);
      expect(sidePanel, findsNothing);
    });

    testWidgets('the bar switches the page', (tester) async {
      await openAt(tester, phone);

      await tester.tap(find.text('Finance'));
      await tester.pump();
      expect(find.text(comingLater), findsOneWidget);
      expect(find.text('Vehicles'), findsNothing);

      await tester.tap(find.text('Garage'));
      await tester.pump();
      expect(find.text('Vehicles'), findsOneWidget);
      expect(find.text(comingLater), findsNothing);
    });

    testWidgets('the header shows the company, cash and turbo', (tester) async {
      await openAt(tester, phone);

      final header = find.byType(AppBar);
      expect(
        find.descendant(of: header, matching: find.text('Padma Transport')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('Cash: Tk 15,00,000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('Turbo 20x')),
        findsOneWidget,
      );
    });

    testWidgets('touch targets meet the guideline', (tester) async {
      await openAt(tester, phone);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });

  group('wide layout', () {
    testWidgets('a rail, the map and the garage in the side panel', (
      tester,
    ) async {
      await openAt(tester, desktop);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, ShellDestination.garage.index);

      expect(mapArea, findsOneWidget);
      expect(sidePanel, findsOneWidget);
      expect(
        find.descendant(of: sidePanel, matching: find.text('Vehicles')),
        findsOneWidget,
      );
      expect(tester.getSize(sidePanel).width, Layout.sidePanelMaxWidth);
      // The map sits left of the panel and takes the rest of the width.
      expect(
        tester.getTopRight(mapArea).dx,
        lessThanOrEqualTo(tester.getTopLeft(sidePanel).dx),
      );
      expect(tester.getSize(mapArea).width, greaterThan(700));
    });

    testWidgets('at the breakpoint the panel keeps its minimum width', (
      tester,
    ) async {
      await openAt(tester, const Size(Layout.phoneBreakpoint, 800));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.getSize(sidePanel).width, Layout.sidePanelMinWidth);
      expect(tester.takeException(), isNull, reason: 'no overflow');
    });

    testWidgets('one pixel below the breakpoint is the phone layout', (
      tester,
    ) async {
      await openAt(tester, const Size(Layout.phoneBreakpoint - 1, 800));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('the map closes the panel, another place opens it', (
      tester,
    ) async {
      await openAt(tester, desktop);

      await tester.tap(inRail('Map'));
      await tester.pump();
      expect(sidePanel, findsNothing);
      expect(mapArea, findsOneWidget);
      expect(find.text('Vehicles'), findsNothing);

      await tester.tap(inRail('Settings'));
      await tester.pump();
      expect(
        find.descendant(of: sidePanel, matching: find.text(comingLater)),
        findsOneWidget,
      );
    });

    testWidgets('touch targets meet the guideline', (tester) async {
      await openAt(tester, desktop);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });

  testWidgets('resizing across the breakpoint keeps the selected place', (
    tester,
  ) async {
    await openAt(tester, desktop);
    await tester.tap(inRail('Finance'));
    await tester.pump();

    useWindow(tester, phone);
    await tester.pump();
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, ShellDestination.finance.index);
    expect(find.text(comingLater), findsOneWidget);

    useWindow(tester, desktop);
    await tester.pump();
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, ShellDestination.finance.index);
  });

  testWidgets('the turbo badge goes when Turbo Start ends', (tester) async {
    await openAt(tester, phone);
    expect(find.text('Turbo 20x'), findsOneWidget);

    h.clock.advance(const Duration(minutes: 61));
    await tester.runAsync(() => h.engine.tick());
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Turbo'), findsNothing);
  });

  testWidgets('Bangla: places, header and badge', (tester) async {
    await openAt(tester, phone, language: 'bn');

    for (final label in ['মানচিত্র', 'গ্যারেজ', 'হিসাব', 'সেটিংস']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('নগদ: ৳ ১৫,০০,০০০'), findsOneWidget);
    expect(find.text('টার্বো ২০ গুণ'), findsOneWidget);

    await tester.tap(find.text('হিসাব'));
    await tester.pump();
    expect(find.text('এই পাতাটি পরের কোনো আপডেটে আসবে।'), findsOneWidget);
  });
}
