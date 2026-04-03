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
  final _amountController = TextEditingController();
  bool _isLoading = false;

  final List<String> _fuelTypes = ['Petrol 92', 'Petrol 95', 'Diesel'];
  final List<String> _modes = ['Auto Filling', 'Manual Filling'];

  Future<void> _submitOrder() async {
    if (_amountController.text.isEmpty) {
      _showError('Please enter amount or liters');
      return;
    }

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 1));

    AppState.selectedFuelType = _selectedFuelType;
    AppState.selectedMode = _selectedMode;
    AppState.selectedAmount = _amountController.text;
    AppState.liveStatus = 'Request Submitted';
    AppState.progress = 0.0;

    final order = {
      'fuelType': _selectedFuelType,
      'mode': _selectedMode,
      'amount': _amountController.text,
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
                Text(
                  'Amount / Liters',
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
                  decoration: InputDecoration(
                    hintText: 'e.g., 20 Liters or 5000 MMK',
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
    _amountController.dispose();
    super.dispose();
  }
}
