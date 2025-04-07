import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:motion_toast/motion_toast.dart';
import 'package:motion_toast/resources/arrays.dart';
import 'package:shifthour_employeer/Employer/employer_dashboard.dart';
import 'package:shifthour_employeer/profile.dart' as profile;
import 'package:shifthour_employeer/signup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployerLoginPage extends StatefulWidget {
  const EmployerLoginPage({Key? key}) : super(key: key);

  @override
  State<EmployerLoginPage> createState() => _EmployerLoginPageState();
}

class _EmployerLoginPageState extends State<EmployerLoginPage> {
  // Form Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State Variables
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleSignInInProgress = false;

  // Authentication Subscription
  StreamSubscription<AuthState>? _authSubscription;

  // Google Sign-In Configuration
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
      'openid',
    ],
    serverClientId:
        '825127993257-6jjq58pk3g3oq3rdshetu72qfirvd6lm.apps.googleusercontent.com',
  );

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  // Set up authentication state listener
  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (event) async {
        if (!mounted) return;

        switch (event.event) {
          case AuthChangeEvent.signedIn:
            await _handleSignedIn(event.session);
            break;
          case AuthChangeEvent.signedOut:
            _handleSignedOut();
            break;
          default:
            break;
        }
      },
      onError: (error) {
        debugPrint('Authentication State Error: $error');
        _showErrorMessage('Authentication error occurred');
      },
    );
  }

  // Handle successful sign-in
  Future<void> _handleSignedIn(Session? session) async {
    debugPrint('Authentication Session Received');

    if (session == null) {
      debugPrint('Session is null. Preventing navigation.');
      await Supabase.instance.client.auth.signOut();
      _showErrorMessage('Invalid authentication session');
      return;
    }

    final user = session.user;
    if (user == null) {
      debugPrint('User is null. Preventing navigation.');
      await Supabase.instance.client.auth.signOut();
      _showErrorMessage('No user found in session');
      return;
    }

    debugPrint('User ID: ${user.id}');
    debugPrint('User Email: ${user.email}');

    try {
      // Verify user is an employer
      final userData = await _validateEmployerUser(user);

      if (userData == null) {
        debugPrint('User validation failed. Not an employer account.');
        await Supabase.instance.client.auth.signOut();
        _showErrorMessage('Not an employer account');
        return;
      }

      // Log user data for debugging
      debugPrint('User Data: $userData');

      // Check employer profile and navigate
      await _navigateBasedOnProfile(user);
    } catch (e) {
      debugPrint('Sign-in verification error: $e');
      await Supabase.instance.client.auth.signOut();
      _showErrorMessage('Authentication verification failed');
    } finally {
      setState(() {
        _isLoading = false;
        _isGoogleSignInInProgress = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _validateEmployerUser(User user) async {
    try {
      debugPrint('Validating User: ${user.id}');

      final userData =
          await Supabase.instance.client
              .from('user')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();

      debugPrint('User Data Query Result: $userData');

      if (userData == null) {
        debugPrint('No user found in database');
        return null;
      }

      if (userData['role'] != 'employer') {
        debugPrint('User role is not employer: ${userData['role']}');
        return null;
      }

      return userData;
    } catch (e) {
      debugPrint('User validation error: $e');
      return null;
    }
  }

  // Navigate based on employer profile
  Future<void> _navigateBasedOnProfile(User user) async {
    try {
      debugPrint('Checking Employer Profile for Email: ${user.email}');

      final employerData =
          await Supabase.instance.client
              .from('employers')
              .select('id')
              .eq('contact_email', user.email as Object)
              .maybeSingle();

      debugPrint('Employer Data: $employerData');

      if (employerData != null) {
        // Employer profile exists, navigate to dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const EmployerDashboard()),
        );
      } else {
        // No profile, prompt for profile setup
        _showProfileSetupPopup();
      }
    } catch (e) {
      debugPrint('Profile navigation error: $e');
      await Supabase.instance.client.auth.signOut();
      _showErrorMessage('Unable to verify employer profile');
    }
  }

  // Handle sign-out
  void _handleSignedOut() {
    setState(() {
      _isLoading = false;
      _isGoogleSignInInProgress = false;
    });
  }

  // Google Sign-In handler
  Future<void> _handleGoogleLogin() async {
    if (_isLoading || _isGoogleSignInInProgress) return;

    setState(() {
      _isLoading = true;
      _isGoogleSignInInProgress = true;
    });

    try {
      // Clear previous Google sign-in
      await _googleSignIn.signOut();
      await Supabase.instance.client.auth.signOut(); // Add this line

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _handleLoginCancellation();
        return;
      }

      debugPrint('Google User Email: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Validate tokens with more logging
      debugPrint('ID Token: ${googleAuth.idToken}');
      debugPrint('Access Token: ${googleAuth.accessToken}');

      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception('Invalid Google authentication tokens');
      }

      // Attempt Supabase sign-in with Google tokens
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      // Additional logging
      debugPrint('Supabase Auth Response: $response');
      debugPrint('Supabase User: ${response.user}');

      // Auth state listener will handle navigation
    } catch (e) {
      debugPrint('Google Sign-In Detailed Error: $e');
      _handleLoginError(e);
    }
  }

  // Handle login cancellation
  void _handleLoginCancellation() {
    setState(() {
      _isLoading = false;
      _isGoogleSignInInProgress = false;
    });
    _showErrorMessage('Google sign-in cancelled');
  }

  // Handle login errors

  // In your login method
  void _handleLoginError(dynamic error) {
    debugPrint('Google Sign-In Error: $error');

    setState(() {
      _isLoading = false;
      _isGoogleSignInInProgress = false;
    });

    String errorMessage = 'Login failed. Please try again.';

    if (error is AuthException) {
      errorMessage = error.message;
    } else if (error is PlatformException) {
      switch (error.code) {
        case 'sign_in_failed':
          errorMessage = 'Google sign-in failed. Please try again.';
          break;
        case 'network_error':
          errorMessage = 'Network error. Check your internet connection.';
          break;
        default:
          errorMessage = 'Unexpected error occurred during sign-in.';
      }
    } else if (error is Exception) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    // Show MotionToast
    MotionToast.error(
      title: const Text(
        'Sign-In Failed',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      description: Text(errorMessage),
      position: MotionToastPosition.top,
      animationType: AnimationType.slideInFromBottom,
    ).show(context);
  }

  // Email and password login handler
  Future<void> _handleEmailPasswordLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Validate inputs
    if (!_validateInputs(email, password)) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) throw Exception('Login failed: No user returned.');

      // User validation and navigation handled by auth state listener
    } on AuthException catch (e) {
      _showErrorMessage(e.message);
    } catch (e) {
      _showErrorMessage('Login failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Input validation
  bool _validateInputs(String email, String password) {
    if (email.isEmpty) {
      _showErrorMessage('Please enter your email');
      return false;
    }

    if (!_isValidEmail(email)) {
      _showErrorMessage('Please enter a valid email address');
      return false;
    }

    if (password.isEmpty) {
      _showErrorMessage('Please enter your password');
      return false;
    }

    return true;
  }

  // Email format validation
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email);
  }

  // Show error message
  void _showErrorMessage(String message) {
    // Check if the widget is still mounted before showing SnackBar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // Optional: Log the message if widget is not mounted
      debugPrint(
        'Attempted to show error message after widget unmounted: $message',
      );
    }
  }

  // Profile setup popup
  void _showProfileSetupPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Complete Employer Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'We need some additional information about your business to create your employer profile.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            profile.ProfileSetupScreen(isEmployer: true),
                  ),
                );
              },
              child: const Text('Continue'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  // Forgot password handler
  void _handleForgotPassword() {
    showDialog(
      context: context,
      builder: (context) {
        final resetEmailController = TextEditingController();
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: resetEmailController,
            decoration: const InputDecoration(
              hintText: 'Enter your email',
              labelText: 'Email',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (_isValidEmail(email)) {
                  try {
                    await Supabase.instance.client.auth.resetPasswordForEmail(
                      email,
                      redirectTo:
                          'your-app-deep-link-here', // Replace with your app's password reset deep link
                    );
                    Navigator.of(context).pop();
                    _showErrorMessage('Password reset link sent to $email');
                  } catch (e) {
                    _showErrorMessage(
                      'Failed to send reset link: ${e.toString()}',
                    );
                  }
                } else {
                  _showErrorMessage('Please enter a valid email');
                }
              },
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // Clean up controllers and subscriptions
    _emailController.dispose();
    _passwordController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  // Build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 32),
              _buildLogo(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildLoginCard(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Logo Widget
  Widget _buildLogo() {
    return Column(
      children: [
        Center(
          child: Image.asset(
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
        ),
        const SizedBox(height: 10),
        const Text(
          'ShiftHour for Employers',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2637),
          ),
        ),
      ],
    );
  }

  // Login Card Widget
  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2637),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employer Login',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Log in to manage your workforce',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          _buildEmailField(),
          const SizedBox(height: 16),
          _buildPasswordField(),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : _buildLoginButton(),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _handleGoogleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            icon: Image.asset('assets/google_logo.png', height: 24),
            label: const Text('Sign in with Google'),
          ),
          const SizedBox(height: 16),
          _buildSignupText(),
        ],
      ),
    );
  }

  // Email Input Field

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Email',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A3142),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'name@company.com',
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Password',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            GestureDetector(
              onTap: () {
                // Handle "Forgot password"
              },
              child: Text(
                'Forgot password?',
                style: TextStyle(fontSize: 16, color: Colors.blue.shade400),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A3142),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _handleLogin,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B6BF8), Color(0xFF8B65D9)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Center(
          child: Text(
            'Login as Employer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an employer account? ",
          style: TextStyle(color: Colors.white70),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => const SignUpPage()));
          },
          child: Text(
            "Sign Up",
            style: TextStyle(
              color: Colors.blue.shade400,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorMessage('Please enter both email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) throw Exception('Login failed: No user returned.');

      // Check if user is an employer
      final userData =
          await Supabase.instance.client
              .from('user')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();

      if (userData == null) {
        throw Exception('User not found in user table.');
      }

      final isEmployer = userData['role'] == 'employer';
      if (!isEmployer) {
        throw Exception('This account is not registered as an employer.');
      }

      // Check if employer has a profile set up
      final employerData =
          await Supabase.instance.client
              .from('employers')
              .select('id')
              .eq('contact_email', email)
              .maybeSingle();

      if (employerData != null) {
        _navigateToDashboard();
      } else {
        _showProfileSetupPopup();
      }
    } on AuthException catch (e) {
      _showErrorMessage('Login error: ${e.message}');
    } catch (e) {
      _showErrorMessage('Login failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const EmployerDashboard()),
    );
  }

  void _navigateToProfileSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => profile.ProfileSetupScreen(isEmployer: true),
      ),
    );
  }
}
