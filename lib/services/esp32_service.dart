import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/pump_status.dart';
import 'app_state.dart';

/// ESP32 HTTP Service
/// Handles all communication with ESP32 fuel pump controller
class Esp32Service {
  /// Base URL of the pump controller. Derived from [AppState.esp32IpAddress]
  /// so there is a single source of truth for the address - the screens and
  /// the service can never disagree about which ESP32 they are talking to.
  static String get baseUrl => 'http://${AppState.esp32IpAddress}';
  
  // HTTP client with timeout
  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 5);
  
  // Retry configuration
  static const int maxRetries = 2;

  /// Set the ESP32 IP address
  static void setIpAddress(String ip) {
    AppState.setEsp32Ip(ip.trim());
  }

  /// Validate IP address format
  static bool isValidIp(String ip) {
    if (ip.isEmpty) return false;
    
    // Basic IPv4 validation
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip)) return false;
    
    // Check each octet
    final parts = ip.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    
    return true;
  }

  /// Whether an ESP32 address has been configured.
  static bool get isConfigured => AppState.esp32IpAddress.trim().isNotEmpty;

  /// Get full URL for endpoint
  static String _url(String endpoint) {
    return '$baseUrl$endpoint';
  }

  /// GET /status - Get current pump status
  static Future<PumpStatus?> getStatus() async {
    if (!isConfigured) return null;
    
    try {
      final response = await _client
          .get(Uri.parse(_url('/status')))
          .timeout(_timeout);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PumpStatus.fromJson(json);
      } else {
        debugPrint('[ESP32] Status error: ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      debugPrint('[ESP32] Status timeout');
      return null;
    } catch (e) {
      debugPrint('[ESP32] Status error: $e');
      return null;
    }
  }

  /// POST /pump/on - Turn pump on
  static Future<Map<String, dynamic>> pumpOn() async {
    return _postRequest('/pump/on');
  }

  /// POST /pump/off - Turn pump off
  static Future<Map<String, dynamic>> pumpOff() async {
    return _postRequest('/pump/off');
  }

  /// POST /mode?mode=manual - Set manual mode
  static Future<Map<String, dynamic>> setManualMode() async {
    return _postRequest('/mode?mode=manual');
  }

  /// POST /mode?mode=auto - Set auto mode
  static Future<Map<String, dynamic>> setAutoMode() async {
    return _postRequest('/mode?mode=auto');
  }

  /// POST /manual/start?mmk=10000 - Start manual filling
  static Future<Map<String, dynamic>> startManualFilling(double mmk) async {
    return _postRequest('/manual/start?mmk=${mmk.toStringAsFixed(0)}');
  }

  /// POST /auto/start - Start auto filling
  static Future<Map<String, dynamic>> startAutoFilling() async {
    return _postRequest('/auto/start');
  }

  /// POST /fuel/select?type=92 - Select fuel type and control servo
  static Future<Map<String, dynamic>> selectFuelType(String type) async {
    return _postRequest('/fuel/select?type=$type');
  }

  /// POST /emergency/stop - Emergency stop
  static Future<Map<String, dynamic>> emergencyStop() async {
    return _postRequest('/emergency/stop');
  }

  /// POST /servo/on - Turn servo ON (0 degrees)
  static Future<Map<String, dynamic>> servoOn() async {
    return _postRequest('/servo/on');
  }

  /// POST /servo/off - Turn servo OFF (180 degrees)
  static Future<Map<String, dynamic>> servoOff() async {
    return _postRequest('/servo/off');
  }

  /// Generic POST request with retry logic
  static Future<Map<String, dynamic>> _postRequest(String endpoint, {int retry = 0}) async {
    if (!isConfigured) {
      return {'success': false, 'error': 'ESP32 IP not configured'};
    }
    
    try {
      final response = await _client
          .post(Uri.parse(_url(endpoint)))
          .timeout(_timeout);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json;
      } else {
        final error = 'HTTP ${response.statusCode}';
        debugPrint('[ESP32] POST error: $error');
        
        // Retry on server error
        if (response.statusCode >= 500 && retry < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (retry + 1)));
          return await _postRequest(endpoint, retry: retry + 1);
        }
        
        return {'success': false, 'error': error};
      }
    } on TimeoutException {
      debugPrint('[ESP32] POST timeout: $endpoint');
      
      // Retry on timeout
      if (retry < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * (retry + 1)));
        return await _postRequest(endpoint, retry: retry + 1);
      }
      
      return {'success': false, 'error': 'Connection timeout'};
    } catch (e) {
      debugPrint('[ESP32] POST error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Test connection to ESP32
  static Future<bool> testConnection() async {
    if (!isConfigured) return false;
    
    try {
      final response = await _client
          .get(Uri.parse(_url('/status')))
          .timeout(const Duration(seconds: 3));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ESP32] Connection test failed: $e');
      return false;
    }
  }

  /// Dispose resources (call when app closes)
  static void dispose() {
    _client.close();
  }
}
