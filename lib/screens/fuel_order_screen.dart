import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/esp32_service.dart';
import 'live_status_screen.dart';

class FuelOrderScreen extends StatefulWidget {
  const FuelOrderScreen({super.key});

  @override
  State<FuelOrderScreen> createState() => _FuelOrderScreenState();
}

class _FuelOrderScreenState extends State<FuelOrderScreen> {
  String _selectedFuelType = 'Petrol 92';
  String _selectedMode = 'Manual Filling';
  final _amountController = TextEditingController();
  bool _isLoading = false;
  bool _isFullTank = false;

  final double _pricePerLiter = 2200.0;
  final List<String> _fuelTypes = ['Petrol 92', 'Petrol 95', 'Diesel'];

  @override
  void initState() {
    super.initState();
    if (!Esp32Service.isConfigured && AppState.hasEsp32Ip) {
      Esp32Service.setIpAddress(AppState.esp32IpAddress);
    }
  }

  Future<void> _submitOrder() async {
    if (!Esp32Service.isConfigured) {
      _showError('ESP32 not configured. Please set IP in Dashboard.');
      return;
    }

    if (!_isFullTank && _amountController.text.isEmpty) {
      _showError('Please enter MMK amount or select Full Tank');
      return;
    }

    setState(() => _isLoading = true);

    double mmkAmount = 0;
    double litersAmount = 0;
    
    if (!_isFullTank) {
      mmkAmount = double.tryParse(_amountController.text) ?? 0;
      litersAmount = mmkAmount / _pricePerLiter;
    }

    AppState.selectedFuelType = _selectedFuelType;
    AppState.selectedMode = _isFullTank ? 'Auto Filling (Full Tank)' : 'Manual Filling';
    AppState.selectedAmount = _isFullTank 
        ? 'Full Tank (Auto Mode)'
        : '${litersAmount.toStringAsFixed(2)} Liters / ${mmkAmount.toStringAsFixed(0)} MMK';

    final order = {
      'fuelType': _selectedFuelType,
      'mode': AppState.selectedMode,
      'amount': AppState.selectedAmount,
      'date': DateTime.now().toString(),
      'status': 'Pending',
    };
    AppState.addToHistory(order);

    bool success = false;
    String message = '';

    if (_isFullTank) {
      final result = await Esp32Service.setAutoMode();
      if (result['success'] == true) {
        final startResult = await Esp32Service.startAutoFilling();
        success = startResult['success'] == true;
        message = startResult['message'] ?? startResult['error'] ?? 'Unknown response';
      } else {
        success = false;
        message = result['error'] ?? 'Failed to set auto mode';
      }
    } else {
      if (mmkAmount > 0) {
        final result = await Esp32Service.startManualFilling(mmkAmount);
        success = result['success'] == true;
        message = result['message'] ?? result['error'] ?? 'Unknown response';
      } else {
        message = 'Invalid MMK amount';
      }
    }

    setState(() => _isLoading = false);

    if (success) {
      _showSuccess('Order submitted: $message');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LiveStatusScreen()),
      );
    } else {
      _showError('Failed: $message');
    }
  }

  void _setFullTankMode() {
    setState(() {
      _isFullTank = true;
      _selectedMode = 'Auto Filling';
      _amountController.clear();
    });
    _showSuccess('Full Tank mode selected - Auto filling enabled');
  }

  void _setManualMode() {
    setState(() {
      _isFullTank = false;
      _selectedMode = 'Manual Filling';
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Fuel Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFuelType,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      items: _fuelTypes.map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (String? newValue) => setState(() => _selectedFuelType = newValue!),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Mode Selection Cards
                Text('Filling Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildModeCard(
                        title: 'Manual',
                        subtitle: 'Enter MMK',
                        icon: Icons.attach_money,
                        isSelected: !_isFullTank,
                        color: Colors.orange,
                        onTap: _setManualMode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModeCard(
                        title: 'Full Tank',
                        subtitle: 'Auto Mode',
                        icon: Icons.local_gas_station,
                        isSelected: _isFullTank,
                        color: Colors.purple,
                        onTap: _setFullTankMode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // MMK Input (only for manual mode)
                if (!_isFullTank) ...[
                  Text('Amount (MMK)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g., 10000',
                      suffixText: 'Ks',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade400, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Show calculated liters
                  if (_amountController.text.isNotEmpty)
                    Text(
                      '≈ ${(double.tryParse(_amountController.text) ?? 0 / _pricePerLiter).toStringAsFixed(2)} Liters',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Rate: ${_pricePerLiter.toStringAsFixed(0)} MMK/Liter',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Full tank info
                if (_isFullTank) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_mode, color: Colors.purple.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Auto Fill Mode', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade800)),
                              Text('Pump will automatically fill until tank is full or stopped by sensor', style: TextStyle(fontSize: 12, color: Colors.purple.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFullTank ? Colors.purple.shade700 : Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_isFullTank ? 'START FULL TANK' : 'SUBMIT ORDER', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey.shade600, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : Colors.grey.shade800)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
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
