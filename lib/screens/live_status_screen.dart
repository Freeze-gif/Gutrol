import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pump_status.dart';
import '../services/app_state.dart';
import '../services/esp32_service.dart';
import '../services/wallet_service.dart';
import 'home_screen.dart';

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
  Timer? _refreshTimer;
  bool _hasCompleted = false; // Prevent double charging

  /// True until the very first status poll has come back, so the screen can
  /// show a spinner instead of a blank page.
  bool _isFirstLoad = true;

  /// Consecutive failed polls. One dropped packet must not be mistaken for
  /// "the pump stopped", which would end the session and charge the wallet.
  int _consecutiveFailures = 0;
  static const int _failureTolerance = 3;

  // For tracking duration
  DateTime? _pumpStartTime;
  Timer? _durationTimer;
  Duration _elapsedDuration = Duration.zero;

  @override
  void initState() {
    super.initState();

    // Keep the service pointed at the configured address.
    if (AppState.hasEsp32Ip) {
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
      });
    }
  }

  Future<void> _onFuelingComplete() async {
    // Prevent multiple executions
    if (_hasCompleted) return;
    _hasCompleted = true;
    
    // Calculate final values - fallback to duration if ESP32 returns 0
    const double litersPerSecond = 0.125; // 1L = 8 seconds
    const double pricePerLiter = 3200.0;
    
    double wantLiters = _status?.wantLiters ?? 0;
    double remainingLiters = _status?.remainingLiters ?? 0;
    
    // Use AppState target if ESP32 didn't track
    if (wantLiters <= 0) {
      wantLiters = AppState.targetLiters;
    }
    
    // If still no target, calculate from duration
    if (wantLiters <= 0 && _elapsedDuration.inSeconds > 0) {
      wantLiters = _elapsedDuration.inSeconds * litersPerSecond;
    }
    
    // Assume all dispensed when complete
    remainingLiters = 0;
    
    final dispensedLiters = (wantLiters - remainingLiters).clamp(0, double.infinity).toDouble();
    
    // Use AppState target MMK if available, otherwise calculate from liters
    double dispensedMMK = AppState.targetMMK;
    if (dispensedMMK <= 0) {
      dispensedMMK = (dispensedLiters * pricePerLiter).toDouble();
    }
    
    // Stop refresh timer
    _refreshTimer?.cancel();
    
    // Create fuel purchase transaction
    final fuelTransaction = {
      'id': 'FUEL${DateTime.now().millisecondsSinceEpoch}',
      'type': 'purchase',
      'amount': dispensedMMK,
      'description': 'Fuel Purchase - ${AppState.selectedFuelType}',
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'Completed',
    };

    // Deduct in Firestore and mirror the stored balance locally. Doing the
    // deduction here (rather than on the local static) is what keeps the
    // balance correct after signing out and back in.
    final charged =
        await WalletService.applyTransaction(fuelTransaction, -dispensedMMK);

    // Update order status in history (await to ensure Firebase update completes)
    await _updateOrderStatus(dispensedMMK);

    // Clear pump start time to prevent re-triggering
    _pumpStartTime = null;

    if (!mounted) return;

    if (!charged) {
      _showSnackBar(
        WalletService.lastError ??
            'Could not record this fill-up. Please check your connection.',
        isError: true,
      );
    }

    // Show completion dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle, color: Colors.green.shade600, size: 64),
        title: const Text('Fueling Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${dispensedLiters.toStringAsFixed(2)} Liters dispensed',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Amount: ${dispensedMMK.toStringAsFixed(0)} MMK',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deducted from wallet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New Balance: ${AppState.walletBalance.toStringAsFixed(0)} MMK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppState.walletBalance < 10000 ? Colors.red : const Color(0xFF1565C0),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              // Close servo before leaving (backup to hardware timer)
              await Esp32Service.servoOff();
              navigator.pop();
              navigator.pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(double amount) async {
    // Calculate liters from amount
    const double pricePerLiter = 3200.0;
    final liters = amount / pricePerLiter;
    
    // Find the pending order and update it locally
    for (var order in AppState.history) {
      if (order['status'] == 'Pending') {
        order['status'] = 'Completed';
        order['amount'] = '${liters.toStringAsFixed(2)} Liters / ${amount.toStringAsFixed(0)} MMK';
        break;
      }
    }
    
    // Update in Firebase
    await WalletService.updateOrderStatus('', 'Completed', amount);
  }

  Future<void> _fetchStatus() async {
    final status = await Esp32Service.getStatus();
    if (!mounted) return;

    // Update global hazard status
    if (status != null) {
      AppState.updateHazardStatus(status.hazardActive);
    }

    setState(() {
      _isFirstLoad = false;

      if (status != null) {
        _consecutiveFailures = 0;
        _status = status;
        AppState.isEsp32Connected = true;

        // Track pump duration
        if (status.pumpRunning && _pumpStartTime == null) {
          _pumpStartTime =
              DateTime.now().subtract(Duration(milliseconds: status.pumpRunTimeMs));
          _startDurationTracking();
        }
      } else {
        _consecutiveFailures++;
        if (_consecutiveFailures >= _failureTolerance) {
          // Only declare the controller offline after repeated failures, so a
          // single dropped poll does not blank out a live session.
          _status = null;
          AppState.isEsp32Connected = false;
        }
      }
    });

    // Handle fueling completion or hazard stop outside setState
    if (_pumpStartTime == null || _hasCompleted) return;

    if (status != null && status.hazardActive) {
      _stopDurationTracking();
      await _onHazardStop();
    } else if (status != null && !status.pumpRunning) {
      // The controller reported the pump has stopped - the session is done.
      _stopDurationTracking();
      await _onFuelingComplete();
    } else if (status == null && _consecutiveFailures >= _failureTolerance) {
      // Lost the controller mid-fill. Settle up with what was dispensed so
      // far rather than leaving the order pending forever.
      _stopDurationTracking();
      await _onFuelingComplete();
    }
  }

  Future<void> _onHazardStop() async {
    if (_hasCompleted) return;
    _hasCompleted = true;
    _refreshTimer?.cancel();
    
    // Calculate partial values
    const double litersPerSecond = 0.125;
    const double pricePerLiter = 3200.0;
    final dispensedLiters = (_elapsedDuration.inSeconds * litersPerSecond).toDouble();
    final dispensedMMK = (dispensedLiters * pricePerLiter).toDouble();

    // Deduct only what was dispensed - through Firestore, so the deduction
    // survives a re-login.
    await WalletService.applyTransaction({
      'id': 'HAZ${DateTime.now().millisecondsSinceEpoch}',
      'type': 'purchase',
      'amount': dispensedMMK,
      'description': 'Fuel Purchase (hazard stop) - ${AppState.selectedFuelType}',
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'Completed',
    }, -dispensedMMK);

    // Save partial history with hazard tag
    final hazardOrder = {
      'fuelType': AppState.selectedFuelType,
      'mode': AppState.selectedMode,
      'amount': '${dispensedLiters.toStringAsFixed(2)} L / ${dispensedMMK.toStringAsFixed(0)} MMK',
      'date': DateTime.now().toString(),
      'status': 'stopped_by_hazard',
      'hazardStop': true,
      'note': 'Stopped due to gas hazard'
    };
    AppState.addToHistory(hazardOrder);
    await WalletService.saveOrder(hazardOrder);
    
    // Close servo on hazard stop
    await Esp32Service.servoOff();
    
    _pumpStartTime = null;
  }

  Future<void> _manualRefresh() async {
    setState(() => _isLoading = true);
    await _fetchStatus();
    if (!mounted) return;
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

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      final result = await Esp32Service.emergencyStop();
      if (!mounted) return;
      _showResult(result, 'Emergency Stop');
      await _fetchStatus();
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showResult(Map<String, dynamic> result, String action) {
    final success = result['success'] == true;
    final message = result['message'] ?? result['error'] ?? '';
    if (message.isNotEmpty) {
      _showSnackBar(
        success ? '$action: $message' : 'Error: $message',
        isError: !success,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
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
            onPressed: _isLoading ? null : _showIpDialog,
            tooltip: 'Pump controller address',
            icon: const Icon(Icons.settings_ethernet),
          ),
          IconButton(
            onPressed: _isLoading ? null : _manualRefresh,
            tooltip: 'Refresh',
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
              if (_status != null) ...[
                // Main Status Card with Car Plate, Liters, Amount, Duration
                _buildMainStatusCard(),
                const SizedBox(height: 16),

                // Progress Line
                _buildProgressCard(),
                const SizedBox(height: 16),

                // Emergency Stop
                _buildEmergencyStopButton(),
              ] else
                // Never leave the screen blank - say what is happening and
                // give the user a way to fix it.
                _buildConnectionState(),
            ],
          ),
        ),
      ),
    );
  }

  /// Shown while the first poll is in flight, and whenever the controller
  /// cannot be reached.
  Widget _buildConnectionState() {
    if (_isFirstLoad) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Connecting to the fuel pump...',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.wifi_off, size: 72, color: Colors.red.shade300),
          const SizedBox(height: 20),
          const Text(
            'Pump controller not reachable',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Tried ${Esp32Service.baseUrl}/status',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          Text(
            'Make sure your phone is on the same Wi-Fi network as the ESP32, '
            'then check the address below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _manualRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _showIpDialog,
                icon: const Icon(Icons.settings_ethernet),
                label: const Text('Change IP address'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Let the user point the app at the ESP32's current address. The device is
  /// on DHCP, so a hardcoded IP goes stale every time it reconnects.
  Future<void> _showIpDialog() async {
    final controller = TextEditingController(text: AppState.esp32IpAddress);
    String? errorText;

    final newIp = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pump Controller Address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'ESP32 IP address',
                  hintText: AppState.defaultEsp32Ip,
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The ESP32 prints its IP address to the serial monitor when it '
                'joins the Wi-Fi network.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (!Esp32Service.isValidIp(value)) {
                  setDialogState(() => errorText = 'Enter a valid IPv4 address');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );

    if (newIp == null || !mounted) return;

    Esp32Service.setIpAddress(newIp);
    setState(() {
      _status = null;
      _isFirstLoad = true;
      _consecutiveFailures = 0;
    });
    await _manualRefresh();
    if (!mounted) return;
    _showSnackBar(
      AppState.isEsp32Connected
          ? 'Connected to $newIp'
          : 'Still cannot reach $newIp',
      isError: !AppState.isEsp32Connected,
    );
  }

  Widget _buildMainStatusCard() {
    final statusColor = _getStatusColor(_status!.currentStatus);
    
    // Calculate values - using 3200 MMK per liter
    const double pricePerLiter = 3200.0;
    const double litersPerSecond = 0.125; // 1 Liter = 8 seconds
    
    // Try to get target from ESP32 first, then AppState, then duration-based
    double wantLiters = _status!.wantLiters;
    if (wantLiters <= 0) {
      wantLiters = AppState.targetLiters;
    }
    if (wantLiters <= 0 && _elapsedDuration.inSeconds > 0) {
      wantLiters = _elapsedDuration.inSeconds * litersPerSecond;
    }
    if (wantLiters <= 0) {
      wantLiters = 1; // Default to avoid division by zero
    }
    
    // Calculate remaining - use ESP32 value or estimate from duration
    double remainingLiters = _status!.remainingLiters;
    if (_status!.pumpRunning && _elapsedDuration.inSeconds > 0) {
      final estimatedDispensed = _elapsedDuration.inSeconds * litersPerSecond;
      remainingLiters = (wantLiters - estimatedDispensed).clamp(0, wantLiters);
    } else if (!_status!.pumpRunning && _elapsedDuration.inSeconds > 0) {
      // Pump stopped - assume all dispensed
      remainingLiters = 0;
    }
    
    final dispensedLiters = (wantLiters - remainingLiters).clamp(0, double.infinity).toDouble();
    final dispensedMMK = (dispensedLiters * pricePerLiter).toDouble();
    
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
                  color: statusColor.withAlpha((0.1 * 255).round()),
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
                      value: dispensedLiters.toStringAsFixed(2),
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
                      value: dispensedMMK.toStringAsFixed(0),
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
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
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
    // Progress calculation - dispensed / target
    const double litersPerSecond = 0.125; // 1L = 8 seconds
    
    // Get target from ESP32, then AppState, then duration-based estimate
    double wantLiters = _status!.wantLiters;
    if (wantLiters <= 0) {
      wantLiters = AppState.targetLiters;
    }
    if (wantLiters <= 0 && _elapsedDuration.inSeconds > 0) {
      wantLiters = _elapsedDuration.inSeconds * litersPerSecond;
    }
    if (wantLiters <= 0) {
      wantLiters = 1; // Default to avoid division by zero
    }
    
    // Calculate dispensed based on duration while pump is running
    double dispensedLiters = 0;
    if (_status!.pumpRunning && _elapsedDuration.inSeconds > 0) {
      dispensedLiters = _elapsedDuration.inSeconds * litersPerSecond;
    } else if (!_status!.pumpRunning && _elapsedDuration.inSeconds > 0) {
      // Pump stopped - assume all dispensed based on duration
      dispensedLiters = _elapsedDuration.inSeconds * litersPerSecond;
    }
    
    // Clamp to target
    dispensedLiters = dispensedLiters.clamp(0, wantLiters).toDouble();
    
    final progress = wantLiters > 0
        ? ((dispensedLiters / wantLiters) * 100).clamp(0, 100)
        : 0.0;
    
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
                  'Dispensed: ${dispensedLiters.toStringAsFixed(2)} L',
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
