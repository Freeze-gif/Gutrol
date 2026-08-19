// Basic Flutter widget test for PetrolCustomerApp.

import 'package:flutter_test/flutter_test.dart';

import 'package:petrol_customer_app/main.dart';

void main() {
  testWidgets('PetrolCustomerApp smoke test', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const PetrolCustomerApp());
    await tester.pumpAndSettle();

    // Verify that the app renders without crashing.
    expect(find.byType(PetrolCustomerApp), findsOneWidget);
  });
}
