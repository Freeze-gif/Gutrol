class AppState {
  static String customerName = '';
  static String licensePlate = '';
  static String selectedFuelType = '';
  static String selectedMode = '';
  static String selectedAmount = '';
  static String liveStatus = 'Request Submitted';
  static double progress = 0.0;
  static List<Map<String, dynamic>> history = [];
  
  // ESP32 Connection Settings
  static String esp32IpAddress = '';
  static bool isEsp32Connected = false;

  static void init() {
    history = [
      {
        'fuelType': 'Petrol 92',
        'mode': 'Auto Filling',
        'amount': '20 Liters',
        'date': '2024-03-15 10:30 AM',
        'status': 'Completed',
      },
      {
        'fuelType': 'Diesel',
        'mode': 'Manual Filling',
        'amount': '5000 MMK',
        'date': '2024-03-10 14:45 PM',
        'status': 'Completed',
      },
      {
        'fuelType': 'Petrol 95',
        'mode': 'Auto Filling',
        'amount': '30 Liters',
        'date': '2024-02-28 09:15 AM',
        'status': 'Completed',
      },
    ];
  }

  static void clear() {
    customerName = '';
    licensePlate = '';
    selectedFuelType = '';
    selectedMode = '';
    selectedAmount = '';
    liveStatus = 'Request Submitted';
    progress = 0.0;
    // Note: We don't clear ESP32 IP to persist it across sessions
    isEsp32Connected = false;
  }

  static void addToHistory(Map<String, dynamic> order) {
    history.insert(0, order);
  }
  
  /// Set ESP32 IP address
  static void setEsp32Ip(String ip) {
    esp32IpAddress = ip;
  }
  
  /// Check if ESP32 is configured
  static bool get hasEsp32Ip => esp32IpAddress.isNotEmpty;
}
