import 'package:flutter/material.dart';
import '../../services/payment_service.dart';
import '../../services/app_state.dart';
import '../../services/wallet_service.dart';

/// Payment Method Selection Screen
class PaymentMethodScreen extends StatefulWidget {
  final double amountMMK;
  final String fuelType;
  final double liters;

  const PaymentMethodScreen({
    super.key,
    required this.amountMMK,
    required this.fuelType,
    required this.liters,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String? _selectedMethod;
  bool _isLoading = false;
  String? _errorMessage;

  void _selectMethod(String method) {
    setState(() {
      _selectedMethod = method;
      _errorMessage = null;
    });
  }

  Future<void> _proceedToPayment() async {
    if (_selectedMethod == null) {
      setState(() {
        _errorMessage = 'Please select a payment method';
      });
      return;
    }

    // Check wallet balance if using prepaid wallet
    if (_selectedMethod == 'prepaidwallet') {
      if (AppState.walletBalance < widget.amountMMK) {
        setState(() {
          _errorMessage = 'Insufficient wallet balance. Current: ${AppState.walletBalance.toStringAsFixed(0)} MMK. Please top up your wallet.';
        });
        return;
      }
      
      // Deduct from the wallet in Firestore. Only report success once the
      // deduction has actually been stored, otherwise it is lost on re-login.
      setState(() => _isLoading = true);
      final saved = await WalletService.applyTransaction({
        'id': 'PAY${DateTime.now().millisecondsSinceEpoch}',
        'type': 'purchase',
        'amount': widget.amountMMK,
        'description': 'Fuel Payment - ${widget.fuelType}',
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'Completed',
      }, -widget.amountMMK);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!saved) {
        setState(() {
          _errorMessage = WalletService.lastError ??
              'Payment failed. Your balance was not changed.';
        });
        return;
      }

      // Show success and navigate to fueling
      _showWalletPaymentSuccess();
      return;
    }

    setState(() => _isLoading = true);

    // Generate mock transaction data (skip backend call for now)
    final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';
    final transactionRef = 'REF${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentStatusScreen(
            transactionId: transactionId,
            transactionRef: transactionRef,
            amountMMK: widget.amountMMK,
            liters: widget.liters,
            fuelType: widget.fuelType,
            paymentMethod: _selectedMethod!,
            qrCode: null,
            qrImage: null,
            deepLink: null,
            paymentUrl: null,
          ),
        ),
      );
    }
  }

  void _showWalletPaymentSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('Payment Successful'),
        content: Text('${widget.amountMMK.toStringAsFixed(0)} MMK has been deducted from your wallet.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => LiveFuelingScreen(
                    transactionId: 'TXN${DateTime.now().millisecondsSinceEpoch}',
                    amountMMK: widget.amountMMK,
                    liters: widget.liters,
                    fuelType: widget.fuelType,
                  ),
                ),
              );
            },
            child: const Text('Start Fueling'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final methods = PaymentService.getAvailablePaymentMethods();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Select Payment Method'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Order Summary
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fuel Type:',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Text(
                        widget.fuelType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount:',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Text(
                        '${widget.liters.toStringAsFixed(2)} L',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total to Pay:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.amountMMK.toStringAsFixed(0)} MMK',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Payment Methods
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: methods.length,
                itemBuilder: (context, index) {
                  final method = methods[index];
                  final isSelected = _selectedMethod == 
                    (method['name'] as String).toLowerCase().replaceAll(' ', '');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: isSelected ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected 
                          ? Color(method['color'] as int) 
                          : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => _selectMethod(
                        (method['name'] as String).toLowerCase().replaceAll(' ', ''),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Payment Icon
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Color(method['color'] as int).withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  (method['name'] as String)[0],
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(method['color'] as int),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    method['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    method['description'] as String,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if ((method['processingFee'] as int) > 0)
                                    Text(
                                      'Fee: ${method['processingFee']} MMK',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Selection indicator
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected 
                                    ? Color(method['color'] as int) 
                                    : Colors.grey.shade400,
                                  width: 2,
                                ),
                                color: isSelected 
                                  ? Color(method['color'] as int) 
                                  : Colors.transparent,
                              ),
                              child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Proceed Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _proceedToPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Proceed to Payment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Payment Status Screen - Shows QR code and tracks payment
class PaymentStatusScreen extends StatefulWidget {
  final String transactionId;
  final String transactionRef;
  final double amountMMK;
  final double liters;
  final String fuelType;
  final String paymentMethod;
  final String? qrCode;
  final String? qrImage;
  final String? deepLink;
  final String? paymentUrl;

  const PaymentStatusScreen({
    super.key,
    required this.transactionId,
    required this.transactionRef,
    required this.amountMMK,
    required this.liters,
    required this.fuelType,
    required this.paymentMethod,
    this.qrCode,
    this.qrImage,
    this.deepLink,
    this.paymentUrl,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  String _status = 'pending';
  bool _isLoading = true;
  Stream? _paymentStream;

  @override
  void initState() {
    super.initState();
    _startPaymentPolling();
  }

  void _startPaymentPolling() {
    _paymentStream = PaymentService.pollPaymentStatus(widget.transactionId);
    _paymentStream?.listen((result) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success'] == true) {
            _status = result['status'] ?? 'pending';
            
            // Navigate to live status if paid
            if (result['paid'] == true) {
              _navigateToLiveStatus();
            }
          }
        });
      }
    });
  }

  void _navigateToLiveStatus() {
    // Navigate to live fueling status screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiveFuelingScreen(
          transactionId: widget.transactionId,
          amountMMK: widget.amountMMK,
          liters: widget.liters,
          fuelType: widget.fuelType,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cancel polling
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final methodInfo = PaymentService.getPaymentMethodInfo(widget.paymentMethod);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Indicator
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _status == 'paid' 
                  ? Colors.green.shade50 
                  : _status == 'failed'
                    ? Colors.red.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _status == 'paid'
                    ? Colors.green.shade200
                    : _status == 'failed'
                      ? Colors.red.shade200
                      : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _status == 'paid'
                        ? Colors.green.shade100
                        : _status == 'failed'
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _status == 'paid'
                        ? Icons.check_circle
                        : _status == 'failed'
                          ? Icons.error
                          : Icons.access_time,
                      color: _status == 'paid'
                        ? Colors.green.shade700
                        : _status == 'failed'
                          ? Colors.red.shade700
                          : Colors.orange.shade700,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _status == 'paid'
                            ? 'Payment Successful!'
                            : _status == 'failed'
                              ? 'Payment Failed'
                              : 'Waiting for Payment...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _status == 'paid'
                              ? Colors.green.shade800
                              : _status == 'failed'
                                ? Colors.red.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _status == 'paid'
                            ? 'Your payment has been confirmed.'
                            : _status == 'failed'
                              ? 'Please try again or use another method.'
                              : 'Complete payment in your ${_getMethodName()} app',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // QR Code Section
            if (_status == 'pending')
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // QR Code or Future Available Message
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha((0.1 * 255).round()),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // KBZ Pay: Show local QR image
                            // Others: Show "Available in future"
                            if (widget.paymentMethod == 'kbzpay') ...[
                              // Local KBZ Pay QR Image
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'assets/img/kbzpay_qr.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.qr_code,
                                              size: 80,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Add kbzpay_qr.png\nto assets/img/',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Scan with KBZ Pay',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ref: ${widget.transactionRef}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ] else ...[
                              // Other payment methods - Show "Available in future"
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 60,
                                        color: Colors.orange.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Available in Future',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${methodInfo['name']}',
                                        style: TextStyle(
                                          color: Colors.orange.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Coming Soon',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How to pay:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInstructionStep('1', 'Open ${_getMethodName()} app'),
                            _buildInstructionStep('2', 'Tap Scan QR'),
                            _buildInstructionStep('3', 'Scan the code above'),
                            _buildInstructionStep('4', 'Confirm payment of ${widget.amountMMK.toStringAsFixed(0)} MMK'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Loading indicator
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),

            // Bottom buttons
            if (_status == 'failed')
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getMethodName() {
    final info = PaymentService.getPaymentMethodInfo(widget.paymentMethod);
    return info['name'] as String;
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live Fueling Screen - Shows pump status during fueling
class LiveFuelingScreen extends StatefulWidget {
  final String transactionId;
  final double amountMMK;
  final double liters;
  final String fuelType;

  const LiveFuelingScreen({
    super.key,
    required this.transactionId,
    required this.amountMMK,
    required this.liters,
    required this.fuelType,
  });

  @override
  State<LiveFuelingScreen> createState() => _LiveFuelingScreenState();
}

class _LiveFuelingScreenState extends State<LiveFuelingScreen> {
  Stream? _pumpStream;
  double _litersDispensed = 0;
  String _pumpStatus = 'dispensing';
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _startPumpPolling();
  }

  void _startPumpPolling() {
    _pumpStream = PaymentService.pollPumpStatus(widget.transactionId);
    _pumpStream?.listen((result) {
      if (mounted && result['success'] == true) {
        setState(() {
          _litersDispensed = result['litersDispensed'] ?? 0;
          _pumpStatus = result['status'] ?? 'dispensing';
          _completed = result['completed'] ?? false;
        });

        if (_completed) {
          _showCompletionDialog();
        }
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('Fueling Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.liters.toStringAsFixed(2)} liters of ${widget.fuelType} dispensed.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${widget.amountMMK.toStringAsFixed(0)} MMK',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _litersDispensed / widget.liters;

    return Scaffold(
      backgroundColor: Colors.blue.shade700,
      appBar: AppBar(
        title: const Text('Fueling in Progress'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Progress Circle
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha((0.1 * 255).round()),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withAlpha((0.2 * 255).round()),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_litersDispensed.toStringAsFixed(2)} L',
                              style: TextStyle(
                                color: Colors.white.withAlpha((0.8 * 255).round()),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Status
                Text(
                  _pumpStatus == 'dispensing' 
                    ? 'Dispensing Fuel...' 
                    : 'Fueling Complete',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Details
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Fuel Type', widget.fuelType),
                      const SizedBox(height: 8),
                      _buildDetailRow('Target', '${widget.liters.toStringAsFixed(2)} L'),
                      const SizedBox(height: 8),
                      _buildDetailRow('Amount', '${widget.amountMMK.toStringAsFixed(0)} MMK'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.8 * 255).round()),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
