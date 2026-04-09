/// Pump Status Model
/// Represents the status data returned from ESP32 /status endpoint
class PumpStatus {
  final bool pumpRunning;
  final bool waitingToStartPump;
  final bool autoMode;
  final double remainingLiters;
  final double remainingMMK;
  final double wantMMK;
  final double wantLiters;
  final int pumpRunTimeMs;
  final String currentStatus;
  final double tankLiters;
  final double tankMMK;
  final bool emergencyStop;

  PumpStatus({
    required this.pumpRunning,
    required this.waitingToStartPump,
    required this.autoMode,
    required this.remainingLiters,
    required this.remainingMMK,
    required this.wantMMK,
    required this.wantLiters,
    required this.pumpRunTimeMs,
    required this.currentStatus,
    required this.tankLiters,
    required this.tankMMK,
    required this.emergencyStop,
  });

  /// Create PumpStatus from ESP32 JSON response
  factory PumpStatus.fromJson(Map<String, dynamic> json) {
    return PumpStatus(
      pumpRunning: json['pumpRunning'] ?? false,
      waitingToStartPump: json['waitingToStartPump'] ?? false,
      autoMode: json['autoMode'] ?? false,
      remainingLiters: (json['remainingLiters'] ?? 0).toDouble(),
      remainingMMK: (json['remainingMMK'] ?? 0).toDouble(),
      wantMMK: (json['wantMMK'] ?? 0).toDouble(),
      wantLiters: (json['wantLiters'] ?? 0).toDouble(),
      pumpRunTimeMs: json['pumpRunTimeMs'] ?? 0,
      currentStatus: json['currentStatus'] ?? 'Unknown',
      tankLiters: (json['tankLiters'] ?? 0).toDouble(),
      tankMMK: (json['tankMMK'] ?? 0).toDouble(),
      emergencyStop: json['emergencyStop'] ?? false,
    );
  }

  /// Convert to JSON for debugging
  Map<String, dynamic> toJson() {
    return {
      'pumpRunning': pumpRunning,
      'waitingToStartPump': waitingToStartPump,
      'autoMode': autoMode,
      'remainingLiters': remainingLiters,
      'remainingMMK': remainingMMK,
      'wantMMK': wantMMK,
      'wantLiters': wantLiters,
      'pumpRunTimeMs': pumpRunTimeMs,
      'currentStatus': currentStatus,
      'tankLiters': tankLiters,
      'tankMMK': tankMMK,
      'emergencyStop': emergencyStop,
    };
  }

  /// Get progress percentage (0-100) based on remaining vs total
  int get progressPercent {
    if (wantLiters <= 0) return 0;
    double dispensed = wantLiters - remainingLiters;
    return ((dispensed / wantLiters) * 100).clamp(0, 100).round();
  }

  /// Get status color based on current status
  String get statusDescription {
    switch (currentStatus.toLowerCase()) {
      case 'ready':
        return 'System Ready';
      case 'confirmed':
        return 'Order Confirmed';
      case 'running':
        return pumpRunning ? 'Pumping Fuel...' : 'Ready to Pump';
      case 'completed':
        return 'Fueling Completed';
      case 'emergency stop':
        return 'EMERGENCY STOP!';
      case 'error':
        return 'System Error';
      default:
        return currentStatus;
    }
  }

  @override
  String toString() {
    return 'PumpStatus{status: $currentStatus, pump: $pumpRunning, mode: ${autoMode ? "Auto" : "Manual"}, remaining: $remainingLiters L / $remainingMMK MMK}';
  }
}
