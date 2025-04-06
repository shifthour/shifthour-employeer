import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart'; // Add this import
import 'package:shifthour_employeer/Employer/Employee%20%20workers/Eworkers_dashboard.dart';
import 'package:shifthour_employeer/Employer/employeer_profile.dart';
import 'package:shifthour_employeer/Employer/employer_dashboard.dart';
import 'package:shifthour_employeer/Employer/payments/employeer_payments_dashboard.dart';
import 'package:shifthour_employeer/const/auth.dart';
import 'package:shifthour_employeer/login.dart';
import 'package:shifthour_employeer/profile.dart';
import 'package:shifthour_employeer/splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://awpczipxzeurlpmmrzid.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3cGN6aXB4emV1cmxwbW1yemlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyMTU3NzEsImV4cCI6MjA1Nzc5MTc3MX0.ch5Qkouye-qtLeyfxtmbJpl1UoyxlyHYJH1HmnwrAeM',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AuthWrapper(
      child: GetMaterialApp(
        // Change MaterialApp to GetMaterialApp
        title: 'ShiftHour',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFFF0F5FF),
          fontFamily: 'Inter',
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue.shade700,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter Tight',
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        // Set the splash screen as the home widget
        home: const SplashScreen(),
        getPages: [
          GetPage(name: '/login', page: () => const EmployerLoginPage()),
          GetPage(
            name: '/employer_dashboard',
            page: () => const EmployerDashboard(),
          ),
          GetPage(
            name: '/profile_setup',
            page: () => const ProfileSetupScreen(isEmployer: false),
          ),
          GetPage(name: '/workers', page: () => const EmployerWorkersScreen()),
          GetPage(
            name: '/employeer',
            page: () => const EmployerProfileScreen(),
          ),
          GetPage(name: '/payments', page: () => const PaymentsScreen()),
        ],
      ),
    );
  }
}
