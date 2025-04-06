import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  bool _obscurePassword = true;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isGoogleSignIn = false;
  bool _justInitialized = true; // Flag to track initial page load

  // Stream subscription for auth state changes
  StreamSubscription<AuthState>? _authSubscription;

  // Update your GoogleSignIn initialization
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
      'openid', // This scope is required for ID tokens
    ],
    serverClientId:
        '825127993257-6jjq58pk3g3oq3rdshetu72qfirvd6lm.apps.googleusercontent.com',
  );

  @override
  void dispose() {
    // Cancel the auth subscription to prevent memory leaks
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Check if user is already signed in when the page first loads
    final currentUser = Supabase.instance.client.auth.currentUser;
    // Only set _justInitialized to true if there actually is a current user
    _justInitialized = currentUser != null;

    // Listen for auth state changes
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) async {
      if (!mounted) return;

      if (state.event == AuthChangeEvent.signedIn) {
        if (mounted) {
          setState(() => _isLoading = false);
        }

        // Skip navigation if this is the initial load with an already signed-in user
        // BUT don't skip if this is an actual new sign-in event (like Google auth)
        if (_justInitialized) {
          _justInitialized = false; // Reset the flag
          // Only return/skip if this is truly the initial app load, not a fresh sign-in
          if (!_isGoogleSignIn) {
            return;
          }
        }

        final user = state.session?.user;
        if (user != null) {
          // Only show toast if sign-in came from Google
          if (_isGoogleSignIn) {
            if (mounted) {
              _showGoogleSignInSuccessToast(user.email ?? 'your account');
            }
            _isGoogleSignIn = false; // Reset the flag

            // Add a delay to ensure toast is visible before navigation
            await Future.delayed(const Duration(seconds: 1));

            // Check if widget is still mounted after delay
            if (!mounted) return;
          }

          // Check user profile and navigate
          if (mounted) {
            await _checkEmployerProfileAndNavigate(user);
          }
        }
      }
    });
  }

  Future<void> _checkEmployerProfileAndNavigate(User user) async {
    if (!mounted) return;

    try {
      final email = user.email;
      if (email == null || email.isEmpty) {
        if (mounted) {
          _showErrorMessage('Email address not available from authentication');
        }
        return;
      }

      // First check if user exists by email and is an employer
      final userData =
          await Supabase.instance.client
              .from('user')
              .select()
              .eq('email', email)
              .maybeSingle();

      if (!mounted) return;

      if (userData == null) {
        // User authenticated but doesn't have an entry in our user table
        // Direct them to signup to collect necessary information
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SignUpPage()),
        );
        return;
      }

      // Verify user is an employer
      final isEmployer = userData['role'] == 'employer';
      if (!isEmployer) {
        _showErrorMessage('This account is not registered as an employer');
        return;
      }

      // Check if employer has a profile
      final profileData =
          await Supabase.instance.client
              .from('employers')
              .select('id')
              .eq('contact_email', email)
              .maybeSingle();

      if (!mounted) return;

      if (profileData != null) {
        // Employer has a profile, go to dashboard
        _navigateToDashboard();
      } else {
        // Employer has account but no profile, show profile setup
        _showProfileSetupPopup();
      }

      // Optionally update the user_id if it doesn't match
      if (userData['user_id'] != user.id) {
        await Supabase.instance.client
            .from('user')
            .update({'user_id': user.id})
            .eq('email', email);
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Error checking profile: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 32), // Top spacing
              _buildLogo(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildLoginCard(),
              ),
              const SizedBox(height: 32), // Bottom spacing
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
    if (!mounted) return;

    try {
      print("Starting Google Sign-In process");
      setState(() {
        _isLoading = true;
      });

      // Check if user is already signed in to Google and sign out
      final isSignedIn = await _googleSignIn.isSignedIn();
      print("Is already signed in to Google: $isSignedIn");
      if (isSignedIn) {
        await _googleSignIn.signOut();
        print("Signed out from previous Google session");
      }

      // Show the account picker and get selected account
      print("Showing Google account picker");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print(
        "Google account picker result: ${googleUser != null ? 'Account selected' : 'Cancelled'}",
      );

      // User canceled the sign-in flow
      if (googleUser == null) {
        print("User cancelled Google Sign-In");
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      print("Google user email: ${googleUser.email}");
      print("Google user display name: ${googleUser.displayName}");
      print("Google user ID: ${googleUser.id}");

      if (mounted) {
        setState(() {
          _isGoogleSignIn = true;
        });
      }

      // Get authentication details from Google
      print("Getting Google authentication tokens");
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print("ID token available: ${googleAuth.idToken != null}");
      print("Access token available: ${googleAuth.accessToken != null}");

      if (googleAuth.idToken == null) {
        print("ERROR: ID token is null!");
        throw Exception('Failed to get ID token from Google');
      }

      // Sign in to Supabase with Google token
      print("Attempting to sign in to Supabase with Google tokens");
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      print("Supabase auth response received");

      // Check if sign-in was successful
      final user = response.user;
      if (user == null) {
        print("ERROR: Supabase returned null user after Google sign-in");
        throw Exception('Google sign-in failed: No user returned');
      }

      print("Successfully signed in to Supabase as: ${user.email}");

      // The auth state listener will handle the success toast and navigation
      // We don't need to do anything else here
    } catch (e) {
      print("Google sign-in error: $e");
      print("Stack trace: ${StackTrace.current}");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isGoogleSignIn = false;
        });
        _showErrorMessage('Google sign-in failed: ${e.toString()}');
      }
    }
  }

  void _showGoogleSignInSuccessToast(String email) {
    // First check if widget is still mounted
    if (!mounted) return;

    // Use ScaffoldMessenger which is safer for navigation scenarios
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Image.asset('assets/google_logo.png', width: 24, height: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sign-in Successful',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Successfully signed in as $email',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blueGrey[800],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

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
              ? const Center(child: CircularProgressIndicator())
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

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const EmployerDashboard()),
    );
  }

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
            'We need some information about your business to create your employer profile.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToProfileSetup();
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

  void _navigateToProfileSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => profile.ProfileSetupScreen(isEmployer: true),
      ),
    );
  }
}
