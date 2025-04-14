import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:shifthour_employeer/Employer/Business%20Kyc/kyc.dart';
import 'package:shifthour_employeer/Employer/Employee%20%20workers/Eworkers_dashboard.dart';
import 'package:shifthour_employeer/Employer/Manage%20Jobs/manage_jobs_dashboard.dart';
import 'package:shifthour_employeer/Employer/payments/payments.model.dart';
import 'package:shifthour_employeer/const/Bottom_Navigation.dart'
    show NavigationController, NavigationMixin, ShiftHourBottomNavigation;
import 'package:shifthour_employeer/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployerDashboard extends StatefulWidget {
  const EmployerDashboard({Key? key}) : super(key: key);

  @override
  State<EmployerDashboard> createState() => _EmployerDashboardState();
}

class _EmployerDashboardState extends State<EmployerDashboard> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isBusinessVerified = false;

  bool _isLoading = true;
  String _userName = "";
  String _usercompany = "";
  String _contactemail = "";
  int _totalShifts = 0;
  int _activeWorkers = 0;
  @override
  void initState() {
    super.initState();
    // Set current tab to Dashboard (index 0) when this page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get the navigation controller and set index without triggering navigation
      final controller = Get.find<NavigationController>();
      controller.currentIndex.value = 0;

      // Load employer data
      _loadUserData();
      _loadProfileData();
      _loadkyc();
    });
  }

  Future<String> _calculateTotalHoursTracked() async {
    try {
      // Get current user's ID
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user currently logged in');
      }
      final userId = currentUser.id;

      // Fetch shift IDs posted by current user
      final shiftIds = await Supabase.instance.client
          .from('worker_job_listings')
          .select('shift_id')
          .eq('user_id', userId);

      // Extract shift IDs into a list, handling null values
      final shiftIdList =
          shiftIds
              .map((e) => e['shift_id'] as String?)
              .where((id) => id != null)
              .toList();

      // Build the 'or' query for attendance records
      final attendanceQuery = shiftIdList
          .map((shiftId) {
            return 'shift_id.eq.$shiftId';
          })
          .join(',');

      // Fetch attendance records for those shift IDs
      final attendanceRecords = await Supabase.instance.client
          .from('worker_attendance')
          .select()
          .or(attendanceQuery);

      // Calculate total minutes
      int totalMinutes = 0;

      attendanceRecords.forEach((record) {
        final checkInTime = record['check_in_time'] as String?;
        final checkOutTime = record['check_out_time'] as String?;

        if (checkInTime != null && checkOutTime != null) {
          final checkIn = DateTime.parse(checkInTime);
          final checkOut = DateTime.parse(checkOutTime);
          final durationMinutes = checkOut.difference(checkIn).inMinutes;
          totalMinutes += durationMinutes;
        }
      });
      // Format total duration
      final durationHours = totalMinutes ~/ 60;
      final remainingMinutes = totalMinutes % 60;
      return '$durationHours hr $remainingMinutes ms';
    } catch (e) {
      print('Error calculating total hours tracked: $e');
      return '0 hours 0 minutes';
    }
  }

  final PaymentsController _paymentsController = Get.put(PaymentsController());
  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not logged in or email not available');
      }

      final email = user.email!;

      try {
        // Fetch total shifts count from worker_job_listings
        final totalShiftsResponse =
            await Supabase.instance.client
                .from('worker_job_listings')
                .select()
                .eq('user_id', user.id)
                .count();

        // Fetch active workers count by joining worker_job_listings and worker_job_applications
        final activeWorkersResponse =
            await Supabase.instance.client
                .from('worker_job_listings')
                .select('worker_job_applications!inner(*)')
                .eq('user_id', user.id)
                .eq('worker_job_applications.application_status', 'In Progress')
                .count();

        if (mounted) {
          setState(() {
            _totalShifts = totalShiftsResponse.count ?? 0;
            _activeWorkers = activeWorkersResponse.count ?? 0;
          });
        }
      } catch (e) {
        print('ERROR: $e');
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadProfileData() async {
    try {
      setState(() => _isLoading = true);

      // Get current user's email
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not logged in or email not available');
      }

      final email = user.email!;

      try {
        // Check what data exists in job_seekers table
        // Change this line
        final response =
            await Supabase.instance.client
                .from('employers')
                .select('*')
                .eq(
                  'contact_email',
                  email,
                ) // Changed from 'email' to 'contact_email'
                .single();

        // Log all key-value pairs
        print('DEBUG: JOB SEEKER DATA:');
        response.forEach((key, value) {
          print('$key: $value');
        });

        // Then update state with confirmed field name
        setState(() {
          // _isBusinessVerified = response['is_verified'] ?? false;
          // Make sure you use the exact field name from the output above
          _userName = response['contact_name'] ?? 'Employer';
          _usercompany =
              response['company_name']; // Make sure 'contact_name' is exactly as in DB
          _contactemail =
              response['contact_email']; // Make sure 'contact_email' is exactly as in DB
        });
      } catch (e) {
        print('ERROR: $e');
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Keep default values
    } finally {
      // setState(() => _isLoading = false);
    }
  }

  Future<void> _loadkyc() async {
    try {
      setState(() => _isLoading = true);

      // Get current user's email
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not logged in or email not available');
      }

      final email = user.email!;

      try {
        // Use .select() without .single() to handle no rows
        final response =
            await Supabase.instance.client
                .from('business_verifications')
                .select('*')
                .eq('email', email)
                .maybeSingle(); // Use maybeSingle instead of single

        // Check if response is null
        if (response == null) {
          print('No verification record found for email: $email');
          setState(() {
            _isBusinessVerified = false;
          });
          return;
        }

        // Log all key-value pairs
        print('DEBUG: BUSINESS VERIFICATION DATA:');
        response.forEach((key, value) {
          print('$key: $value');
        });

        // Update state with verification status
        setState(() {
          _isBusinessVerified = response['is_verified'] ?? false;
        });
      } catch (e) {
        print('ERROR in _loadkyc: $e');
        setState(() {
          _isBusinessVerified = false;
        });
      }
    } catch (e) {
      print('Error loading KYC data: $e');
      setState(() {
        _isBusinessVerified = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRecentActivities() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final activitiesResponse = await Supabase.instance.client
          .from('recent_activities')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(4);

      return activitiesResponse;
    } catch (e) {
      print('Error fetching recent activities: $e');
      return [];
    }
  }

  Widget _buildRecentActivitySection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchRecentActivities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No recent activities',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                blurRadius: 4,
                color: const Color(0x10000000),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontFamily: 'Inter Tight',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to full activity log
                      },
                      child: Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...snapshot.data!
                    .map(
                      (activity) => _buildActivityItem(
                        context,
                        icon: _getActivityIcon(activity['activity_type']),
                        iconBackgroundColor: _getActivityBackgroundColor(
                          activity['activity_type'],
                        ),
                        iconColor: _getActivityIconColor(
                          activity['activity_type'],
                        ),
                        title: activity['title'],
                        description: activity['description'],
                        timeAgo: _formatTimeAgo(activity['created_at']),
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getActivityIcon(String activityType) {
    switch (activityType) {
      case 'job_posted':
        return Icons.work_outline;
      case 'worker_assigned':
        return Icons.person_add_outlined;
      case 'check_in':
        return Icons.login_rounded;
      case 'check_out':
        return Icons.logout_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getActivityBackgroundColor(String activityType) {
    switch (activityType) {
      case 'job_posted':
        return Color(0xFFE6EEFF);
      case 'worker_assigned':
        return Color(0xFFFFF1E6);
      case 'check_in':
        return Color(0xFFE0F8F3);
      case 'check_out':
        return Color(0xFFFEF0E6);
      default:
        return Color(0xFFF5F5F5);
    }
  }

  Color _getActivityIconColor(String activityType) {
    switch (activityType) {
      case 'job_posted':
        return Color(0xFF5B6BF8);
      case 'worker_assigned':
        return Colors.orange;
      case 'check_in':
        return Colors.teal;
      case 'check_out':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  String _formatTimeAgo(String timestamp) {
    final DateTime dateTime = DateTime.parse(timestamp);
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _openBusinessVerificationForm() {
    // Show the form as a full-screen dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: StandaloneVerificationForm(
              onComplete: () {
                // After verification, refresh the data to update the UI
                _loadProfileData();
                _loadUserData();
              },
            ),
          ),
        );
      },
    );
  }

  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF0F5FF),
        // Add drawer to the scaffold
        drawer: _buildDrawer(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 70, // Taller app bar for more pronounced curve
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.indigo.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 24),
            onPressed: () {
              scaffoldKey.currentState?.openDrawer();
            },
          ),
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const SizedBox(
                width: 8,
              ), // Add some spacing between the icon and text
              const Text(
                'ShiftHour',
                style: TextStyle(
                  fontFamily: 'Inter Tight',
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                print('Notifications pressed');
              },
            ),
            const SizedBox(width: 8),
          ],
        ),

        // Add app bar with menu icon
        bottomNavigationBar: const ShiftHourBottomNavigation(),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Header
              // Verification Alert
              if (_isLoading)
                const SizedBox.shrink() // or CircularProgressIndicator()
              else if (!_isBusinessVerified)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber.shade800,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Your business verification is incomplete',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _openBusinessVerificationForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.amber.shade800,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              minimumSize: const Size(0, 36),
                            ),
                            child: const Text(
                              'Complete Now',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Main Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dashboard Overview',
                          style: TextStyle(
                            fontFamily: 'Inter Tight',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // First Row of Stats
                        Row(
                          children: [
                            // Total Jobs
                            Expanded(
                              child: _buildStatCard(
                                context,
                                icon: Icons.work_rounded,
                                iconColor: const Color(0xFF5B6BF8),
                                value: '$_totalShifts',
                                label: 'Total Shifts',
                                growthValue: '+10%',
                                growthColor: const Color(0xFF5B6BF8),
                              ),
                            ),

                            const SizedBox(width: 16),
                            // Active Workers
                            Expanded(
                              child: _buildStatCard(
                                context,
                                icon: Icons.people_rounded,
                                iconColor: Colors.teal,
                                value: '$_activeWorkers',
                                label: 'Active Workers',
                                growthValue: '+12%',
                                growthColor: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Second Row of Stats
                        Row(
                          children: [
                            // Hours Tracked
                            Expanded(
                              child: FutureBuilder<String>(
                                future: _calculateTotalHoursTracked(),
                                builder: (context, snapshot) {
                                  final hoursTracked =
                                      snapshot.hasData
                                          ? snapshot.data
                                          : '0 hours 0 minutes';
                                  return _buildStatCard(
                                    context,
                                    icon: Icons.timer_rounded,
                                    iconColor: Colors.orange,
                                    value: hoursTracked,
                                    label: 'Hours Tracked',
                                    growthValue: '+19%',
                                    growthColor: Colors.orange,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Pending Payments
                            Expanded(
                              child: _buildStatCard(
                                context,
                                icon: Icons.payments_rounded,
                                iconColor: Colors.green,
                                value:
                                    _paymentsController
                                        .getFormattedWalletBalance(), // Use this method
                                label: 'Wallet',
                                growthValue: '+7%',
                                growthColor: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildRecentActivitySection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Navigation
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.lightBlueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          image: const DecorationImage(
                            fit: BoxFit.cover,
                            image: NetworkImage(
                              'https://source.unsplash.com/200x200/?portrait,woman',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName, // Changed from 'Sarah Johnson' to use the loaded variable
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Business Owner',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.business, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _usercompany,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.dashboard_rounded,
              title: 'Dashboard',
              isSelected: true,
              onTap: () {
                Get.back(); // Close the drawer
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.work_outline_rounded,
              title: 'Shifts',
              onTap: () {
                Get.back();
                Get.to(() => Manage_Jobs_HomePage());
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.people_outline_rounded,
              title: 'Workers',
              onTap: () {
                // Close the drawer first
                Get.back(); // This closes the drawer

                // OR
                Get.toNamed('/workers'); // Direct navigation to the screen
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.payments_outlined,
              title: 'Payments',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                // Navigate to payments page
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.person_outline,
              title: 'Company Profile',
              onTap: () {
                Get.back(); // This closes the drawer

                // OR
                Get.toNamed('/employeer'); // Close the drawer
                // Navigate to profile page
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                // Navigate to settings page
              },
            ),
            const Divider(thickness: 1),
            _buildDrawerItem(
              context,
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                // Navigate to help page
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.logout,
              title: 'Logout',
              onTap: () {
                // Show confirmation dialog
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close dialog
                          },
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop(); // Close dialog

                            try {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (BuildContext dialogContext) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              );

                              // Clear Supabase session
                              await Supabase.instance.client.auth.signOut();

                              // Clear any local storage if needed
                              // final prefs = await SharedPreferences.getInstance();
                              //await prefs.remove('supabase_session');

                              // Store the context in a local variable to check if it's still mounted
                              final scaffoldContext = context;

                              // Check if context is still valid before using Navigator
                              if (Navigator.canPop(context)) {
                                Navigator.of(
                                  context,
                                ).pop(); // Close loading indicator

                                // Navigate to login screen
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => const EmployerLoginPage(),
                                  ),
                                  (Route<dynamic> route) => false,
                                );
                              }
                            } catch (e) {
                              // Handle any errors
                              print('Logout error: $e');

                              // Check if context is still valid before showing SnackBar
                              if (context.mounted) {
                                Navigator.of(
                                  context,
                                ).pop(); // Close loading indicator
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error during logout: $e'),
                                  ),
                                );
                              }
                            } catch (e) {
                              // Handle any errors
                              Navigator.of(
                                context,
                              ).pop(); // Close loading indicator
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error during logout: $e'),
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build drawer items
  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF5B6BF8) : Colors.grey.shade700,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? const Color(0xFF5B6BF8) : Colors.grey.shade800,
        ),
      ),
      onTap: onTap,
      tileColor: isSelected ? const Color(0xFFEEF1FF) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: () {
        print('₹label tab pressed');
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF5B6BF8) : Colors.grey.shade600,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color:
                  isSelected ? const Color(0xFF5B6BF8) : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods to build UI components
  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    String? value,
    required String label,
    required String growthValue,
    required Color growthColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            color: const Color(0x10000000),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: growthColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    growthValue,
                    style: TextStyle(
                      color: growthColor,
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value ?? '-',
              style: const TextStyle(
                fontFamily: 'Inter Tight',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required Color iconBackgroundColor,
    required Color iconColor,
    required String title,
    required String description,
    required String timeAgo,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        print('₹title pressed');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterviewCard(
    BuildContext context, {
    required String name,
    required String position,
    required String date,
    required String time,
    required String imageUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Candidate Image
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: NetworkImage(imageUrl),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Candidate Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Applying for $position',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Interview Time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        date == 'Today'
                            ? Colors.green.shade100
                            : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    date,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          date == 'Today'
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
