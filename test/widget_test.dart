// Basic Flutter widget test for PetrolCustomerApp.
//
// Note: Firebase must be initialized before running this test.
// We use setupAll to initialize a mock Firebase so the app can build.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:petrol_customer_app/main.dart';

void main() {
  // Ensure Flutter bindings are initialized before Firebase setup
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase may already be initialized or fail in test environment
    }
  });

  testWidgets('PetrolCustomerApp smoke test', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const PetrolCustomerApp());

    // Verify that the app renders without crashing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
