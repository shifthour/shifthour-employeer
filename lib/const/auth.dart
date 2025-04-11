import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  late StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Register this object as an observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Subscribe to auth state changes
    _setupAuthListener();

    // Check auth state when the widget is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthState();
    });
  }

  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (event) async {
        if (event.event == AuthChangeEvent.signedOut) {
          // Explicitly redirect to login on signOut
          _clearLocalSession();
          Get.offAllNamed('/login');
        } else if (event.event == AuthChangeEvent.signedIn) {
          await _checkUserRole();
        }
      },
      onError: (error) {
        debugPrint('Authentication State Error: $error');
        // Redirect to login on auth errors
        Get.offAllNamed('/login');
      },
    );
  }

  @override
  void dispose() {
    // Cancel the auth subscription
    _authSubscription.cancel();
    // Remove the observer when this widget is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App was resumed from background - check auth state
      _checkAuthState();
    }
  }

  Future<void> _clearLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('supabase_session');
    } catch (e) {
      debugPrint('Error clearing local session: $e');
    }
  }

  Future<void> _checkAuthState() async {
    try {
      // Check for valid session
      final session = await Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;

      // If session is null, expired, or user is null, logout and redirect
      if (session == null || session.isExpired || user == null) {
        await Supabase.instance.client.auth.signOut();
        await _clearLocalSession();
        Get.offAllNamed('/login');
        return;
      }

      // User is logged in with valid session, check their role
      await _checkUserRole();
    } catch (e) {
      debugPrint('Error checking auth state: $e');
      // On error, go to login for safety
      Get.offAllNamed('/login');
    }
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Get.offAllNamed('/login');
      return;
    }

    try {
      final userData =
          await Supabase.instance.client
              .from('user')
              .select('role')
              .eq('user_id', user.id)
              .maybeSingle();

      // If userData is null, the user's row might have been deleted
      if (userData == null) {
        // Sign out the user as their profile is incomplete
        await Supabase.instance.client.auth.signOut();
        await _clearLocalSession();
        Get.offAllNamed('/login');
        return;
      }

      // Check the current route name
      final currentRoute = Get.currentRoute;
      final isEmployer = userData['role'] == 'employer';
      final targetRoute =
          isEmployer ? '/employer_dashboard' : '/worker_dashboard';

      // If user is on the login route or a route that doesn't match their role, redirect them
      if (currentRoute == '/login' ||
          (currentRoute != targetRoute && currentRoute != '/profile_setup')) {
        Get.offAllNamed(targetRoute);
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
      // On error, go to login for safety
      await Supabase.instance.client.auth.signOut();
      await _clearLocalSession();
      Get.offAllNamed('/login');
    }
  }

  // Static method to handle logout from anywhere in the app
  static Future<void> logout() async {
    try {
      // Show loading indicator
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // Perform logout
      await Supabase.instance.client.auth.signOut();

      // Clear local session
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('supabase_session');

      // Navigate to login
      if (Get.isDialogOpen!) {
        Get.back(); // Close loading dialog
      }
      Get.offAllNamed('/login');
    } catch (e) {
      debugPrint('Logout error: $e');
      // Still try to navigate to login
      Get.offAllNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
