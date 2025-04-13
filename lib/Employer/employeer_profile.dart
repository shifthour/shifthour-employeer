import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shifthour_employeer/Employer/Business%20Kyc/kyc.dart';
import 'package:shifthour_employeer/Employer/employer_dashboard.dart';
import 'package:shifthour_employeer/const/Bottom_Navigation.dart';
import 'package:shifthour_employeer/const/Standard_Appbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Model class for Employer data
class Employer {
  final String id;
  final String companyName;
  final String website;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final DateTime createdAt;
  final DateTime updatedAt;

  Employer({
    required this.id,
    required this.companyName,
    required this.website,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Employer.fromJson(Map<String, dynamic> json) {
    return Employer(
      id: json['id'] ?? '',
      companyName: json['company_name'] ?? '',
      website: json['website'] ?? '',
      contactName: json['contact_name'] ?? '',
      contactEmail: json['contact_email'] ?? '',
      contactPhone: json['contact_phone']?.toString() ?? '',
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
    );
  }
}

class EmployerProfileController extends GetxController {
  // Get Supabase client
  final supabase = Supabase.instance.client;

  // Observable to hold the employer data
  final employer = Rx<Employer?>(null);

  // Observable for loading state
  final isLoading = true.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  // Observable variables for company information
  final companyName = ''.obs;
  final companyDescription = ''.obs;

  final website = ''.obs;
  final phoneNumber = ''.obs;
  final emailAddress = ''.obs;
  final contactName = ''.obs;
  final alternateContact = 'Slack: @techvision'.obs;
  final panNumber = ''.obs;
  final panPhotoUrl = ''.obs;
  final incorporationCertificateUrl = ''.obs;
  final isVerified = false.obs;
  // Verification Status
  final verificationProgress = 0.7.obs;

  @override
  void onInit() {
    super.onInit();
    loadEmployerFromSupabase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get the navigation controller and set index without triggering navigation
      final controller = Get.find<NavigationController>();
      controller.currentIndex.value = 4;
    });
  }

  Future<void> loadKycInformation(String userId) async {
    try {
      final response =
          await supabase
              .from('business_verifications')
              .select()
              .eq('user_id', userId)
              .maybeSingle();

      if (response != null) {
        panNumber.value = response['pan_number'] ?? '';
        panPhotoUrl.value = response['pan_photo_url'] ?? '';
        incorporationCertificateUrl.value =
            response['incorporation_certificate_url'] ?? '';
        isVerified.value = response['is_verified'] ?? false;
      }
    } catch (e) {
      print('Error loading KYC information: $e');
    }
  }

