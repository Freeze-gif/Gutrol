import 'package:flutter/material.dart';
import '../services/app_state.dart';
import 'live_status_screen.dart';

class FuelOrderScreen extends StatefulWidget {
  const FuelOrderScreen({super.key});

  @override
  State<FuelOrderScreen> createState() => _FuelOrderScreenState();
}

class _FuelOrderScreenState extends State<FuelOrderScreen> {
  String _selectedFuelType = 'Petrol 92';
  String _selectedMode = 'Auto Filling';
  final _litersController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  bool _isCalculating = false;

  // Price per liter in MMK (adjust as needed)
  final double _pricePerLiter = 2200.0;

  final List<String> _fuelTypes = ['Petrol 92', 'Petrol 95', 'Diesel'];
  final List<String> _modes = ['Auto Filling', 'Manual Filling'];

  Future<void> _submitOrder() async {
    if (_litersController.text.isEmpty && _amountController.text.isEmpty) {
      _showError('Please enter liters or amount');
      return;
    }

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 1));

    AppState.selectedFuelType = _selectedFuelType;
    AppState.selectedMode = _selectedMode;
    AppState.selectedAmount = '${_litersController.text} Liters / ${_amountController.text} MMK';
    AppState.liveStatus = 'Request Submitted';
    AppState.progress = 0.0;

    final order = {
      'fuelType': _selectedFuelType,
      'mode': _selectedMode,
      'amount': '${_litersController.text} Liters / ${_amountController.text} MMK',
      'date': DateTime.now().toString(),
      'status': 'Pending',
    };
    AppState.addToHistory(order);

    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LiveStatusScreen()),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onLitersChanged(String value) {
    if (_isCalculating) return;
    
    if (value.isNotEmpty) {
      final liters = double.tryParse(value) ?? 0;
      final amount = liters * _pricePerLiter;
      
      setState(() {
        _isCalculating = true;
        _amountController.text = amount.toStringAsFixed(0);
        _isCalculating = false;
      });
    } else {
      _amountController.clear();
    }
  }

  void _onAmountChanged(String value) {
    if (_isCalculating) return;
    
    if (value.isNotEmpty) {
      final amount = double.tryParse(value) ?? 0;
      final liters = amount / _pricePerLiter;
      
      setState(() {
        _isCalculating = true;
        _litersController.text = liters.toStringAsFixed(2);
        _isCalculating = false;
      });
    } else {
      _litersController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Fuel Order'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Fuel Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFuelType,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      items: _fuelTypes.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedFuelType = newValue!;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Filling Mode',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMode,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      items: _modes.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedMode = newValue!;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Liters',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _litersController,
                            keyboardType: TextInputType.number,
                            onChanged: _onLitersChanged,
                            decoration: InputDecoration(
                              hintText: 'e.g., 20',
                              suffixText: 'L',
                              prefixIcon: const Icon(Icons.local_gas_station),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue.shade400,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.sync_alt,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount (MMK)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            onChanged: _onAmountChanged,
                            decoration: InputDecoration(
                              hintText: 'e.g., 44000',
                              suffixText: 'Ks',
                              prefixIcon: const Icon(Icons.attach_money),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue.shade400,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Rate: ${_pricePerLiter.toStringAsFixed(0)} MMK/Liter',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'SUBMIT ORDER',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _litersController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
