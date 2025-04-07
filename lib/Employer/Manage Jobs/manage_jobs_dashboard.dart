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
  String mainTab = "all"; // To track the main tab (all, assigned, unassigned)
  String assignedSubTab = "all";
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
      print('Main Tab: $mainTab');
      print('Assigned Sub-Tab: $assignedSubTab');

      if (userId == null) {
        print('No user ID found - not logged in');
        setState(() {
          isLoading = false;
          jobs = [];
        });
        return;
      }

      // Get today's date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Prepare the jobs list
      List<Map<String, dynamic>> response = [];

      // Fetch jobs based on the current tab selection
      if (mainTab == "all") {
        // For all shifts, fetch from worker_job_listings
        final allJobsResponse = await supabase
            .from('worker_job_listings')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        response = allJobsResponse is List ? allJobsResponse : [];
      } else if (mainTab == "assigned") {
        // For assigned shifts, fetch from worker_job_applications with specific status filters
        final applicationsResponse = await supabase
            .from('worker_job_applications')
            .select()
            .eq('user_id', userId)
            .order('application_date', ascending: false);

        response = applicationsResponse is List ? applicationsResponse : [];
      } else if (mainTab == "unassigned") {
        // For unassigned, return an empty list or fetch unassigned jobs if such a concept exists
        response = [];
      }

      // Debug the response
      print('Supabase response: $response');
      print('Response type: ${response.runtimeType}');
      print('Response length: ${response.length}');

      if (response.isNotEmpty) {
        // Process each job to add status color and determine assignment status
        final processedJobs =
            response.map<Map<String, dynamic>>((job) {
              print('Processing job: $job');

              // Determine processing logic based on the source table
              final isFromApplications = job.containsKey('application_status');

              // Parse job date
              DateTime? jobDate;
              try {
                jobDate =
                    job['date'] != null ? DateTime.parse(job['date']) : null;
              } catch (e) {
                print('Error parsing date: ${job['date']}');
                jobDate = null;
              }

              // Determine status and color
              Color statusColor;
              String status;
              bool isUrgent = false;

              if (isFromApplications) {
                // Logic for worker_job_applications
                if (job['application_status'] == 'Rejected') {
                  status = 'Cancelled';
                  statusColor = const Color(0xFFEF4444); // red-500
                } else if (jobDate == null) {
                  status = 'Active';
                  statusColor = const Color(0xFF10B981); // emerald-500
                } else if (jobDate.isBefore(today)) {
                  status = 'Completed';
                  statusColor = const Color(0xFF6B7280); // gray-500
                } else if (jobDate.isAtSameMomentAs(today)) {
                  status = 'In Progress';
                  statusColor = const Color(0xFF3B82F6); // blue-500
                  isUrgent = true;
                } else {
                  status = 'Upcoming';
                  statusColor = const Color(0xFF10B981); // emerald-500

                  // Check if the upcoming job is within the next 2 days to mark as urgent
                  if (jobDate.difference(today).inDays <= 2) {
                    isUrgent = true;
                  }
                }
              } else {
                // Logic for worker_job_listings
                status = job['status']?.toString() ?? "Active";
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

                // Determine urgency for job listings
                if (jobDate != null) {
                  isUrgent =
                      jobDate.difference(today).inDays <= 2 &&
                      status == 'Active';
                }
              }

              // Format start_time and end_time
              String formattedTime = 'No time specified';
              if (job['start_time'] != null && job['end_time'] != null) {
                formattedTime = '${job['start_time']} - ${job['end_time']}';
              }

              // Format date
              String formattedDate = 'No date specified';
              if (jobDate != null) {
                formattedDate = DateFormat('MMMM d, yyyy').format(jobDate);
              }

              // Create processed job object
              return {
                ...job,
                'statusColor': statusColor,
                'status': status,
                'urgent': isUrgent,
                'time': formattedTime,
                'date': formattedDate,
                'workers':
                    '1/1', // Assuming the application is for the current user
                'pay': '₹${job['pay_rate'] ?? 0}/Day',
                'job_title': job['job_title'] ?? 'Untitled Job',
                'company': job['company'] ?? 'No Company',
                'location': job['location'] ?? 'No Location',
                'description':
                    job['description'] ??
                    (job['cover_letter'] ?? 'No description'),
                'skills':
                    job['skills'] ??
                    (job['position_number'] != null
                        ? 'Position ${job['position_number']}'
                        : 'No specific skills'),
                'number_of_positions':
                    job['number_of_positions'] ?? job['position_number'],
              };
            }).toList();

        // Apply additional filtering based on assigned sub-tab
        final filteredJobs =
            processedJobs.where((job) {
              print('Job status for filtering: ${job['status']}');

              if (mainTab == "assigned") {
                switch (assignedSubTab) {
                  case 'in-progress':
                    return job['status'].toString().toLowerCase().contains(
                      'progress',
                    );
                  case 'completed':
                    return job['status'].toString().toLowerCase() ==
                        'completed';
                  case 'upcoming':
                    return job['status'].toString().toLowerCase() == 'upcoming';
                  default: // 'all'
                    return true;
                }
              }
              return true;
            }).toList();

        print('Processed ${processedJobs.length} jobs');
        print('Filtered ${filteredJobs.length} jobs');

        setState(() {
          jobs = filteredJobs;
          isLoading = false;
        });
      } else {
        print('No jobs found');
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
      // First apply main tab filter
      if (mainTab == "all") {
        // Continue to sub-filter if assigned tab is selected
        if (activeTab == "assigned") {
          // Then apply assigned sub-tab filters
          if (assignedSubTab == "all") {
            // Show all assigned jobs
            return job["status"] != "Unassigned";
          } else if (assignedSubTab == "in-progress" &&
              job["status"] != "In Progress") {
            return false;
          } else if (assignedSubTab == "completed" &&
              job["status"] != "Completed") {
            return false;
          } else if (assignedSubTab == "upcoming" &&
              job["status"] != "Upcoming") {
            return false;
          }
        }
        // No further filtering for "all" tab
      } else if (mainTab == "assigned") {
        // Check if job is assigned
        if (job["status"] == "Unassigned") {
          return false;
        }

        // Then apply assigned sub-tab filters
        if (assignedSubTab == "all") {
          // Show all assigned jobs
          return true;
        } else if (assignedSubTab == "in-progress" &&
            job["status"] != "In Progress") {
          return false;
        } else if (assignedSubTab == "completed" &&
            job["status"] != "Completed") {
          return false;
        } else if (assignedSubTab == "upcoming" &&
            job["status"] != "Upcoming") {
          return false;
        }
      } else if (mainTab == "unassigned" && job["status"] != "Unassigned") {
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
          Get.to(() => const PostShiftScreen())?.then((_) => fetchJobs());
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
    return Column(
      children: [
        // Main tabs
        Row(
          children: [
            _buildMainTab('All Shifts', 'all'),
            _buildMainTab('Assigned', 'assigned'),
            _buildMainTab('Unassigned', 'unassigned'),
          ],
        ),

        // Sub-tabs for Assigned (only show when assigned tab is selected)
        if (mainTab == "assigned")
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                _buildSubTab('All', 'all'),
                _buildSubTab('In Progress', 'in-progress'),
                _buildSubTab('Completed', 'completed'),
                _buildSubTab('Upcoming', 'upcoming'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTabsLandscape() {
    return Column(
      children: [
        // Main tabs
        Row(
          children: [
            _buildMainTab('All Shifts', 'all'),
            _buildMainTab('Assigned', 'assigned'),
            _buildMainTab('Unassigned', 'unassigned'),
          ],
        ),

        // Sub-tabs for Assigned (only show when assigned tab is selected)
        if (mainTab == "assigned")
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                _buildSubTab('All', 'all'),
                _buildSubTab('In Progress', 'in-progress'),
                _buildSubTab('Completed', 'completed'),
                _buildSubTab('Upcoming', 'upcoming'),
              ],
            ),
          ),
      ],
    );
  }

  // Add these new methods for main tabs and sub-tabs
  Widget _buildMainTab(String title, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            mainTab = value;
            // Reset assigned sub-tab when changing main tab
            if (value != "assigned") {
              assignedSubTab = "all";
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                mainTab == value
                    ? isDark
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
                  mainTab == value ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubTab(String title, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            assignedSubTab = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                assignedSubTab == value
                    ? isDark
                        ? const Color(0xFF1E293B) // slate-800
                        : const Color(0xFFF8FAFC) // very light blue
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:
                assignedSubTab == value
                    ? Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                      width: 1,
                    )
                    : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  assignedSubTab == value ? FontWeight.bold : FontWeight.normal,
              color:
                  assignedSubTab == value
                      ? Theme.of(context).primaryColor
                      : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(String title, String value) {
    return FractionallySizedBox(
      widthFactor:
          title == 'All Shifts' || title == 'In Progress' ? 0.33 : 0.32,
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
              Get.to(() => const PostShiftScreen())?.then((_) => fetchJobs());
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
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section: Job title, pay rate and favorite icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Job Title
                Expanded(
                  child: Text(
                    job["job_title"] ?? "Untitled Job",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),

                // Pay Rate with Container
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "₹${job["pay_rate"] ?? "0"}/hr",
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),

                // Favorite Icon
                IconButton(
                  icon: Icon(
                    Icons.favorite_border,
                    color: isDark ? Colors.grey : Colors.grey.shade400,
                  ),
                  onPressed: () {
                    // Implement favorite functionality
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    job["location"] ?? "No location specified",
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            // Time with icon
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 20,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    job["start_time"] != null && job["end_time"] != null
                        ? "${job["start_time"]} - ${job["end_time"]}"
                        : "No time specified",
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            // Company with icon
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.currency_rupee_outlined,
                    size: 20,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    job["company"] ?? "No company specified",
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            // Skills/Tags
            Wrap(spacing: 8, runSpacing: 8, children: _buildSkillTags()),

            const SizedBox(height: 20),

            // View Details Button (right-aligned)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Show job details in a popup
                    Get.dialog(
                      JobDetailsPopup(job: job, isDark: isDark),
                      barrierDismissible: true,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "View Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build skill tags
  List<Widget> _buildSkillTags() {
    // Sample skills - in real implementation, you'd fetch these from job data
    final skills = [
      if (job["skills"] != null)
        ...job["skills"].toString().split(',')
      else
        ["Forklift", "Heavy Lifting"],
    ];

    return skills.map((skill) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          skill.toString(),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
          ),
        ),
      );
    }).toList();
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
              _buildDetailRow(
                icon: Icons.person_2_outlined,
                title: 'N.o of positions',
                value:
                    job["number_of_positions"] != null
                        ? job["number_of_positions"].toString()
                        : "No Positions specified",
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
