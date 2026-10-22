import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/ui/layout.dart';

void main() {
  test('window classes change exactly at the breakpoints', () {
    expect(Layout.windowClassOf(360), WindowClass.compact);
    expect(Layout.windowClassOf(599), WindowClass.compact);
    expect(Layout.windowClassOf(599.9), WindowClass.compact);
    expect(Layout.windowClassOf(600), WindowClass.medium);
    expect(Layout.windowClassOf(839), WindowClass.medium);
    expect(Layout.windowClassOf(839.9), WindowClass.medium);
    expect(Layout.windowClassOf(840), WindowClass.expanded);
    expect(Layout.windowClassOf(1920), WindowClass.expanded);
  });

  test('the breakpoints are the named constants', () {
    expect(Layout.windowClassOf(Layout.mediumBreakpoint), WindowClass.medium);
    expect(
      Layout.windowClassOf(Layout.expandedBreakpoint),
      WindowClass.expanded,
    );
  });

  test('the map and the panel fit from 681 px beside the rail', () {
    // 360 map + 1 divider + 320 panel.
    expect(Layout.mapAndPanelFit(681), true);
    expect(Layout.mapAndPanelFit(680.9), false);
    expect(Layout.mapAndPanelFit(520), false);
  });

  test('the side panel takes half the area, up to its max', () {
    // 760 px beside the rail (a 840 px window, an 80 px rail): half of 759.
    expect(Layout.sidePanelWidth(760), 379.5);
    expect(Layout.sidePanelWidth(1840), Layout.sidePanelMaxWidth);
  });

  test('where both fit, neither goes below its minimum', () {
    // 711 px beside a wide rail: half would leave the map 355 px.
    expect(Layout.sidePanelWidth(711), 350);
    // At the edge both are exactly at their minimum.
    expect(Layout.sidePanelWidth(681), Layout.sidePanelMinWidth);
    for (var area = 681.0; area <= 1200; area += 0.5) {
      final panel = Layout.sidePanelWidth(area);
      final map = area - Layout.dividerWidth - panel;
      expect(map, greaterThanOrEqualTo(Layout.mapMinWidth), reason: '$area');
      expect(
        panel,
        inInclusiveRange(Layout.sidePanelMinWidth, Layout.sidePanelMaxWidth),
        reason: '$area',
      );
    }
  });

  test('asking for a panel where it does not fit is a bug', () {
    expect(() => Layout.sidePanelWidth(680), throwsA(isA<AssertionError>()));
  });
}
