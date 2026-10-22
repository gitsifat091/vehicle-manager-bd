import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/ui/layout.dart';
import 'package:vehicle_manager_bd/ui/screens/garage_screen.dart';
import 'package:vehicle_manager_bd/ui/shell/app_shell.dart';

import '../support/app_harness.dart';

void main() {
  late AppHarness h;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    h = AppHarness();
  });

  const phone = Size(390, 844);
  const tablet = Size(700, 1000);
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

  Future<void> resizeTo(WidgetTester tester, double width) async {
    useWindow(tester, Size(width, 800));
    await tester.pump();
  }

  final mapArea = find.byKey(AppShell.mapAreaKey);
  final sidePanel = find.byKey(AppShell.sidePanelKey);
  final bar = find.byType(NavigationBar);
  final rail = find.byType(NavigationRail);

  /// A place in the rail. A placeholder page repeats its name, so a plain
  /// text finder can match twice.
  Finder inRail(String label) =>
      find.descendant(of: rail, matching: find.text(label));

  /// The selected place, from the bar or the rail, whichever is shown.
  int selectedIndex(WidgetTester tester) => bar.evaluate().isNotEmpty
      ? tester.widget<NavigationBar>(bar).selectedIndex
      : tester.widget<NavigationRail>(rail).selectedIndex!;

  /// Checks the shell is in the layout of [windowClass], with a page other
  /// than the map selected.
  void expectLayout(WindowClass windowClass) {
    final compact = windowClass == WindowClass.compact;
    final expanded = windowClass == WindowClass.expanded;
    expect(bar, compact ? findsOneWidget : findsNothing, reason: 'bar');
    expect(rail, compact ? findsNothing : findsOneWidget, reason: 'rail');
    expect(mapArea, expanded ? findsOneWidget : findsNothing, reason: 'map');
    expect(
      sidePanel,
      expanded ? findsOneWidget : findsNothing,
      reason: 'panel',
    );
  }

  /// The width beside the rail: what a page fills in the medium layout.
  double besideRail(WidgetTester tester, double windowWidth) =>
      windowWidth - tester.getSize(rail).width - 1;

  group('the layout at each breakpoint', () {
    for (final (width, windowClass) in [
      (599.0, WindowClass.compact),
      (600.0, WindowClass.medium),
      (839.0, WindowClass.medium),
      (840.0, WindowClass.expanded),
    ]) {
      testWidgets('$width px is ${windowClass.name}', (tester) async {
        await openAt(tester, Size(width, 800));
        expectLayout(windowClass);
        expect(find.text('Vehicles'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'no overflow');
      });
    }
  });

  group('compact layout', () {
    testWidgets('a bottom bar with the four places, the garage first', (
      tester,
    ) async {
      await openAt(tester, phone);

      expectLayout(WindowClass.compact);
      for (final label in ['Map', 'Garage', 'Finance', 'Settings']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(selectedIndex(tester), ShellDestination.garage.index);
      expect(find.text('Vehicles'), findsOneWidget);
      expect(find.text('Sathi Plus'), findsOneWidget);
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

  group('medium layout', () {
    testWidgets('a rail, and the garage fills the area beside it', (
      tester,
    ) async {
      await openAt(tester, tablet);

      expectLayout(WindowClass.medium);
      expect(selectedIndex(tester), ShellDestination.garage.index);
      expect(
        tester.getSize(find.byType(GarageScreen)).width,
        besideRail(tester, tablet.width),
      );
    });

    testWidgets('no side panel for any page; the map fills the area', (
      tester,
    ) async {
      await openAt(tester, tablet);

      for (final label in ['Map', 'Garage', 'Finance', 'Settings']) {
        await tester.tap(inRail(label));
        await tester.pump();
        expect(sidePanel, findsNothing, reason: label);
        expect(
          mapArea,
          label == 'Map' ? findsOneWidget : findsNothing,
          reason: label,
        );
      }

      await tester.tap(inRail('Map'));
      await tester.pump();
      expect(tester.getSize(mapArea).width, besideRail(tester, tablet.width));
      expect(find.text('Vehicles'), findsNothing);
    });

    testWidgets('the header is shown', (tester) async {
      await openAt(tester, tablet);
      final header = find.byType(AppBar);
      expect(
        find.descendant(of: header, matching: find.text('Padma Transport')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('Turbo 20x')),
        findsOneWidget,
      );
    });

    testWidgets('touch targets meet the guideline', (tester) async {
      await openAt(tester, tablet);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });

  group('expanded layout', () {
    testWidgets('a rail, the map and the garage in the side panel', (
      tester,
    ) async {
      await openAt(tester, desktop);

      expectLayout(WindowClass.expanded);
      expect(selectedIndex(tester), ShellDestination.garage.index);
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

    testWidgets('at 840 px the map is at least 360 px wide', (tester) async {
      await openAt(tester, const Size(Layout.expandedBreakpoint, 800));
      expect(tester.getSize(mapArea).width, greaterThanOrEqualTo(360));
      expect(
        tester.getSize(sidePanel).width,
        inInclusiveRange(Layout.sidePanelMinWidth, Layout.sidePanelMaxWidth),
      );
    });

    testWidgets('a rail too wide for map and panel falls back to medium', (
      tester,
    ) async {
      const width = Layout.expandedBreakpoint;
      await openAt(tester, const Size(width, 800));
      expect(sidePanel, findsOneWidget);

      // Large text widens the rail's labels until less than 681 px is left.
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      expect(Layout.mapAndPanelFit(besideRail(tester, width)), false);
      expect(rail, findsOneWidget);
      expect(sidePanel, findsNothing);
      expect(mapArea, findsNothing);
      expect(selectedIndex(tester), ShellDestination.garage.index);
      expect(
        tester.getSize(find.byType(GarageScreen)).width,
        besideRail(tester, width),
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');

      // The map selected fills the area, like the medium layout.
      await tester.tap(inRail('Map'));
      await tester.pump();
      expect(tester.getSize(mapArea).width, besideRail(tester, width));

      // Normal text again: map and panel are back, the selection kept.
      await tester.tap(inRail('Garage'));
      await tester.pump();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pump();
      expect(sidePanel, findsOneWidget);
      expect(tester.getSize(mapArea).width, greaterThanOrEqualTo(360));
      expect(
        find.descendant(of: sidePanel, matching: find.byType(GarageScreen)),
        findsOneWidget,
      );
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

  group('resizing keeps the selected place', () {
    testWidgets('across 600 px, both ways', (tester) async {
      await openAt(tester, tablet);
      await tester.tap(inRail('Finance'));
      await tester.pump();

      await resizeTo(tester, Layout.mediumBreakpoint - 1);
      expectLayout(WindowClass.compact);
      expect(selectedIndex(tester), ShellDestination.finance.index);
      expect(find.text(comingLater), findsOneWidget);

      await resizeTo(tester, Layout.mediumBreakpoint);
      expectLayout(WindowClass.medium);
      expect(selectedIndex(tester), ShellDestination.finance.index);
      expect(find.text(comingLater), findsOneWidget);
    });

    testWidgets('across 840 px, both ways, with the garage', (tester) async {
      await openAt(tester, const Size(Layout.expandedBreakpoint, 800));
      expect(
        find.descendant(of: sidePanel, matching: find.byType(GarageScreen)),
        findsOneWidget,
      );

      // Expanded to medium: the garage leaves the panel and fills the area.
      await resizeTo(tester, Layout.expandedBreakpoint - 1);
      expectLayout(WindowClass.medium);
      expect(selectedIndex(tester), ShellDestination.garage.index);
      expect(
        tester.getSize(find.byType(GarageScreen)).width,
        besideRail(tester, Layout.expandedBreakpoint - 1),
      );

      // Medium to expanded: the map comes back with the garage in the panel.
      await resizeTo(tester, Layout.expandedBreakpoint);
      expectLayout(WindowClass.expanded);
      expect(selectedIndex(tester), ShellDestination.garage.index);
      expect(
        find.descendant(of: sidePanel, matching: find.byType(GarageScreen)),
        findsOneWidget,
      );
    });

    testWidgets('from desktop to phone and back', (tester) async {
      await openAt(tester, desktop);
      await tester.tap(inRail('Finance'));
      await tester.pump();

      await resizeTo(tester, phone.width);
      expect(selectedIndex(tester), ShellDestination.finance.index);
      expect(find.text(comingLater), findsOneWidget);

      await resizeTo(tester, desktop.width);
      expect(selectedIndex(tester), ShellDestination.finance.index);
    });
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
