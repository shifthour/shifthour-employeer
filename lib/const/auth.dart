import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Register this object as an observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Check auth state when the widget is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthState();
    });
  }

  @override
  void dispose() {
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

  Future<void> _checkAuthState() async {
    // Check if user is logged in
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      // If user is not logged in, go to login page
      Get.offNamed('/login');
      return;
    }

    // User is logged in, check their role
    try {
      final userData =
          await Supabase.instance.client
              .from('user')
              .select('role')
              .eq('user_id', user.id)
              .maybeSingle();

      // If userData is null, the user's row might have been deleted
      if (userData == null) {
        // Navigate to login as their profile is incomplete
        Get.offNamed('/login');
        return;
      }

      // Check the current route name
      final currentRoute = Get.currentRoute;
      final isEmployer = userData['role'] == 'employer';
      final targetRoute =
          isEmployer ? '/employer_dashboard' : '/worker_dashboard';

      // If user is on a route that doesn't match their role, redirect them
      if (currentRoute != targetRoute) {
        Get.offNamed(targetRoute);
      }
    } catch (e) {
      print('Error checking user role: $e');
      // On error, go to login for safety
      Get.offNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
