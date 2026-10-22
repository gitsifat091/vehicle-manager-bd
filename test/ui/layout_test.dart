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

  test('the side panel takes half the area, within its min and max', () {
    // 760 px beside the rail (a 840 px window, an 80 px rail): half of 759.
    expect(Layout.sidePanelWidth(760), 379.5);
    expect(Layout.sidePanelWidth(520), Layout.sidePanelMinWidth);
    expect(Layout.sidePanelWidth(1840), Layout.sidePanelMaxWidth);
  });

  test('the panel gives way so the map keeps its minimum', () {
    // 711 px beside a wide rail: half would leave the map 355 px.
    expect(Layout.sidePanelWidth(711), 350);
    for (var area = 681.0; area <= 1200; area += 0.5) {
      final map = area - Layout.dividerWidth - Layout.sidePanelWidth(area);
      expect(map, greaterThanOrEqualTo(Layout.mapMinWidth), reason: '$area');
    }
  });
}