  Future<void> loadEmployerFromSupabase() async {
    try {
      isLoading.value = true;

      // Get current user
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('No authenticated user found or user has no email');
      }

      final email = currentUser.email;
      print('Trying to load employer with email: $email');

      // Query the employers table from Supabase
      final response =
          await supabase
              .from('employers')
              .select()
              .eq('contact_email', email!) // Use contact_email not email
              .maybeSingle(); // Use maybeSingle instead of single

      if (response == null) {
        throw Exception('No employer found with email: $email');
      }

      // Convert the response to an Employer object
      final employerData = Employer.fromJson(response);
      employer.value = employerData;

      // Update UI observables with the loaded data
      updateUIFromEmployer(employerData);

      // Load KYC information
      await loadKycInformation(currentUser.id);
    } catch (e) {
      hasError.value = true;
      errorMessage.value = e.toString();
      print('Error loading employer from Supabase: $e');

      // If there's an error, try to load all employers as fallback
      loadAllEmployers();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAllEmployers() async {
    try {
      // Query all records from the employers table
      final response = await supabase
          .from('employers')
          .select()
          .limit(1); // Just get the first employer as fallback

      if (response != null && response.isNotEmpty) {
        final employerData = Employer.fromJson(response[0]);
        employer.value = employerData;

        // Update UI observables
        updateUIFromEmployer(employerData);
      } else {
        throw Exception('No employer records found');
      }
    } catch (e) {
      print('Error in fallback loading: $e');
      // Use sample data as last resort
      loadSampleData();
    }
  }

  // Method to load sample data if all else fails
  void loadSampleData() {
    try {
      // Sample data from the CSV analysis
      final sampleData = {
        'id': '9367f1d8-4441-42e9-a783-cb073fe96434',
        'company_name': 'safestorage',
        'website': 'https://www.safestorage.in',
        'contact_name': 'kushal',
        'contact_email': 'kushal@safestorage.in',
        'contact_phone': '9036140106',
        'created_at': '2025-04-05 12:38:22.377939+00',
        'updated_at': '2025-04-05 12:38:22.380751+00',
      };

      final employerData = Employer.fromJson(sampleData);
      employer.value = employerData;

      // Update UI observables
      updateUIFromEmployer(employerData);
    } catch (e) {
      print('Error loading sample data: $e');
    }
  }

  // Helper method to get current employer ID (implement based on your auth system)
  String getCurrentEmployerId() {
    // In a real app, you would get this from your authentication system
    // For example: return supabase.auth.currentUser?.id ?? '';

    // For demo purposes, return a sample ID
    return '9367f1d8-4441-42e9-a783-cb073fe96434';
  }

  Widget _buildKycInformation(
    BuildContext context,
    EmployerProfileController controller,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KYC Information', style: theme.textTheme.titleMedium),
              Obx(
                () => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        controller.isVerified.value
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    controller.isVerified.value ? 'Verified' : 'Pending',
                    style: TextStyle(
                      color:
                          controller.isVerified.value
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // PAN Number
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAN Number',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Obx(
                      () => Text(
                        controller.panNumber.value.isEmpty
                            ? 'Not provided'
                            : controller.panNumber.value,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Document previews
          Row(
            children: [
              // PAN Card Preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAN Card',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () =>
                          controller.panPhotoUrl.value.isNotEmpty
                              ? Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      controller.panPhotoUrl.value,
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                              : Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'No document',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Incorporation Certificate Preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incorporation Certificate',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () =>
                          controller
                                  .incorporationCertificateUrl
                                  .value
                                  .isNotEmpty
                              ? Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      controller
                                          .incorporationCertificateUrl
                                          .value,
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                              : Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'No document',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Verify Button (if not verified)
          Obx(
            () =>
                controller.isVerified.value
                    ? SizedBox()
                    : Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to verification form
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => StandaloneVerificationForm(
                                      onComplete:
                                          () =>
                                              controller
                                                  .loadEmployerFromSupabase(),
                                    ),
                              ),
                            );
                          },
                          icon: Icon(Icons.verified_user),
                          label: Text('Complete Verification'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // Method to update UI variables from loaded employer data
  void updateUIFromEmployer(Employer employerData) {
    companyName.value = employerData.companyName.trim();
    website.value = employerData.website;
    phoneNumber.value = employerData.contactPhone;
    emailAddress.value = employerData.contactEmail;
    contactName.value = employerData.contactName;
  }

  // Team Members
  final teamMembers =
      <TeamMember>[
        TeamMember(
          name: 'John Doe',
          email: 'john.doe@techvision.com',
          role: 'Owner',
          roleColor: Colors.blue,
          initials: 'JD',
          initialsColor: Colors.blue.shade100,
        ),
        TeamMember(
          name: 'Sarah Johnson',
          email: 'sarah.j@techvision.com',
          role: 'Manager',
          roleColor: Colors.green,
          initials: 'SJ',
          initialsColor: Colors.green.shade100,
        ),
        TeamMember(
          name: 'Robert Lee',
          email: 'robert.l@techvision.com',
          role: 'Recruiter',
          roleColor: Colors.orange,
          initials: 'RL',
          initialsColor: Colors.orange.shade100,
        ),
      ].obs;

  // Account Statistics
  final accountAge = '7 years'.obs;
  final jobsPosted = 248.obs;
  final workersHired = 183.obs;
  final averageRating = 4.8.obs;
}

class TeamMember {
  final String name;
  final String email;
  final String role;
  final Color roleColor;
  final String initials;
  final Color initialsColor;

  TeamMember({
    required this.name,
    required this.email,
    required this.role,
    required this.roleColor,
    required this.initials,
    required this.initialsColor,
  });
}

class EmployerProfileScreen extends StatelessWidget {
  const EmployerProfileScreen({Key? key}) : super(key: key);
  // Add this method to the EmployerProfileScreen class
  void _showImagePopup(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with title and close button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(),
                // Image container with scroll capability
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Failed to load image",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKycInformation(
    BuildContext context,
    EmployerProfileController controller,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KYC Information', style: theme.textTheme.titleMedium),
              Obx(
                () => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        controller.isVerified.value
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    controller.isVerified.value ? 'Verified' : 'Pending',
                    style: TextStyle(
                      color:
                          controller.isVerified.value
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // PAN Number
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAN Number',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Obx(
                      () => Text(
                        controller.panNumber.value.isEmpty
                            ? 'Not provided'
                            : controller.panNumber.value,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Document previews
          Row(
            children: [
              // PAN Card Preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAN Card',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () =>
                          controller.panPhotoUrl.value.isNotEmpty
                              ? GestureDetector(
                                onTap:
                                    () => _showImagePopup(
                                      context,
                                      controller.panPhotoUrl.value,
                                      'PAN Card',
                                    ),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            controller.panPhotoUrl.value,
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    // Tap to view overlay
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.zoom_in,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'No document',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Incorporation Certificate Preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incorporation Certificate',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () =>
                          controller
                                  .incorporationCertificateUrl
                                  .value
                                  .isNotEmpty
                              ? GestureDetector(
                                onTap:
                                    () => _showImagePopup(
                                      context,
                                      controller
                                          .incorporationCertificateUrl
                                          .value,
                                      'Incorporation Certificate',
                                    ),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                            controller
                                                .incorporationCertificateUrl
                                                .value,
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    // Tap to view overlay
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.zoom_in,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'No document',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Verify Button (if not verified)
          Obx(
            () =>
                controller.isVerified.value
                    ? SizedBox()
                    : Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to verification form
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => StandaloneVerificationForm(
                                      onComplete:
                                          () =>
                                              controller
                                                  .loadEmployerFromSupabase(),
                                    ),
                              ),
                            );
                          },
                          icon: Icon(Icons.verified_user),
                          label: Text('Complete Verification'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EmployerProfileController());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: StandardAppBar(
        onBackPressed: () {
          Get.off(() => EmployerDashboard());
        },

        title: 'Employer Profile',
        centerTitle: false,
      ),
      bottomNavigationBar: const ShiftHourBottomNavigation(),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.hasError.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${controller.errorMessage.value}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => controller.loadEmployerFromSupabase(),
                  child: const Text('Retry Loading Data'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Header
            _buildProfileHeader(context, controller),
            const SizedBox(height: 16),

            // Verification Status
            _buildVerificationStatus(context, controller),
            const SizedBox(height: 16),

            // Company Information
            _buildCompanyInformation(context, controller),
            const SizedBox(height: 16),

            // Contact Information
            _buildContactInformation(context, controller),
            const SizedBox(height: 16),

            // KYC Information
            _buildKycInformation(context, controller),
            const SizedBox(height: 16),
          ],
        );
      }),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    EmployerProfileController controller,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Company Logo Placeholder - Use first letter of company name
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Obx(
                () => Text(
                  controller.companyName.value.isNotEmpty
                      ? controller.companyName.value
                          .substring(0, 1)
                          .toUpperCase()
                      : 'S',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => Text(
                    controller.companyName.value,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Edit profile functionality
            },
            child: const Text('Edit Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStatus(
    BuildContext context,
    EmployerProfileController controller,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verification Status', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Obx(
                    () => LinearProgressIndicator(
                      value: controller.verificationProgress.value,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  // Complete verification functionality
                },
                child: const Text('Complete Verification'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInformation(
    BuildContext context,
    EmployerProfileController controller,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Company Information', style: theme.textTheme.titleMedium),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Website',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Obx(
                      () => Text(
                        controller.website.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Company Description',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              Obx(
                () => Text(
                  controller.companyDescription.value.isEmpty
                      ? 'No description available.'
                      : controller.companyDescription.value,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactInformation(
    BuildContext context,
    EmployerProfileController controller,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contact Information', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Name',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Obx(
                      () => Text(
                        controller.contactName.value,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Address',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone Number',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Obx(
                      () => Text(
                        controller.phoneNumber.value,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email Address',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Obx(
                      () => Text(
                        controller.emailAddress.value,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
