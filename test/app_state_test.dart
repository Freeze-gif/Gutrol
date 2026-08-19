import 'package:flutter_test/flutter_test.dart';
import 'package:petrol_customer_app/services/app_state.dart';

void main() {
  setUp(() {
    AppState.customerName = 'Test User';
    AppState.licensePlate = '1A-2345';
    AppState.walletBalance = 50000;
    AppState.walletTransactions = [
      {'id': 'TXN1', 'type': 'topup', 'amount': 50000.0},
    ];
    AppState.history = [
      {'id': 'ORD1', 'status': 'Completed'},
    ];
    AppState.targetMMK = 10000;
  });

  test('clear() resets the order in progress but keeps account data', () {
    AppState.clear();

    expect(AppState.targetMMK, 0.0);
    expect(AppState.walletBalance, 50000);
    expect(AppState.history, isNotEmpty);
    expect(AppState.customerName, 'Test User');
  });

  test('clearUserData() wipes everything tied to the signed-in account', () {
    AppState.clearUserData();

    expect(AppState.customerName, isEmpty);
    expect(AppState.licensePlate, isEmpty);
    expect(AppState.walletBalance, 0.0);
    expect(AppState.walletTransactions, isEmpty);
    expect(AppState.history, isEmpty);
  });

  test('clearUserData() leaves the pump controller address alone', () {
    AppState.setEsp32Ip('192.168.1.50');

    AppState.clearUserData();

    expect(AppState.esp32IpAddress, '192.168.1.50');
    expect(AppState.hasEsp32Ip, isTrue);
  });
}
