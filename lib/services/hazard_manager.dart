import 'package:flutter/material.dart';
import 'app_state.dart';
import '../screens/home_screen.dart';

class HazardManager {
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _isHazardDialogOpen = false;
  static bool _isSafeDialogOpen = false;

  static void init(GlobalKey<NavigatorState> navKey) {
    _navigatorKey = navKey;
    AppState.hazardNotifier.addListener(_handleHazardChange);
  }

  static void _handleHazardChange() {
    final bool isHazardActive = AppState.hazardNotifier.value;
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    if (isHazardActive) {
      // If safe dialog is open, close it
      if (_isSafeDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        _isSafeDialogOpen = false;
      }
      _showHazardDialog(context);
    } else {
      // If hazard was active and now is safe
      if (_isHazardDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        _isHazardDialogOpen = false;
        _showSafeDialog(context);
      }
    }
  }

  static void _showHazardDialog(BuildContext context) {
    if (_isHazardDialogOpen) return;

    _isHazardDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.red.shade50,
          icon: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 64),
          title: Text(
            'Hazard Alert',
            style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Gas leak detected. System has stopped for safety.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ).then((_) => _isHazardDialogOpen = false);
  }

  static void _showSafeDialog(BuildContext context) {
    // If hazard dialog is open, close it first
    if (_isHazardDialogOpen) {
      Navigator.of(context).pop();
      _isHazardDialogOpen = false;
    }

    if (_isSafeDialogOpen) return;

    _isSafeDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.green.shade50,
          icon: Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 64),
          title: Text(
            'System Safe',
            style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Gas level is safe now. You can continue using the system.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _isSafeDialogOpen = false;
                  Navigator.of(context, rootNavigator: true).pop();
                  
                  // Navigate to Home
                  _navigatorKey?.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Go to Home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _isSafeDialogOpen = false);
  }
}
