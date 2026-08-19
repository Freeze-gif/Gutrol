import 'package:flutter/foundation.dart';

class AppState {
  static String customerName = '';
  static String licensePlate = '';
  static String selectedFuelType = '';
  static String selectedMode = '';
  static String selectedAmount = '';
  static String liveStatus = 'Request Submitted';
  static double progress = 0.0;
  
  // Order targets for live status calculation
  static double targetLiters = 0.0;
  static double targetMMK = 0.0;
  static double walletBalance = 0.0;
  static List<Map<String, dynamic>> history = [];
  static List<Map<String, dynamic>> walletTransactions = [];
  
  // ESP32 Connection Settings
  static String esp32IpAddress = '10.130.26.120';
  static bool isEsp32Connected = false;

  // Hazard State
  static bool hazardActive = false;
  static final ValueNotifier<bool> hazardNotifier = ValueNotifier<bool>(false);

  static void updateHazardStatus(bool isActive) {
    if (hazardActive != isActive) {
      hazardActive = isActive;
      hazardNotifier.value = isActive;
    }
  }

  static void init() {
    history = [];
  }

  static void clear() {
    customerName = '';
    licensePlate = '';
    selectedFuelType = '';
    selectedMode = '';
    selectedAmount = '';
    liveStatus = 'Request Submitted';
    progress = 0.0;
    targetLiters = 0.0;
    targetMMK = 0.0;
    // Note: We don't clear ESP32 IP or wallet balance to persist them across sessions
    isEsp32Connected = false;
  }

  static void addToHistory(Map<String, dynamic> order) {
    history.insert(0, order);
  }

  static void addWalletTransaction(Map<String, dynamic> transaction) {
    walletTransactions.insert(0, transaction);
  }
  
  /// Set ESP32 IP address
  static void setEsp32Ip(String ip) {
    esp32IpAddress = ip;
  }
  
  /// Check if ESP32 is configured
  static bool get hasEsp32Ip => esp32IpAddress.isNotEmpty;
}
