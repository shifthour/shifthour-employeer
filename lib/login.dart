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
      if (mounted) _showErrorMessage('Invalid authentication session');
      return;
    }

    final user = session.user;
    if (user == null) {
      debugPrint('User is null. Preventing navigation.');
      await Supabase.instance.client.auth.signOut();
      if (mounted) _showErrorMessage('No user found in session');
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
        if (mounted) _showErrorMessage('Not an employer account');
        return;
      }

      // Log user data for debugging
      debugPrint('User Data: $userData');

      // Check employer profile and navigate
      if (mounted) {
        await _navigateBasedOnProfile(user);
      }
    } catch (e) {
      debugPrint('Sign-in verification error: $e');
      await Supabase.instance.client.auth.signOut();
      if (mounted) _showErrorMessage('Authentication verification failed');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isGoogleSignInInProgress = false;
        });
      }
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
    if (!mounted) return; // Early return if widget is no longer mounted

    try {
      debugPrint('Checking Employer Profile for Email: ${user.email}');

      final employerData =
          await Supabase.instance.client
              .from('employers')
              .select('id')
              .eq('contact_email', user.email as Object)
              .maybeSingle();

      debugPrint('Employer Data: $employerData');

      // Check if widget is still mounted before proceeding
      if (!mounted) return;

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

      // Only proceed with these operations if the widget is still mounted
      if (mounted) {
        await Supabase.instance.client.auth.signOut();
        _showErrorMessage('Unable to verify employer profile');
      } else {
        debugPrint('Widget unmounted, skipping error display and navigation');
        // Still perform signout even if widget is unmounted
        await Supabase.instance.client.auth.signOut();
      }
    }
  }

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
      // Log the message if widget is not mounted
      debugPrint(
        'Attempted to show error message after widget unmounted: $message',
      );
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
      await Supabase.instance.client.auth.signOut();

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
  void _handleLoginError(dynamic error) {
    debugPrint('Google Sign-In Error: $error');

    // Check if widget is still mounted before updating state
    if (mounted) {
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
    } else {
      debugPrint('Widget unmounted, skipping error UI update');
    }
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
                    builder: (context) => profile.EmployerProfileSetupScreen(),
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

  void dispose() {
    // Clean up controllers and subscriptions
    _emailController.dispose();
    _passwordController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  // Build method - UPDATED FOR RESPONSIVENESS
  @override
  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;

    // Calculate adaptive sizes
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenHeight < 500;

    // Adaptive dimensions
    final logoSize =
        screenHeight *
        (isVerySmallScreen ? 0.10 : (isSmallScreen ? 0.12 : 0.15));
    final buttonHeight = screenHeight * (isVerySmallScreen ? 0.05 : 0.06);
    final inputFieldHeight = screenHeight * (isVerySmallScreen ? 0.05 : 0.06);

    // Text sizes
    final headerTextSize =
        screenHeight *
        (isVerySmallScreen ? 0.03 : (isSmallScreen ? 0.035 : 0.04));
    final normalTextSize =
        screenHeight *
        (isVerySmallScreen ? 0.022 : (isSmallScreen ? 0.024 : 0.026));
    final smallTextSize =
        screenHeight *
        (isVerySmallScreen ? 0.018 : (isSmallScreen ? 0.02 : 0.022));

    // Padding and spacing
    final horizontalPadding = screenWidth * 0.05;
    final cardPadding = screenWidth * (isVerySmallScreen ? 0.03 : 0.04);
    final smallSpacing = screenHeight * 0.006;
    final normalSpacing = screenHeight * 0.012;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      // Add resizeToAvoidBottomInset to prevent keyboard from causing overflow
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          // Add scrolling capability
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: smallSpacing,
            ),
            child: Column(
              children: [
                // Logo section - reduced height on small screens
                SizedBox(
                  height:
                      screenHeight *
                      (isVerySmallScreen
                          ? 0.15
                          : (isSmallScreen ? 0.18 : 0.22)),
                  child: Center(
                    child: Image.asset(
                      'assets/logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.error_outline,
                          size: logoSize * 0.5,
                          color: Colors.red,
                        );
                      },
                    ),
                  ),
                ),

                // Login card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(cardPadding),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2637),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Take only needed space
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header section

                      // Email field
                      Text(
                        'Business Email',
                        style: TextStyle(
                          fontSize: normalTextSize,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: smallSpacing),
                      Container(
                        height: inputFieldHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3142),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _emailController,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: normalTextSize,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'name@company.com',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: smallTextSize,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.03,
                              vertical: screenHeight * 0.01,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: normalSpacing),

                      // Password field
                      Text(
                        'Password',
                        style: TextStyle(
                          fontSize: normalTextSize,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: smallSpacing),
                      Container(
                        height: inputFieldHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3142),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: normalTextSize,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.03,
                              vertical: screenHeight * 0.01,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white70,
                                size: screenHeight * 0.022,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: smallSpacing),

                      // Forgot password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _handleForgotPassword,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size(10, 10),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: smallTextSize,
                              color: Colors.blue.shade400,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: normalSpacing),

                      // Login button
                      _isLoading
                          ? Center(
                            child: SizedBox(
                              width: screenHeight * 0.03,
                              height: screenHeight * 0.03,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                          : GestureDetector(
                            onTap:
                                _isLoading ? null : _handleEmailPasswordLogin,
                            child: Container(
                              height: buttonHeight,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF5B6BF8),
                                    Color(0xFF8B65D9),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                  buttonHeight / 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Login as Employer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalTextSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      SizedBox(height: normalSpacing),

                      // OR divider
                      Center(
                        child: Text(
                          '- OR -',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: smallTextSize,
                          ),
                        ),
                      ),
                      SizedBox(height: normalSpacing),

                      // Google sign-in button
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleGoogleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          minimumSize: Size.fromHeight(buttonHeight),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              buttonHeight / 2,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        icon: Padding(
                          padding: EdgeInsets.only(left: screenWidth * 0.02),
                          child: Image.asset(
                            'assets/google_logo.png',
                            height: buttonHeight * 0.5,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.g_mobiledata,
                                size: buttonHeight * 0.5,
                                color: Colors.blue,
                              );
                            },
                          ),
                        ),
                        label: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: buttonHeight * 0.2,
                          ),
                          child: Text(
                            'Sign in with Google',
                            style: TextStyle(fontSize: smallTextSize),
                          ),
                        ),
                      ),
                      SizedBox(height: normalSpacing),

                      // Sign up text
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: smallTextSize,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const SignUpPage(),
                                  ),
                                );
                              },
                              child: Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: Colors.blue.shade400,
                                  fontWeight: FontWeight.bold,
                                  fontSize: smallTextSize,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Add extra space at the bottom when keyboard is visible
                      SizedBox(
                        height:
                            MediaQuery.of(context).viewInsets.bottom > 0
                                ? 200
                                : 0,
                      ),
                    ],
                  ),
                ),
                // Add some padding at the bottom to ensure scrollability
                SizedBox(height: screenHeight * 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isSmallScreen) {
    return Column(
      children: [
        Center(
          child: Image.asset(
            'assets/logo.png',
            width: isSmallScreen ? 120 : 180,
            height: isSmallScreen ? 120 : 180,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.error_outline,
                size: isSmallScreen ? 40 : 60,
                color: Colors.red,
              );
            },
          ),
        ),
      ],
    );
  }

  // Login Card Widget - UPDATED
  Widget _buildLoginCard(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isSmallScreen ? 12 : 20,
      ), // Reduced padding on small screens
      decoration: BoxDecoration(
        color: const Color(0xFF1E2637),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const SizedBox(height: 12), // Reduced spacing
          _buildEmailField(),
          const SizedBox(height: 8), // Reduced spacing
          _buildPasswordField(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleForgotPassword,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 4), // Reduced padding
              ),
              child: Text(
                'Forgot password?',
                style: TextStyle(fontSize: 14, color: Colors.blue.shade400),
              ),
            ),
          ),
          const SizedBox(height: 4), // Reduced spacing
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : _buildLoginButton(),
          const SizedBox(height: 8), // Reduced spacing
          const Center(
            child: Text('- OR -', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 8), // Reduced spacing
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              minimumSize: Size.fromHeight(
                isSmallScreen ? 40 : 50,
              ), // Smaller height on small screens
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 8,
              ), // Reduced padding
            ),
            icon: Image.asset(
              'assets/google_logo.png',
              height: 20,
            ), // Smaller icon
            label: const Text('Sign in with Google'),
          ),
          const SizedBox(height: 12), // Reduced spacing
          Center(child: _buildSignupText()), // Center the signup text
        ],
      ),
    );
  } // Email Input Field - UPDATED

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Email',
          style: TextStyle(fontSize: 14, color: Colors.white), // Smaller text
        ),
        const SizedBox(height: 4), // Reduced spacing
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
                vertical: 12, // Reduced padding
              ),
            ),
          ),
        ),
      ],
    );
  } // Password Field - UPDATED

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(fontSize: 14, color: Colors.white), // Smaller text
        ),
        const SizedBox(height: 4), // Reduced spacing
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
                vertical: 12, // Reduced padding
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                  size: 20, // Smaller icon
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

  // Login Button - UPDATED
  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleLogin,
      child: Container(
        height: 40, // Smaller height
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
              fontSize: 16, // Smaller text
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Signup Text - UPDATED
  Widget _buildSignupText() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(color: Colors.white70, fontSize: 13), // Smaller text
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
              fontSize: 13, // Smaller text
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
        builder: (context) => profile.EmployerProfileSetupScreen(),
      ),
    );
  }
}
