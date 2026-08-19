import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';

/// Payment Service for KBZPay, Wave Pay, and AYA Pay integration
class PaymentService {
  static final _functions = FirebaseFunctions.instance;
  
  // Price per liter in MMK (1L = 3200 MMK)
  static const Map<String, double> fuelPrices = {
    'Petrol 92': 3200,
    'Petrol 95': 3200,
    'Diesel': 3200,
  };

  /// Calculate liters from MMK amount
  static double calculateLiters(double mmkAmount, String fuelType) {
    final price = fuelPrices[fuelType] ?? 2200;
    return mmkAmount / price;
  }

  /// Calculate MMK amount from liters
  static double calculateMMK(double liters, String fuelType) {
    final price = fuelPrices[fuelType] ?? 2200;
    return liters * price;
  }

  /// Create a new payment
  static Future<Map<String, dynamic>> createPayment({
    required double amountMMK,
    required String fuelType,
    required String paymentMethod, // 'kbzpay', 'wavepay', 'ayapay'
  }) async {
    try {
      final callable = _functions.httpsCallable('createPayment');
      final result = await callable.call({
        'amountMMK': amountMMK,
        'fuelType': fuelType,
        'paymentMethod': paymentMethod,
      });

      return {
        'success': true,
        'transactionId': result.data['transactionId'],
        'transactionRef': result.data['transactionRef'],
        'paymentUrl': result.data['paymentUrl'],
        'qrCode': result.data['qrCode'],
        'qrImage': result.data['qrImage'],
        'deepLink': result.data['deepLink'],
        'expiresAt': result.data['expiresAt'],
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Payment creation failed',
        'code': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Check payment status (for polling)
  static Future<Map<String, dynamic>> checkPaymentStatus(String transactionId) async {
    try {
      final callable = _functions.httpsCallable('checkPaymentStatus');
      final result = await callable.call({
        'transactionId': transactionId,
      });

      return {
        'success': true,
        'status': result.data['status'],
        'paid': result.data['paid'] ?? false,
        'amount': result.data['amount'],
        'liters': result.data['liters'],
        'pumpStatus': result.data['pumpStatus'],
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Status check failed',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Start polling for payment status
  static Stream<Map<String, dynamic>> pollPaymentStatus(
    String transactionId, {
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 5),
  }) {
    final controller = StreamController<Map<String, dynamic>>();
    Timer? timer;
    DateTime startTime = DateTime.now();

    void checkStatus() async {
      final result = await checkPaymentStatus(transactionId);
      controller.add(result);

      // Stop if paid or error
      if (result['success'] == true && 
          (result['paid'] == true || result['status'] == 'failed')) {
        timer?.cancel();
        controller.close();
        return;
      }

      // Check timeout
      if (DateTime.now().difference(startTime) > timeout) {
        timer?.cancel();
        controller.add({
          'success': false,
          'error': 'Payment timeout. Please try again.',
          'timeout': true,
        });
        controller.close();
        return;
      }
    }

    // Start polling
    timer = Timer.periodic(interval, (_) => checkStatus());
    checkStatus(); // Initial check

    // Cleanup on cancel
    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  /// Get pump status for live tracking
  static Future<Map<String, dynamic>> getPumpStatus(String transactionId) async {
    try {
      final callable = _functions.httpsCallable('getPumpStatus');
      final result = await callable.call({
        'transactionId': transactionId,
      });

      return {
        'success': true,
        'status': result.data['status'],
        'litersDispensed': result.data['litersDispensed'],
        'litersTotal': result.data['litersTotal'],
        'progress': double.tryParse(result.data['progress'].toString()) ?? 0,
        'completed': result.data['completed'] ?? false,
        'error': result.data['error'] ?? false,
        'errorMessage': result.data['errorMessage'],
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Failed to get pump status',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Start polling pump status during fueling
  static Stream<Map<String, dynamic>> pollPumpStatus(
    String transactionId, {
    Duration interval = const Duration(seconds: 1),
  }) {
    final controller = StreamController<Map<String, dynamic>>();
    Timer? timer;

    void checkStatus() async {
      final result = await getPumpStatus(transactionId);
      controller.add(result);

      // Stop if completed or error
      if (result['success'] == true && 
          (result['completed'] == true || result['error'] == true)) {
        timer?.cancel();
        controller.close();
        return;
      }
    }

    timer = Timer.periodic(interval, (_) => checkStatus());
    checkStatus();

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  /// Open wallet app with deep link
  static Future<bool> openWalletApp(String deepLink) async {
    try {
      // For KBZPay, Wave Pay, AYA Pay deep links
      // Example: kbzpay://payment?token=xxx
      // Would use url_launcher package
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate payment amount
  static String? validateAmount(double amount) {
    if (amount < 1000) {
      return 'Minimum amount is 1,000 MMK';
    }
    if (amount > 500000) {
      return 'Maximum amount is 500,000 MMK';
    }
    if (amount % 100 != 0) {
      return 'Amount must be in multiples of 100 MMK';
    }
    return null;
  }

  /// Get payment method details
  static Map<String, dynamic> getPaymentMethodInfo(String method) {
    switch (method) {
      case 'kbzpay':
        return {
          'name': 'KBZPay',
          'icon': 'assets/icons/kbzpay.png',
          'color': 0xFF005BAA,
          'description': 'Pay with KBZPay wallet',
          'processingFee': 0,
        };
      case 'wavepay':
        return {
          'name': 'Wave Pay',
          'icon': 'assets/icons/wavepay.png',
          'color': 0xFFFF6B35,
          'description': 'Pay with Wave Pay',
          'processingFee': 0,
        };
      case 'ayapay':
        return {
          'name': 'AYA Pay',
          'icon': 'assets/icons/ayapay.png',
          'color': 0xFF00A651,
          'description': 'Pay with AYA Pay',
          'processingFee': 0,
        };
      case 'wallet':
        return {
          'name': 'Prepaid Wallet',
          'icon': 'W',
          'color': 0xFF1565C0,
          'description': 'Pay using your wallet balance',
          'processingFee': 0,
        };
      default:
        return {
          'name': 'Unknown',
          'icon': '',
          'color': 0xFF808080,
          'description': '',
          'processingFee': 0,
        };
    }
  }

  /// Get available payment methods
  static List<Map<String, dynamic>> getAvailablePaymentMethods() {
    return [
      getPaymentMethodInfo('wallet'),
    ];
  }
}
