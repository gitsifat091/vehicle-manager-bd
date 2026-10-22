import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/ui/layout.dart';

void main() {
  test('the phone layout ends at the breakpoint', () {
    expect(Layout.isPhone(360), true);
    expect(Layout.isPhone(599.9), true);
    expect(Layout.isPhone(600), false);
    expect(Layout.isPhone(1920), false);
  });

  test('the side panel takes half the area, within its min and max', () {
    expect(Layout.sidePanelWidth(520), Layout.sidePanelMinWidth);
    expect(Layout.sidePanelWidth(700), 350);
    expect(Layout.sidePanelWidth(1840), Layout.sidePanelMaxWidth);
  });
}
