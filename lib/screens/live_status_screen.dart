import 'package:flutter/material.dart';
import '../services/app_state.dart';

class LiveStatusScreen extends StatefulWidget {
  const LiveStatusScreen({super.key});

  @override
  State<LiveStatusScreen> createState() => _LiveStatusScreenState();
}

class _LiveStatusScreenState extends State<LiveStatusScreen> {
  final List<Map<String, dynamic>> _statusSteps = [
    {'status': 'Request Submitted', 'progress': 0.0, 'color': Colors.blue},
    {'status': 'Order Accepted', 'progress': 20.0, 'color': Colors.orange},
    {'status': 'Fueling Started', 'progress': 50.0, 'color': Colors.yellow},
    {'status': 'Fueling In Progress', 'progress': 80.0, 'color': Colors.lightBlue},
    {'status': 'Completed', 'progress': 100.0, 'color': Colors.green},
  ];

  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _updateStepIndex();
  }

  void _updateStepIndex() {
    for (int i = 0; i < _statusSteps.length; i++) {
      if (_statusSteps[i]['status'] == AppState.liveStatus) {
        _currentStepIndex = i;
        break;
      }
    }
  }

  void _simulateNextStep() {
    if (_currentStepIndex < _statusSteps.length - 1) {
      setState(() {
        _currentStepIndex++;
        AppState.liveStatus = _statusSteps[_currentStepIndex]['status'];
        AppState.progress = _statusSteps[_currentStepIndex]['progress'];
      });
    }
  }

  Color _getStatusColor() {
    return _statusSteps[_currentStepIndex]['color'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Live Status'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.local_gas_station,
                      size: 60,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 20),
                    _buildInfoRow('Fuel Type', AppState.selectedFuelType),
                    const Divider(),
                    _buildInfoRow('Mode', AppState.selectedMode),
                    const Divider(),
                    _buildInfoRow('Amount', AppState.selectedAmount),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Current Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        AppState.liveStatus,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: AppState.progress / 100,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getStatusColor(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${AppState.progress.toInt()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _simulateNextStep,
                icon: const Icon(Icons.skip_next),
                label: const Text('SIMULATE NEXT STEP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
