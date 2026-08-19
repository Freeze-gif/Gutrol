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
  /// Default address of the pump controller. Changed at runtime from the
  /// Live Status screen when the ESP32 gets a different DHCP lease.
  static const String defaultEsp32Ip = '10.247.47.79';
  static String esp32IpAddress = defaultEsp32Ip;
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

  /// Clear per-order state. Keeps the signed-in user's wallet and history.
  static void clear() {
    selectedFuelType = '';
    selectedMode = '';
    selectedAmount = '';
    liveStatus = 'Request Submitted';
    progress = 0.0;
    targetLiters = 0.0;
    targetMMK = 0.0;
    // Note: the ESP32 IP is a device setting, not user data, so it is kept.
    isEsp32Connected = false;
  }

  /// Clear everything tied to the signed-in account. Must be called on logout
  /// so the next user never sees (or spends) the previous user's balance.
  static void clearUserData() {
    clear();
    customerName = '';
    licensePlate = '';
    walletBalance = 0.0;
    walletTransactions = [];
    history = [];
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
