import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_manager_bd/main.dart';

void main() {
  testWidgets('app starts and shows the placeholder screen', (tester) async {
    await tester.pumpWidget(const VehicleManagerApp());

    expect(find.byType(PlaceholderScreen), findsOneWidget);
  });
}
