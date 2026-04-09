import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pump_status.dart';

/// ESP32 HTTP Service
/// Handles all communication with ESP32 fuel pump controller
class Esp32Service {
  // Base URL - will be updated from AppState
  static String baseUrl = '';
  
  // HTTP client with timeout
  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 5);
  
  // Retry configuration
  static const int maxRetries = 2;

  /// Set the ESP32 IP address
  static void setIpAddress(String ip) {
    baseUrl = 'http://$ip';
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

  /// Check if service is configured
  static bool get isConfigured => baseUrl.isNotEmpty;

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
        print('[ESP32] Status error: ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      print('[ESP32] Status timeout');
      return null;
    } catch (e) {
      print('[ESP32] Status error: $e');
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

  /// POST /emergency/stop - Emergency stop
  static Future<Map<String, dynamic>> emergencyStop() async {
    return _postRequest('/emergency/stop');
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
        print('[ESP32] POST error: $error');
        
        // Retry on server error
        if (response.statusCode >= 500 && retry < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (retry + 1)));
          return _postRequest(endpoint, retry: retry + 1);
        }
        
        return {'success': false, 'error': error};
      }
    } on TimeoutException {
      print('[ESP32] POST timeout: $endpoint');
      
      // Retry on timeout
      if (retry < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * (retry + 1)));
        return _postRequest(endpoint, retry: retry + 1);
      }
      
      return {'success': false, 'error': 'Connection timeout'};
    } catch (e) {
      print('[ESP32] POST error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Test connection to ESP32
  static Future<bool> testConnection() async {
    if (!isConfigured) return false;
    
    try {
      final response = await _client
          .get(Uri.parse(_url('/status')))
          .timeout(Duration(seconds: 3));
      
      return response.statusCode == 200;
    } catch (e) {
      print('[ESP32] Connection test failed: $e');
      return false;
    }
  }

  /// Dispose resources (call when app closes)
  static void dispose() {
    _client.close();
  }
}
