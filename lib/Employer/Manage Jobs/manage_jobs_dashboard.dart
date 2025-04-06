import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shifthour_employeer/Employer/employer_dashboard.dart';
import 'package:shifthour_employeer/const/Bottom_Navigation.dart';
import 'package:shifthour_employeer/const/Standard_Appbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shifthour_employeer/Employer/post%20jobs/post_job.dart';
import 'package:intl/intl.dart';

class Manage_Jobs_HomePage extends StatefulWidget {
  const Manage_Jobs_HomePage({Key? key}) : super(key: key);

  @override
  _ManageHomePageState createState() => _ManageHomePageState();
}

class _ManageHomePageState extends State<Manage_Jobs_HomePage> {
  String searchQuery = "";
  String sortBy = "Recent";
  String activeTab = "all";
  bool isLoading = true;
  List<Map<String, dynamic>> jobs = [];
  final supabase = Supabase.instance.client;

  final List<String> sortOptions = ["Recent", "Date", "Pay Rate"];

  @override
  void initState() {
    super.initState();
    fetchJobs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get the navigation controller and set index without triggering navigation
      final controller = Get.find<NavigationController>();
      controller.currentIndex.value = 1;
    });
  }

  Future<void> fetchJobs() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get current user ID
      final userId = supabase.auth.currentUser?.id;
      print('Current user ID: $userId');

      if (userId == null) {
        print('No user ID found - not logged in');
        setState(() {
          isLoading = false;
          jobs = [];
        });
        return;
      }

      // Fetch jobs from the worker_job_listings table where user_id matches current user
      final response = await supabase
          .from('worker_job_listings')
          .select()
          .eq('user_id', userId) // Add this line to filter by current user
          .order('created_at', ascending: false);

      // Debug the response
      print('Supabase response: $response');
      print('Response type: ${response.runtimeType}');
      print(
        'Response length: ${response is List ? response.length : 'not a list'}',
      );

      if (response is List && response.isNotEmpty) {
        // Process each job to add status color
        final processedJobs =
            response.map<Map<String, dynamic>>((job) {
              print('Processing job: $job');

              // Determine status color based on status value
              Color statusColor;
              final status = job['status']?.toString() ?? "Active";
              switch (status.toLowerCase()) {
                case 'active':
                  statusColor = const Color(0xFF10B981); // emerald-500
                  break;
                case 'in progress':
                  statusColor = const Color(0xFF3B82F6); // blue-500
                  break;
                case 'completed':
                  statusColor = const Color(0xFF6B7280); // gray-500
                  break;
                case 'cancelled':
                  statusColor = const Color(0xFFEF4444); // red-500
                  break;
                default:
                  statusColor = const Color(
                    0xFF10B981,
                  ); // default to emerald-500
              }

              // Determine if job is urgent (example logic - modify as needed)
              final now = DateTime.now();
              DateTime jobDate;
              try {
                jobDate = DateTime.parse(job['date'] ?? now.toIso8601String());
              } catch (e) {
                print('Error parsing date: ${job['date']}');
                jobDate = now;
              }

              final isUrgent =
                  jobDate.difference(now).inDays <= 2 && status == 'Active';

              // Format start_time and end_time to displayable format
              String formattedTime = 'No time specified';
              if (job['start_time'] != null && job['end_time'] != null) {
                formattedTime = '${job['start_time']} - ${job['end_time']}';
              }

              // Format date
              String formattedDate = 'No date specified';
              if (job['date'] != null) {
                try {
                  final date = DateTime.parse(job['date']);
                  formattedDate = DateFormat('MMMM d, yyyy').format(date);
                } catch (e) {
                  print('Error formatting date: ${job['date']}');
                  formattedDate = job['date'] ?? 'No date';
                }
              }

              // Create processed job object
              return {
                ...job,
                'statusColor': statusColor,
                'urgent': isUrgent,
                'time': formattedTime,
                'date': formattedDate,
                'workers': '0/1', // Placeholder
                'pay': '₹${job['pay_rate'] ?? 0}/Day',
              };
            }).toList();

        print('Processed ${processedJobs.length} jobs');

        setState(() {
          jobs = processedJobs;
          isLoading = false;
        });
      } else {
        print('No jobs found or response is not a list');
        setState(() {
          jobs = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching jobs: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredJobs {
    return jobs.where((job) {
      // First apply status filter
      if (activeTab == "all") {
        // Continue to search filter
      } else if (activeTab == "Active" &&
          job["status"]?.toString() != "Active") {
        return false;
      } else if (activeTab == "in-progress" &&
          job["status"]?.toString() != "In Progress") {
        return false;
      } else if (activeTab == "completed" &&
          job["status"]?.toString() != "Completed") {
        return false;
      } else if (activeTab == "cancelled" &&
          job["status"]?.toString() != "Cancelled") {
        return false;
      }

      // Then apply search filter if there is a search query
      if (searchQuery.isEmpty) {
        return true;
      }

      // Search in various fields
      final query = searchQuery.toLowerCase();
      final title = job["job_title"]?.toString().toLowerCase() ?? "";
      final company = job["company"]?.toString().toLowerCase() ?? "";
      final location = job["location"]?.toString().toLowerCase() ?? "";

      return title.contains(query) ||
          company.contains(query) ||
          location.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Get screen width for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 1024;

    return Scaffold(
      appBar: StandardAppBar(
        onBackPressed: () {
          Get.off(() => EmployerDashboard());
        },

        title: 'Shift Management',
        centerTitle: false,
        actions: [
          // Search field
          const SizedBox(width: 12),
          // Download Button
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              border: Border.all(color: Colors.blue.shade100),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue,
            child: Text(
              'JD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      bottomNavigationBar: const ShiftHourBottomNavigation(),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Column(
            children: [
              // Header with gradient

              // Main Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Search and Filter Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color:
                            isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white, // slate-900 or white
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return constraints.maxWidth > 700
                                      ? _buildWideSearchFilter()
                                      : _buildNarrowSearchFilter();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tabs
                      Container(
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9), // slate-100
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child:
                            orientation == Orientation.portrait
                                ? _buildTabsPortrait()
                                : _buildTabsLandscape(),
                      ),

                      const SizedBox(height: 16),

                      // Job List or Loading Indicator
                      Expanded(
                        child:
                            isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : filteredJobs.isEmpty
                                ? _buildEmptyState(isDark)
                                : LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Decide on grid or list view based on available width
                                    if (constraints.maxWidth > 900) {
                                      // Grid view for larger screens
                                      return GridView.builder(
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount:
                                                  constraints.maxWidth > 1200
                                                      ? 3
                                                      : 2,
                                              childAspectRatio: 1.2,
                                              crossAxisSpacing: 16,
                                              mainAxisSpacing: 16,
                                            ),
                                        itemCount: filteredJobs.length,
                                        itemBuilder: (context, index) {
                                          return JobCard(
                                            job: filteredJobs[index],
                                            isDark: isDark,
                                          );
                                        },
                                      );
                                    } else {
                                      // List view for smaller screens
                                      return ListView.builder(
                                        itemCount: filteredJobs.length,
                                        itemBuilder: (context, index) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: JobCard(
                                              job: filteredJobs[index],
                                              isDark: isDark,
                                            ),
                                          );
                                        },
                                      );
                                    }
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // FAB
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => const PostJobScreen())?.then((_) => fetchJobs());
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildWideSearchFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search jobs by title, location, or company...',
              prefixIcon: const Icon(Icons.search),
              fillColor:
                  isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC), // slate-50
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color:
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0), // slate-200
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Sort Dropdown
        Flexible(
          child: PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                sortBy = value;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0), // slate-200
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('Sort: $sortBy'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 16),
                ],
              ),
            ),
            itemBuilder:
                (context) =>
                    sortOptions
                        .map(
                          (option) => PopupMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
          ),
        ),

        const SizedBox(width: 8),

        // Filter Button
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color:
                    isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0), // slate-200
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowSearchFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Search Field
        TextField(
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search jobs...',
            prefixIcon: const Icon(Icons.search),
            fillColor:
                isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC), // slate-50
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color:
                    isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0), // slate-200
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        const SizedBox(height: 8),

        // Sort and Filter Row
        Row(
          children: [
            // Sort Dropdown
            Expanded(
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  setState(() {
                    sortBy = value;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0), // slate-200
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sort, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Sort: $sortBy',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 16),
                    ],
                  ),
                ),
                itemBuilder:
                    (context) =>
                        sortOptions
                            .map(
                              (option) => PopupMenuItem<String>(
                                value: option,
                                child: Text(option),
                              ),
                            )
                            .toList(),
              ),
            ),

            const SizedBox(width: 8),

            // Filter Button
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0), // slate-200
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabsPortrait() {
    return Wrap(
      spacing: 4,
      children: [
        _buildTabItem('All Jobs', 'all'),
        _buildTabItem('Active', 'Active'),
        _buildTabItem('In Progress', 'in-progress'),
        _buildTabItem('Completed', 'completed'),
        _buildTabItem('Cancelled', 'cancelled'),
      ],
    );
  }

  Widget _buildTabsLandscape() {
    return Row(
      children: [
        _buildTab('All Jobs', 'all'),
        _buildTab('Active', 'Active'),
        _buildTab('In Progress', 'in-progress'),
        _buildTab('Completed', 'completed'),
        _buildTab('Cancelled', 'cancelled'),
      ],
    );
  }

  Widget _buildTabItem(String title, String value) {
    return FractionallySizedBox(
      widthFactor: title == 'All Jobs' || title == 'In Progress' ? 0.33 : 0.32,
      child: GestureDetector(
        onTap: () {
          setState(() {
            activeTab = value;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                activeTab == value
                    ? Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0F172A) // slate-900
                        : Colors.white
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight:
                  activeTab == value ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String title, String value) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            activeTab = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                activeTab == value
                    ? Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0F172A) // slate-900
                        : Colors.white
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight:
                  activeTab == value ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color:
                  isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9), // slate-100
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.work_outline,
              size: 32,
              color:
                  isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF94A3B8), // slate-400
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No jobs found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            activeTab != 'all'
                ? 'No ${activeTab.replaceAll('-', ' ')} jobs found'
                : 'Post your first job by clicking the + button',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Get.to(() => const PostJobScreen())?.then((_) => fetchJobs());
            },
            icon: const Icon(Icons.add),
            label: const Text('Post a New Job'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// This should be defined as a separate class outside the _ManageHomePageState class
class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final bool isDark;

  const JobCard({Key? key, required this.job, required this.isDark})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFE2E8F0), // slate-200
        ),
      ),
      color:
          isDark ? const Color(0xFF0F172A) : Colors.white, // slate-900 or white
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Urgent Badge
            if (job["urgent"] == true)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF7F1D1D).withOpacity(0.2)
                          : const Color(0xFFFEE2E2), // red-50
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isDark
                            ? const Color(0xFF991B1B)
                            : const Color(0xFFFCA5A5), // red-200
                  ),
                ),
                child: const Text(
                  'Urgent',
                  style: TextStyle(
                    color: Color(0xFFDC2626), // red-600
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),

            // Job Header
            LayoutBuilder(
              builder: (context, constraints) {
                return constraints.maxWidth > 500
                    ? _buildWideJobHeader(context)
                    : _buildNarrowJobHeader(context);
              },
            ),

            const SizedBox(height: 12),

            // Job Details Section
            _buildJobDetailsSection(context),

            const SizedBox(height: 12),

            // View Details Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    // Show job details in a popup
                    Get.dialog(
                      JobDetailsPopup(job: job, isDark: isDark),
                      barrierDismissible: true,
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Details'),
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailsSection(BuildContext context) {
    return Column(
      children: [
        // Date and Time
        Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.grey),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                job["date"] ?? "No date",
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.access_time, size: 14, color: Colors.grey),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                job["time"] ?? "No time specified",
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // Location and Pay
        Row(
          children: [
            Icon(Icons.location_on, size: 14, color: Colors.grey),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                job["location"] ?? "No location",
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.payments, size: 14, color: Colors.grey),
            const SizedBox(width: 5),
            Text(
              job["pay"] ?? "₹0/Day",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWideJobHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company Logo
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                (job["company"] ?? "")
                    .toString()
                    .substring(
                      0,
                      min(2, (job["company"] ?? "").toString().length),
                    )
                    .toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Job Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job["job_title"] ?? "Untitled Job",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                job["company"] ?? "",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Status and Workers
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: job["statusColor"] ?? Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      job["status"] ?? "Active",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Workers Badge (if applicable)
                  if (job["workers"] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9), // slate-100
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${job["workers"]} Workers',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Action Buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () {},
              color: Colors.grey,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () {},
              color: Colors.grey,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNarrowJobHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Company Logo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  (job["company"] ?? "")
                      .toString()
                      .substring(
                        0,
                        min(2, (job["company"] ?? "").toString().length),
                      )
                      .toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class JobDetailsPopup extends StatelessWidget {
  final Map<String, dynamic> job;
  final bool isDark;

  const JobDetailsPopup({Key? key, required this.job, required this.isDark})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Job Title and Company
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        (job["company"] ?? "")
                            .toString()
                            .substring(0, 2)
                            .toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job["job_title"] ?? "Untitled Job",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          job["company"] ?? "No Company",
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Status and Urgent Badge
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: job["statusColor"] ?? Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      job["status"] ?? "Active",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Urgent Badge
                  if (job["urgent"] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Text(
                        'Urgent',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Detailed Job Information
              _buildDetailRow(
                icon: Icons.calendar_today,
                title: 'Date',
                value: job["date"] ?? "No date specified",
              ),

              _buildDetailRow(
                icon: Icons.access_time,
                title: 'Time',
                value: job["time"] ?? "No time specified",
              ),

              _buildDetailRow(
                icon: Icons.location_on,
                title: 'Location',
                value: job["location"] ?? "No location specified",
              ),

              _buildDetailRow(
                icon: Icons.payments,
                title: 'Pay Rate',
                value: job["pay"] ?? "₹0/Day",
              ),

              // Additional Details Section
              const SizedBox(height: 20),
              const Text(
                'Additional Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                job["description"] ?? "No additional description provided.",
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Edit Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement edit functionality
                        Get.back(); // Close the dialog
                        // Optionally, navigate to edit screen
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Job'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Delete Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Show confirmation dialog before deleting
                        Get.dialog(
                          AlertDialog(
                            title: const Text('Delete Job'),
                            content: const Text(
                              'Are you sure you want to delete this job?',
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () =>
                                        Get.back(), // Close confirmation dialog
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  // TODO: Implement delete functionality
                                  Get.back(); // Close confirmation dialog
                                  Get.back(); // Close details dialog
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build consistent detail rows
  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
