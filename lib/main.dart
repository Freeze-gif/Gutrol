import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/hazard_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(

    options: DefaultFirebaseOptions.currentPlatform,

  );

  runApp(const PetrolCustomerApp());

}



class PetrolCustomerApp extends StatelessWidget {

  const PetrolCustomerApp({super.key});



  @override
  Widget build(BuildContext context) {
    // Initialize Hazard Manager
    HazardManager.init(navigatorKey);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Gutrol',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(

        colorScheme: const ColorScheme.light(

          primary: Color(0xFF1565C0),      // Deep Blue

          onPrimary: Colors.white,          // White on blue

          secondary: Color(0xFFE53935),   // Red accent

          onSecondary: Colors.white,        // White on red

          surface: Colors.white,            // White backgrounds

          onSurface: Color(0xFF1A237E),     // Dark blue text

          error: Color(0xFFD32F2F),         // Red error

          onError: Colors.white,

          background: Color(0xFFE3F2FD),    // Light sky blue background

          onBackground: Color(0xFF1565C0),  // Blue text on light bg

        ),

        useMaterial3: true,

        appBarTheme: const AppBarTheme(

          centerTitle: true,

          elevation: 0,

          backgroundColor: Color(0xFF1565C0), // Deep Blue

          foregroundColor: Colors.white,

        ),

        elevatedButtonTheme: ElevatedButtonThemeData(

          style: ElevatedButton.styleFrom(

            backgroundColor: const Color(0xFF1565C0),

            foregroundColor: Colors.white,

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(12),

            ),

          ),

        ),

        cardTheme: const CardThemeData(

          color: Colors.white,

          elevation: 2,

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.all(Radius.circular(12)),

          ),

        ),

        scaffoldBackgroundColor: const Color(0xFFE3F2FD), // Light sky blue

      ),

      home: const LoginScreen(),

    );

  }

}

