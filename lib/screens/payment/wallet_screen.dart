import 'package:flutter/material.dart';
import '../../services/app_state.dart';
import '../../services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  String _selectedPaymentMethod = 'KBZPay';

  @override
  void initState() {
    super.initState();
    // Initialize mock top-up transactions if empty
    if (AppState.walletTransactions.isEmpty) {
      AppState.addWalletTransaction({
        'id': '1',
        'type': 'topup',
        'amount': 50000.0,
        'description': 'KBZPay Top-up',
        'timestamp': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'status': 'Completed',
      });
    }
  }

  // Only show top-up transactions in wallet history
  List<Map<String, dynamic>> get _transactions => 
      AppState.walletTransactions.where((tx) => tx['type'] == 'topup').toList();

  void _showTopUpDialog() {
    // Local state for modal
    String selectedMethod = _selectedPaymentMethod;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top Up Wallet',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Enter Amount (MMK)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.account_balance_wallet, color: Color(0xFF1565C0)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildPaymentOptionModal('KBZPay', Icons.account_balance, Colors.blue, selectedMethod, (val) {
                setModalState(() => selectedMethod = val);
                _selectedPaymentMethod = val;
              }),
              _buildPaymentOptionModal('Wave Pay', Icons.waves, Colors.orange, selectedMethod, (val) {
                setModalState(() => selectedMethod = val);
                _selectedPaymentMethod = val;
              }),
              _buildPaymentOptionModal('AYA Pay', Icons.payment, Colors.purple, selectedMethod, (val) {
                setModalState(() => selectedMethod = val);
                _selectedPaymentMethod = val;
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _processTopUp();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Proceed to Top Up', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOptionModal(String name, IconData icon, Color color, String selected, Function(String) onSelect) {
    final isSelected = selected == name;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? color.withAlpha((0.1 * 255).round()) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: name,
        groupValue: selected,
        onChanged: (value) => onSelect(value!),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.black87,
              ),
            ),
          ],
        ),
        activeColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  void _processTopUp() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Quick payment processing
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (mounted) {
        final transaction = {
          'id': 'TXN${DateTime.now().millisecondsSinceEpoch}',
          'type': 'topup',
          'amount': amount,
          'description': '$_selectedPaymentMethod Top-up',
          'timestamp': DateTime.now().toIso8601String(),
          'status': 'Completed',
        };
        
        setState(() {
          AppState.walletBalance += amount;
          _isLoading = false;
          // Add transaction to AppState (persists across sessions)
          AppState.addWalletTransaction(transaction);
        });
        
        // Save to Firebase
        await WalletService.addTransaction(transaction);
        
        _amountController.clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Top-up of ${amount.toStringAsFixed(0)} MMK successful!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text('Prepaid Wallet'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildBalanceCard(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Text(
                  'Recent Transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions yet',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    return _buildTransactionItemFromMap(tx);
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTopUpDialog,
        backgroundColor: const Color(0xFFE53935),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Top Up', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withAlpha((0.3 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            '${AppState.walletBalance.toStringAsFixed(0)} MMK',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.qr_code, color: Colors.white, size: 30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItemFromMap(Map<String, dynamic> tx) {
    final isTopUp = tx['type'] == 'topup';
    final timestamp = DateTime.parse(tx['timestamp'] as String);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTopUp ? Colors.green.withAlpha((0.1 * 255).round()) : Colors.red.withAlpha((0.1 * 255).round()),
          child: Icon(
            isTopUp ? Icons.add : Icons.remove,
            color: isTopUp ? Colors.green : Colors.red,
          ),
        ),
        title: Text(tx['description'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(timestamp.toString().substring(0, 16)),
        trailing: Text(
          '${isTopUp ? "+" : "-"}${(tx['amount'] as double).toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isTopUp ? Colors.green : Colors.red,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
