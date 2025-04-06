import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Add a small delay to show the splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if user is logged in
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      // User is logged in, check their role to determine which dashboard to show
      try {
        final userData =
            await Supabase.instance.client
                .from('user')
                .select('role')
                .eq('user_id', user.id)
                .maybeSingle();

        if (!mounted) return;

        if (userData != null) {
          final isEmployer = userData['role'] == 'employer';

          // Navigate to the appropriate dashboard
          Navigator.of(context).pushReplacementNamed(
            isEmployer ? '/employer_dashboard' : '/worker_dashboard',
          );
        } else {
          // User exists in auth but not in our database, send to login
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } catch (e) {
        print('Error checking user role: $e');
        // If there's an error, redirect to login to be safe
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } else {
      // No user is logged in, send to login screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/logo.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red,
                );
              },
            ),
            const SizedBox(height: 20),
            // App name with gradient text
            ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [Colors.blue.shade600, Colors.indigo.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
              child: const Text(
                'ShiftHour',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 50),
            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
