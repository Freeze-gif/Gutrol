import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pump_status.dart';
import '../services/app_state.dart';
import '../services/esp32_service.dart';

/// Live Status Screen - Complete Redesign
/// Shows: Car Plate, Fuel Liters, Amount, Duration, Progress Line
class LiveStatusScreen extends StatefulWidget {
  const LiveStatusScreen({super.key});

  @override
  State<LiveStatusScreen> createState() => _LiveStatusScreenState();
}

class _LiveStatusScreenState extends State<LiveStatusScreen> {
  PumpStatus? _status;
  bool _isLoading = false;
  bool _isConnecting = false;
  String _errorMessage = '';
  Timer? _refreshTimer;
  
  // For tracking duration
  DateTime? _pumpStartTime;
  Timer? _durationTimer;
  Duration _elapsedDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    
    if (!Esp32Service.isConfigured && AppState.hasEsp32Ip) {
      Esp32Service.setIpAddress(AppState.esp32IpAddress);
    }
    
    _fetchStatus();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isLoading) {
        _fetchStatus();
      }
    });
  }

  void _startDurationTracking() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _pumpStartTime != null) {
        setState(() {
          _elapsedDuration = DateTime.now().difference(_pumpStartTime!);
        });
      }
    });
  }

  void _stopDurationTracking() {
    _durationTimer?.cancel();
    if (mounted) {
      setState(() {
        _elapsedDuration = Duration.zero;
        _pumpStartTime = null;
      });
    }
  }

  Future<void> _fetchStatus() async {
    if (!Esp32Service.isConfigured) {
      setState(() {
        _errorMessage = 'ESP32 IP not configured. Go to Dashboard to set IP.';
      });
      return;
    }

    final status = await Esp32Service.getStatus();
    
    if (mounted) {
      setState(() {
        _status = status;
        _isConnecting = status != null;
        if (status == null) {
          _errorMessage = 'Cannot connect to ESP32. Check IP and Wi-Fi.';
        } else {
          _errorMessage = '';
          
          // Track pump duration
          if (status.pumpRunning && _pumpStartTime == null) {
            _pumpStartTime = DateTime.now().subtract(Duration(milliseconds: status.pumpRunTimeMs));
            _startDurationTracking();
          } else if (!status.pumpRunning) {
            _stopDurationTracking();
          }
        }
      });
    }
  }

  Future<void> _manualRefresh() async {
    setState(() => _isLoading = true);
    await _fetchStatus();
    setState(() => _isLoading = false);
  }

  Future<void> _pumpOn() async {
    setState(() => _isLoading = true);
    final result = await Esp32Service.pumpOn();
    _showResult(result, 'Pump ON');
    await _fetchStatus();
    setState(() => _isLoading = false);
  }

  Future<void> _pumpOff() async {
    setState(() => _isLoading = true);
    final result = await Esp32Service.pumpOff();
    _showResult(result, 'Pump OFF');
    await _fetchStatus();
    setState(() => _isLoading = false);
  }

  Future<void> _emergencyStop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('EMERGENCY STOP'),
        content: const Text('Stop pump immediately?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('STOP', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final result = await Esp32Service.emergencyStop();
      _showResult(result, 'Emergency Stop');
      await _fetchStatus();
      setState(() => _isLoading = false);
    }
  }

  void _showResult(Map<String, dynamic> result, String action) {
    final success = result['success'] == true;
    final message = result['message'] ?? result['error'] ?? 'Unknown response';
    _showSnackBar(
      success ? '$action: $message' : 'Error: $message',
      isError: !success,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('emergency') || s.contains('error')) return Colors.red;
    if (s.contains('completed')) return Colors.green;
    if (s.contains('running')) return Colors.blue;
    if (s.contains('confirmed') || s.contains('waiting')) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Live Fueling Status'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _manualRefresh,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Connection Status
              _buildConnectionCard(),
              const SizedBox(height: 16),
              
              if (_status != null) ...[
                // Main Status Card with Car Plate, Liters, Amount, Duration
                _buildMainStatusCard(),
                const SizedBox(height: 16),
                
                // Progress Line
                _buildProgressCard(),
                const SizedBox(height: 16),
                
                // Tank Info
                _buildTankInfoCard(),
                const SizedBox(height: 16),
                
                // Quick Controls
                _buildQuickControls(),
                const SizedBox(height: 16),
                
                // Emergency Stop
                _buildEmergencyStopButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _isConnecting ? Icons.wifi : Icons.wifi_off,
              color: _isConnecting ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESP32 Connection',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                  Text(
                    Esp32Service.isConfigured ? 'IP: ${AppState.esp32IpAddress}' : 'Not configured',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isConnecting ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isConnecting ? 'Connected' : 'Disconnected',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isConnecting ? Colors.green : Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainStatusCard() {
    final statusColor = _getStatusColor(_status!.currentStatus);
    
    // Calculate values
    final remainingLiters = _status!.remainingLiters;
    final remainingMMK = _status!.remainingMMK;
    final dispensedLiters = _status!.wantLiters - remainingLiters;
    final dispensedMMK = _status!.wantMMK - remainingMMK;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Car Plate Number
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppState.licensePlate.isNotEmpty ? AppState.licensePlate : 'NO PLATE',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor, width: 2),
                ),
                child: Text(
                  _status!.currentStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Main Metrics Grid
              Row(
                children: [
                  // Fuel Liters
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.local_gas_station,
                      label: 'Fuel Dispensed',
                      value: '${dispensedLiters.toStringAsFixed(2)}',
                      unit: 'Liters',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Amount
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.attach_money,
                      label: 'Amount',
                      value: '${dispensedMMK.toStringAsFixed(0)}',
                      unit: 'MMK',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Duration
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Duration: ',
                      style: TextStyle(fontSize: 16, color: Colors.orange.shade800),
                    ),
                    Text(
                      _formatDuration(_elapsedDuration),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = _status!.wantLiters > 0
        ? ((_status!.wantLiters - _status!.remainingLiters) / _status!.wantLiters * 100).clamp(0, 100)
        : 0.0;
    
    final remainingLiters = _status!.remainingLiters;
    final wantLiters = _status!.wantLiters;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fueling Progress',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
                Text(
                  '${progress.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Progress Bar
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  // Progress fill
                  FractionallySizedBox(
                    widthFactor: progress / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade700],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // Percentage text
                  Center(
                    child: Text(
                      '${progress.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: progress > 50 ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Progress details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dispensed: ${(wantLiters - remainingLiters).toStringAsFixed(2)} L',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  'Target: ${wantLiters.toStringAsFixed(2)} L',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTankInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Station Tank Status',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTankMetric(
                    'Available',
                    '${_status!.tankLiters.toStringAsFixed(1)} L',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildTankMetric(
                    'Value',
                    '${_status!.tankMMK.toStringAsFixed(0)} Ks',
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTankMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildQuickControls() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Controls',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _status!.emergencyStop ? null : _pumpOn,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('START'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pumpOff,
                    icon: const Icon(Icons.stop),
                    label: const Text('STOP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyStopButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _emergencyStop,
        icon: const Icon(Icons.emergency, size: 28),
        label: const Text(
          'EMERGENCY STOP',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
