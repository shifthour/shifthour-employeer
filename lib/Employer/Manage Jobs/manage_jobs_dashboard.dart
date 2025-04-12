import 'dart:math';
import 'package:flutter/foundation.dart';
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
  } // Add this at the beginning of your fetchJobs method to analyze the structure

  // Replace excessive print statements with conditional logging
  void debugLog(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  Future<void> fetchJobs() async {
    setState(() {
      isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          isLoading = false;
          jobs = [];
        });
        return;
      }

      // Comprehensive query to fetch jobs with potential worker details
      final response = await supabase
          .from('worker_job_listings')
          .select('''
        *,
        worker_job_applications (
          full_name, 
          phone_number, 
          email, 
          application_status,
          date
        )
      ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Process the jobs with joined data
      final processedJobs =
          response.map<Map<String, dynamic>>((job) {
            // Extract worker details
            String workerName = 'No worker assigned';
            String phoneNumber = '';
            String email = '';
            String applicationStatus = '';
            bool hasWorkerAssigned = false;

            // Check if there are associated applications
            final applications = job['worker_job_applications'];
            if (applications != null && applications.isNotEmpty) {
              final firstApplication = applications[0];
              workerName = firstApplication['full_name'] ?? workerName;
              phoneNumber = firstApplication['phone_number'] ?? '';
              email = firstApplication['email'] ?? '';
              applicationStatus = firstApplication['application_status'] ?? '';
              hasWorkerAssigned = true;

              // Debug info to help diagnose issues
              print('Job ${job['job_title']} has worker: $workerName');
              print('Application status: $applicationStatus');
            } else {
              print('Job ${job['job_title']} has no assigned workers');
            }

            // Existing job processing logic
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
            String status = job['status'] ?? "Active";
            bool isUrgent = false;

            // Set the appropriate status color based on the status
            switch (status.toLowerCase()) {
              case 'active':
                statusColor = Colors.green;
                break;
              case 'completed':
                statusColor = Colors.blue;
                break;
              case 'cancelled':
                statusColor = Colors.red;
                break;
              case 'upcoming':
                statusColor = Colors.orange;
                break;
              case 'unassigned':
                statusColor = Colors.grey;
                break;
              default:
                statusColor = Colors.blueGrey;
            }

            // Check if job is marked as urgent
            if (job['urgent'] == true) {
              isUrgent = true;
            }

            return {
              ...job, // Keep all original fields
              'statusColor': statusColor,
              'status': status,
              'urgent': isUrgent,
              'time':
                  job['start_time'] != null && job['end_time'] != null
                      ? '${job['start_time']} - ${job['end_time']}'
                      : 'No time specified',
              'date':
                  jobDate != null
                      ? DateFormat('MMMM d, yyyy').format(jobDate)
                      : 'No date specified',
              'workers': '1/1', // Assuming the application is for one worker
              'pay': '₹${job['pay_rate'] ?? 0}/hr',
              'job_title': job['job_title'] ?? 'Untitled Job',
              'company': job['company'] ?? 'No Company',
              'location': job['location'] ?? 'No Location',
              'description': job['description'] ?? 'No description',
              'number_of_positions':
                  job['number_of_positions'] ?? job['position_number'] ?? 1,
              'worker_name': workerName,
              'phone_number': phoneNumber,
              'email': email,
              'application_status': applicationStatus,
              'has_worker_assigned':
                  hasWorkerAssigned, // Add this flag for easy checking
              'position_number': job['position_number'] ?? 3,
              'shift_id': job['shift_id'] ?? job['id'] ?? "",
            };
          }).toList();

      setState(() {
        jobs = processedJobs;
        isLoading = false;
      });

      // Debug summary
      print('Fetched ${jobs.length} jobs');
      print(
        'Jobs with workers: ${jobs.where((job) => job['has_worker_assigned'] == true).length}',
      );
    } catch (e) {
      print('Error fetching jobs: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredJobs {
    // Get today's date formatted as a string for comparison
    final today = DateTime.now();
    final formattedToday = DateFormat('yyyy-MM-dd').format(today);

    return jobs.where((job) {
      // Debug to help understand the filtering
      print(
        'Filtering job: ${job["job_title"]}, status: ${job["status"]}, has_worker: ${job["has_worker_assigned"]}, date: ${job["date"]}, application_status: ${job["application_status"]}',
      );

      // First apply main tab filter
      if (mainTab == "all") {
        // No filtering for "all" main tab
        return true;
      } else if (mainTab == "assigned") {
        // For assigned tab, first check if job has a worker assigned
        if (job["has_worker_assigned"] != true) {
          return false;
        }

        // Then apply assigned sub-tab filters
        if (assignedSubTab == "all") {
          // Show all assigned jobs
          return true;
        } else if (assignedSubTab == "in-progress") {
          // For in-progress:
          // 1. Job must have a worker assigned (already checked above)
          // 2. Job must be scheduled for today
          // 3. Job must not be completed

          // Parse the job date - this might need adjustment based on your date format
          String jobDateStr = job["date"]?.toString() ?? "";

          try {
            // Try to parse the date if it's in a known format
            DateTime jobDate = DateFormat('MMMM d, yyyy').parse(jobDateStr);
            String formattedJobDate = DateFormat('yyyy-MM-dd').format(jobDate);

            // Check if job is for today and not completed
            return formattedJobDate == formattedToday &&
                job["application_status"]?.toString() != "Completed";
          } catch (e) {
            print("Error parsing date: $e for job: ${job["job_title"]}");
            return false;
          }
        } else if (assignedSubTab == "completed") {
          // Check if the application_status is "Completed" - note the case sensitivity
          return job["application_status"]?.toString() == "Completed";
        } else if (assignedSubTab == "upcoming") {
          // For upcoming jobs, check future dates
          String jobDateStr = job["date"]?.toString() ?? "";

          try {
            // Try to parse the date if it's in a known format
            DateTime jobDate = DateFormat('MMMM d, yyyy').parse(jobDateStr);

            // Check if job date is in the future
            return jobDate.isAfter(today) &&
                job["application_status"]?.toString() != "Completed" &&
                job["application_status"]?.toString() != "Cancelled";
          } catch (e) {
            print("Error parsing date: $e for job: ${job["job_title"]}");
            return false;
          }
        }
      } else if (mainTab == "unassigned") {
        // Show jobs that don't have a worker assigned
        return job["has_worker_assigned"] != true;
      }

      // Apply search filter if there is a search query
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final title = job["job_title"]?.toString().toLowerCase() ?? "";
        final company = job["company"]?.toString().toLowerCase() ?? "";
        final location = job["location"]?.toString().toLowerCase() ?? "";

        // Add Shift ID to search criteria with fallback to job ID
        final shiftId =
            (job['shift_id'] ?? job['id'] ?? "").toString().toLowerCase();

        return title.contains(query) ||
            company.contains(query) ||
            location.contains(query) ||
            shiftId.contains(query);
      }

      return true;
    }).toList();
  }

  TextField _buildSearchTextField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search Shifts by title, location, company, or Shift ID...',
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
    );
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
        backgroundColor: Colors.blue,
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
              hintText: 'Search Shifts by title, location, or company...',
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
            hintText: 'Search Shifts...',
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

class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final bool isDark;

  const JobCard({Key? key, required this.job, required this.isDark})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Debug the available fields
    print('JobCard - Available fields: ${job.keys.toList()}');

    // Get the has_worker_assigned flag, defaulting to false if not present
    final bool hasWorkerAssigned = job['has_worker_assigned'] == true;

    // Check if this is an upcoming job
    final bool isUpcoming =
        job['status']?.toString().toLowerCase() == 'upcoming';

    // Debug the job status and worker assignment
    print(
      'Job ${job["job_title"]} - status: ${job["status"]}, hasWorker: $hasWorkerAssigned',
    );

    // Extract worker name with proper handling
    String workerName = 'No worker assigned';

    final String shiftId =
        job['shift_id']?.toString() ?? job['id']?.toString() ?? 'N/A';
    if (job['worker_name'] != null &&
        job['worker_name'].toString().trim().isNotEmpty) {
      workerName = job['worker_name'];
    } else {
      // Fallback method to extract worker name from various fields
      final nameFields = ['full_name', 'fullName', 'name'];

      for (var field in nameFields) {
        if (job[field] != null) {
          final nameStr = job[field].toString().trim();
          if (nameStr.isNotEmpty &&
              nameStr.toLowerCase() != 'null' &&
              nameStr.toLowerCase() != 'unknown') {
            workerName = nameStr;
            break;
          }
        }
      }
    }
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
            // Top section: Shift ID, pay rate and favorite icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shift ID in place of title
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Shift ID: $shiftId',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
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

            // Job Title below shift ID
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: Text(
                job["job_title"] ?? "Untitled Job",
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),

            // Status Badge - UPDATED: Always show worker assignment badge if a worker is assigned
            if (hasWorkerAssigned)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Worker Assigned",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
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

            // UPDATED: Always display worker name if a worker is assigned
            if (hasWorkerAssigned)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 20,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      workerName,
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

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
  } // Helper method to build skill tags
}

class JobDetailsPopup extends StatelessWidget {
  final Map<String, dynamic> job;
  final bool isDark;

  const JobDetailsPopup({Key? key, required this.job, required this.isDark})
    : super(key: key);

  // Helper function to safely get string values
  String safeString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Debug available fields
    print('JobDetailsPopup - Available fields: ${job.keys.toList()}');
    print(
      'Job ${job["job_title"]} - status: ${job["status"]}, hasWorker: ${job["has_worker_assigned"]}',
    );

    // Get worker assignment status directly from the flag we added
    final bool hasWorkerAssigned = job['has_worker_assigned'] == true;

    // Check if this is an upcoming job (for conditional styling if needed)
    final bool isUpcoming =
        safeString(job['status']).toLowerCase() == 'upcoming';

    // Get the worker name consistently
    String workerName = job['worker_name'] ?? 'No worker assigned';
    final String? phoneNumber = job['phone_number'];
    final String? workerEmail = job['email'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header section - unchanged
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
                        safeString(job["company"], defaultValue: "")
                            .substring(
                              0,
                              min(
                                2,
                                safeString(
                                  job["company"],
                                  defaultValue: "",
                                ).length,
                              ),
                            )
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
                          safeString(
                            job["job_title"],
                            defaultValue: "Untitled Job",
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          safeString(
                            job["company"],
                            defaultValue: "No Company",
                          ),
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

              // Status badges - includes Worker Assigned badge
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
                      safeString(job["status"], defaultValue: "Active"),
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

                  // Worker Assigned Badge - UPDATED to use has_worker_assigned
                  if (hasWorkerAssigned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Text(
                        'Worker Assigned',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Detailed Job Information - unchanged
              _buildDetailRow(
                icon: Icons.calendar_today,
                title: 'Date',
                value: safeString(
                  job["date"],
                  defaultValue: "No date specified",
                ),
              ),

              _buildDetailRow(
                icon: Icons.access_time,
                title: 'Time',
                value: safeString(
                  job["time"],
                  defaultValue: "No time specified",
                ),
              ),

              _buildDetailRow(
                icon: Icons.location_on,
                title: 'Location',
                value: safeString(
                  job["location"],
                  defaultValue: "No location specified",
                ),
              ),

              _buildDetailRow(
                icon: Icons.payments,
                title: 'Pay Rate',
                value: safeString(job["pay"], defaultValue: "₹0/Day"),
              ),

              _buildDetailRow(
                icon: Icons.person_2_outlined,
                title: 'N.o of positions',
                value:
                    job["number_of_positions"] != null
                        ? safeString(job["number_of_positions"])
                        : "No Positions specified",
              ),

              // UPDATED: Always show worker details if a worker is assigned
              if (hasWorkerAssigned) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),

                const Text(
                  'Worker Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Show worker full name
                _buildDetailRow(
                  icon: Icons.person,
                  title: 'Worker Name',
                  value: workerName,
                ),

                // Show worker phone number if available
                if (phoneNumber != null && phoneNumber.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.phone,
                    title: 'Phone Number',
                    value: phoneNumber,
                  ),

                // Show worker email if available
                if (workerEmail != null && workerEmail.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.email,
                    title: 'Email',
                    value: workerEmail,
                  ),

                // Show match percentage if available
                if (job['match_percentage'] != null)
                  _buildDetailRow(
                    icon: Icons.percent,
                    title: 'Match Percentage',
                    value: '${safeString(job['match_percentage'])}%',
                  ),

                // Show application status if available
                if (job['application_status'] != null)
                  _buildDetailRow(
                    icon: Icons.notifications,
                    title: 'Application Status',
                    value: safeString(job['application_status']),
                  ),

                // Show position number if available
                if (job['position_number'] != null)
                  _buildDetailRow(
                    icon: Icons.numbers,
                    title: 'Position Number',
                    value: safeString(job['position_number']),
                  ),

                // Show shift_id if available
                if (job['shift_id'] != null)
                  _buildDetailRow(
                    icon: Icons.work_outline,
                    title: 'Shift ID',
                    value: safeString(job['shift_id']),
                  ),
              ],

              // Additional Details Section - unchanged
              const SizedBox(height: 20),
              const Text(
                'Additional Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                safeString(
                  job["description"],
                  defaultValue: "No additional description provided.",
                ),
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),

              // Rest of the UI remains unchanged
              const SizedBox(height: 20),

              // Action Buttons - unchanged
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Edit Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.back(); // Close the dialog
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
                                onPressed: () => Get.back(),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
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

              // Contact Worker Button - UPDATED to use has_worker_assigned
              if (hasWorkerAssigned &&
                  ((phoneNumber != null && phoneNumber.isNotEmpty) ||
                      (workerEmail != null && workerEmail.isNotEmpty))) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Show contact options dialog
                      Get.dialog(
                        AlertDialog(
                          title: const Text('Contact Worker'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (phoneNumber != null && phoneNumber.isNotEmpty)
                                ListTile(
                                  leading: const Icon(Icons.phone),
                                  title: Text(phoneNumber),
                                  onTap: () {
                                    Get.back();
                                    // Launch phone call
                                  },
                                ),
                              if (workerEmail != null && workerEmail.isNotEmpty)
                                ListTile(
                                  leading: const Icon(Icons.email),
                                  title: Text(workerEmail),
                                  onTap: () {
                                    Get.back();
                                    // Launch email app
                                  },
                                ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.contact_phone),
                    label: const Text('Contact Worker'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build consistent detail rows (unchanged)
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
