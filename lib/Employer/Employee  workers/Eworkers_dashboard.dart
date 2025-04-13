import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shifthour_employeer/Employer/employer_dashboard.dart';
import 'package:shifthour_employeer/const/Activity_log.dart';
import 'package:shifthour_employeer/const/Bottom_Navigation.dart';
import 'package:shifthour_employeer/const/Standard_Appbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class WorkerApplicationsController extends GetxController {
  // Reactive variables for state management
  final RxList<Map<String, dynamic>> applications =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxString searchQuery = ''.obs;

  final supabase = Supabase.instance.client;

  @override
  void onInit() {
    super.onInit();
    fetchApplications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get the navigation controller and set index without triggering navigation
      final controller = Get.find<NavigationController>();
      controller.currentIndex.value = 2;
    });
  }

  // Add these at the top of your WorkerApplicationsController class
  final RxMap<String, bool> checkInLoading = <String, bool>{}.obs;
  final RxMap<String, RxString> checkInStatuses = <String, RxString>{}.obs;

  // Complete implementation of checkIn method
  Future<void> checkIn(
    Map<String, dynamic> application,
    BuildContext context,
  ) async {
    // Ensure the context is still valid
    if (!context.mounted) return;

    try {
      // Set loading state for this specific application
      final appId = application['id'].toString();
      checkInLoading[appId] = true;

      // Check if the job has already been checked in
      final existingCheckIn = await _checkExistingCheckIn(application);

      // Clear loading flag
      checkInLoading[appId] = false;

      if (existingCheckIn != null) {
        // If already checked in, proceed to checkout
        await _showCheckOutDialog(context, application, existingCheckIn);
      } else {
        // Prompt for job seeker code
        await _showCheckInCodeDialog(context, application);
      }
    } catch (e) {
      // Clear loading flag on error
      final appId = application['id'].toString();
      checkInLoading[appId] = false;

      print('Error in check-in process: $e');
      // Show error snackbar if context is still valid
      if (context.mounted) {
        _showErrorSnackbar(context, 'An error occurred during check-in');
      }
    }
  }

  // Complete implementation of getCheckInStatus
  Future<String> getCheckInStatus(Map<String, dynamic> application) async {
    final appId = application['id'].toString();

    // If we have a cached status that's not 'loading', return it immediately
    if (checkInStatuses.containsKey(appId) &&
        checkInStatuses[appId]!.value != 'loading') {
      return checkInStatuses[appId]!.value;
    }

    try {
      print('Checking Check-In Status for Application ID: $appId');

      final response =
          await supabase
              .from('worker_attendance')
              .select('status')
              .eq('application_id', appId)
              .order('created_at', ascending: false)
              .maybeSingle();

      print('Check-In Status Response: $response');

      // Get the status from response or default to not_checked_in
      final status = response?['status'] ?? 'not_checked_in';

      // Cache the result for future use
      if (!checkInStatuses.containsKey(appId)) {
        checkInStatuses[appId] = RxString(status);
      } else {
        checkInStatuses[appId]!.value = status;
      }

      return status;
    } catch (e) {
      print('Error checking check-in status: $e');

      // If there's a Supabase error, print more details
      if (e is PostgrestException) {
        print('Supabase Error Details:');
        print('Message: ${e.message}');
        print('Hint: ${e.hint}');
        print('Details: ${e.details}');
      }

      // Return cached status if available, otherwise default
      if (checkInStatuses.containsKey(appId)) {
        return checkInStatuses[appId]!.value;
      }
      return 'not_checked_in';
    }
  }

  Future<bool> cancelShift(Map application, BuildContext context) async {
    try {
      // Show confirmation dialog
      final shouldCancel = await _showCancelConfirmationDialog(context);
      if (shouldCancel != true) {
        return false;
      }

      final applicationId = application['id'];
      final shiftId = application['shift_id'];

      if (applicationId == null || shiftId == null) {
        throw Exception('Invalid application or shift ID');
      }

      // Show loading indicator
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      await ActivityLogger.logShiftCancellation(
        application as Map<String, dynamic>,
      );
      // Check if shift can be cancelled (before 24 hours)
      final shiftResponse =
          await supabase
              .from('worker_job_listings')
              .select('date, start_time')
              .eq('shift_id', shiftId)
              .single();

      if (shiftResponse == null) {
        throw Exception('Shift not found');
      }

      // Parse shift date and time
      final shiftDate = DateTime.parse(
        shiftResponse['shift_date'] ?? DateTime.now().toIso8601String(),
      );

      // Parse time from string like "10:00 AM" to DateTime
      final shiftTime = _parseTime(
        shiftResponse['shift_start_time'] ?? "12:00 PM",
      );

      final shiftDateTime = DateTime(
        shiftDate.year,
        shiftDate.month,
        shiftDate.day,
        shiftTime.hour,
        shiftTime.minute,
      );

      // Check if shift is more than 24 hours away
      // Uncomment if you want this validation
      // final now = DateTime.now();
      // final difference = shiftDateTime.difference(now);
      // if (difference.inHours < 24) {
      //   Get.back(); // Close loading dialog
      //   Get.dialog(
      //     AlertDialog(
      //       title: Text('Cannot Cancel Shift'),
      //       content: Text(
      //         'Shifts can only be cancelled at least 24 hours before they start.',
      //       ),
      //       actions: [
      //         TextButton(onPressed: () => Get.back(), child: Text('OK')),
      //       ],
      //     ),
      //   );
      //   return false;
      // }

      // First, check if the application has attendance records
      final attendanceResponse = await supabase
          .from('worker_attendance')
          .select('id')
          .eq('application_id', applicationId);

      // If there are attendance records, we can't delete the application
      if (attendanceResponse != null && attendanceResponse.length > 0) {
        // Close loading dialog
        Get.back();

        // Show error dialog for in-progress shifts
        Get.dialog(
          AlertDialog(
            title: Text('Cannot Cancel Shift'),
            content: Text(
              'This shift has already been checked in or is in progress. You cannot cancel it now.',
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: Text('OK')),
            ],
          ),
        );

        return false;
      }

      // If no attendance records, update the application status to Cancelled
      await supabase
          .from('worker_job_applications')
          .delete()
          .eq('shift_id', shiftId)
          .eq('id', applicationId);

      // Close loading dialog
      Get.back();

      // Refresh the applications list
      await refreshApplications();

      // Show success message
      Get.snackbar(
        'Shift Cancelled',
        'The shift has been successfully cancelled',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      // Close loading dialog if open
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      print('Error cancelling shift: $e');

      // Show error message
      Get.snackbar(
        'Error',
        'Failed to cancel shift: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      return false;
    }
  }

  // Helper method to show the confirmation dialog
  Future<bool?> _showCancelConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Cancel Shift'),
            content: Text(
              'Are you sure you want to cancel this shift? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Yes, Cancel'),
              ),
            ],
          ),
    );
  } // Add this helper method to parse time strings

  DateTime _parseTime(String timeString) {
    // Default to noon if parsing fails
    if (timeString == null || timeString.isEmpty) {
      return DateTime(2022, 1, 1, 12, 0);
    }

    try {
      // Handle time formats like "10:00 AM" or "14:00"
      timeString = timeString.trim().toUpperCase();

      int hour = 0;
      int minute = 0;

      if (timeString.contains('AM') || timeString.contains('PM')) {
        // Handle 12-hour format with AM/PM
        final parts = timeString.split(' ');
        final timePart = parts[0];
        final amPm = parts[1];

        final timeSplit = timePart.split(':');
        hour = int.parse(timeSplit[0]);
        minute = int.parse(timeSplit[1]);

        // Convert to 24-hour format
        if (amPm == 'PM' && hour < 12) {
          hour += 12;
        } else if (amPm == 'AM' && hour == 12) {
          hour = 0;
        }
      } else {
        // Handle 24-hour format
        final timeSplit = timeString.split(':');
        hour = int.parse(timeSplit[0]);
        minute = int.parse(timeSplit[1]);
      }

      return DateTime(2022, 1, 1, hour, minute);
    } catch (e) {
      print('Error parsing time: $e');
      return DateTime(2022, 1, 1, 12, 0); // Default to noon
    }
  }

  // Add this helper method to show a confirmation dialog

  // Complete implementation of _performCheckIn
  // Complete implementation of _performCheckIn
  Future<void> _performCheckIn(Map<String, dynamic> application) async {
    final appId = application['id'].toString();

    try {
      // First verify the worker exists in job_seekers table
      final workerId = application['worker_id'] ?? application['user_id'];
      await ActivityLogger.logWorkerCheckIn(application);

      // Check if the worker exists in job_seekers table
      final workerExists =
          await supabase
              .from('job_seekers')
              .select('id')
              .eq('id', workerId)
              .maybeSingle();

      // Update application status to In Progress
      if (application['shift_id'] != null) {
        await supabase
            .from('worker_job_applications')
            .update({'application_status': 'In Progress'})
            .eq('shift_id', application['shift_id'])
            .eq('id', application['id']);
      }

      // If worker doesn't exist in job_seekers, we need to handle this case
      if (workerExists == null) {
        print('Warning: Worker ID $workerId not found in job_seekers table');

        // Option 2: Use a different ID field like application ID
        final insertData = {
          'application_id': application['id'],
          'shift_id': application['shift_id'],
          // Use application ID instead of worker_id to avoid the foreign key issue
          // 'worker_id': workerId, // This is the problematic line
          'check_in_time': DateTime.now().toIso8601String(),
          'status': 'checked_in',
          'job_title': application['job_title'] ?? 'Unknown Job',
          'company': application['company'] ?? 'Unknown Company',
          'location': application['location'] ?? 'Unknown Location',
        };

        // Remove any null values
        insertData.removeWhere((key, value) => value == null);

        final response =
            await supabase
                .from('worker_attendance')
                .insert(insertData)
                .select();

        print('Check-In Insertion Response (without worker_id): $response');
      } else {
        // Worker exists in job_seekers table, proceed with normal check-in
        final insertData = {
          'application_id': application['id'],
          'shift_id': application['shift_id'],
          'worker_id': workerId,
          'check_in_time': DateTime.now().toIso8601String(),
          'status': 'checked_in',
          'job_title': application['job_title'] ?? 'Unknown Job',
          'company': application['company'] ?? 'Unknown Company',
          'location': application['location'] ?? 'Unknown Location',
        };

        // Remove any null values
        insertData.removeWhere((key, value) => value == null);

        final response =
            await supabase
                .from('worker_attendance')
                .insert(insertData)
                .select();

        print('Check-In Insertion Response: $response');
      }

      // After successful check-in, update the cached status immediately
      if (!checkInStatuses.containsKey(appId)) {
        checkInStatuses[appId] = RxString('checked_in');
      } else {
        checkInStatuses[appId]!.value = 'checked_in';
      }
    } catch (e) {
      print('Error performing check-in: $e');

      // If it's a Supabase error, print more details
      if (e is PostgrestException) {
        print('Supabase Error Details:');
        print('Message: ${e.message}');
        print('Hint: ${e.hint}');
        print('Details: ${e.details}');
      }

      rethrow;
    }
  } // Complete implementation of _performCheckOut

  Future<void> _performCheckOut(
    Map<String, dynamic>? checkInRecord,
    int onTimeRating,
    int performanceRating,
    String? feedback,
  ) async {
    try {
      // First, check if checkInRecord is null
      if (checkInRecord == null) {
        print('Error: checkInRecord is null');
        return;
      }

      // Check if id exists in the record
      if (checkInRecord['id'] == null) {
        print('Error: checkInRecord does not contain an id field');
        return;
      }

      // Get application ID and shift ID for status updating
      final applicationId = checkInRecord['application_id']?.toString();
      final shiftId = checkInRecord['shift_id']?.toString();

      // Create update data with proper null handling
      final updateData = {
        'check_out_time': DateTime.now().toIso8601String(),
        'status': 'checked_out',
        'on_time_rating': onTimeRating,
        'performance_rating': performanceRating,
      };

      // Only add feedback if it's not null or empty
      if (feedback != null && feedback.trim().isNotEmpty) {
        updateData['feedback'] = feedback;
      }

      // Log activity with enriched data
      if (checkInRecord != null) {
        // Create a merged record with both checkout and application data
        Map<String, dynamic> logData = {...checkInRecord};

        // Try to find the original application to get worker details
        try {
          final applicationData =
              await supabase
                  .from('worker_job_applications')
                  .select('full_name, job_title')
                  .eq('id', checkInRecord['application_id'])
                  .single();

          if (applicationData != null) {
            logData['full_name'] = applicationData['full_name'];
            if (logData['job_title'] == null) {
              logData['job_title'] = applicationData['job_title'];
            }
          }
        } catch (e) {
          print('Could not fetch worker details for log: $e');
        }

        await ActivityLogger.logWorkerCheckOut(logData);
      }

      // Update attendance record
      await supabase
          .from('worker_attendance')
          .update(updateData)
          .eq('id', checkInRecord['id']);

      // Update worker job application status to Completed
      if (shiftId != null) {
        await supabase
            .from('worker_job_applications')
            .update({'application_status': 'Completed'})
            .eq('shift_id', shiftId);
      }

      // Check if worker_id exists before updating worker ratings
      if (checkInRecord['worker_id'] != null) {
        // Optionally, update worker's overall ratings
        await _updateWorkerRatings(
          checkInRecord['worker_id'].toString(),
          onTimeRating,
          performanceRating,
        );
      } else {
        print('Warning: worker_id is null, skipping worker ratings update');
      }

      // After successful check-out, update the cached status
      if (applicationId != null) {
        if (!checkInStatuses.containsKey(applicationId)) {
          checkInStatuses[applicationId] = RxString('checked_out');
        } else {
          checkInStatuses[applicationId]!.value = 'checked_out';
        }
      }
    } catch (e) {
      print('Error performing check-out: $e');

      // If it's a Supabase error, print more details
      if (e is PostgrestException) {
        print('Supabase Error Details:');
        print('Message: ${e.message}');
        print('Hint: ${e.hint}');
        print('Details: ${e.details}');
      }

      rethrow;
    }
  } // Helper method to build the check button (add this to your WorkerApplicationsScreen class)

  Widget _buildCheckButton(
    BuildContext context,
    Map<String, dynamic> application,
    WorkerApplicationsController controller,
  ) {
    final appId = application['id'].toString();

    // Initialize the status in our cache if it doesn't exist yet
    if (!controller.checkInStatuses.containsKey(appId)) {
      controller.checkInStatuses[appId] = RxString('loading');

      // Fetch the initial status
      controller.getCheckInStatus(application).then((status) {
        // The status will be updated in the cache by getCheckInStatus
      });
    }

    // Now we can use Obx to watch changes to both the status and loading state
    return Obx(() {
      // Get current status from our cache
      final status = controller.checkInStatuses[appId]?.value ?? 'loading';

      // Show loading spinner while fetching initial status
      if (status == 'loading') {
        return ElevatedButton(onPressed: null, child: Text('Loading...'));
      }

      // Check if this application is in loading state (during check-in/out)
      final isLoading = controller.checkInLoading[appId] == true;

      // Show loading button while performing check-in/out
      if (isLoading) {
        return ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: status == 'checked_in' ? Colors.red : Colors.green,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 8),
              Text('Processing...'),
            ],
          ),
        );
      }

      // If already checked out, show Done with a grey color
      if (status == 'checked_out') {
        return ElevatedButton(
          onPressed: null, // Disable button as process is complete
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          child: Text('Done'),
        );
      }

      // Regular button for check-in or check-out
      return ElevatedButton(
        onPressed: () => controller.checkIn(application, context),
        style: ElevatedButton.styleFrom(
          backgroundColor: status == 'checked_in' ? Colors.red : Colors.green,
        ),
        child: Text(status == 'checked_in' ? 'Check Out' : 'Check In'),
      );
    });
  }

  bool isUpcomingShift(Map<String, dynamic> application) {
    try {
      // Get current date and time
      final now = DateTime.now();

      // Parse shift date from the application
      DateTime? shiftDate;
      if (application['date'] != null) {
        shiftDate = DateTime.parse(application['date'].toString());
      } else if (application['shift_date'] != null) {
        shiftDate = DateTime.parse(application['shift_date'].toString());
      }

      // If no date is available, we can't determine if it's upcoming
      if (shiftDate == null) {
        return false;
      }

      // For shifts scheduled for today, check if they're still in the future
      if (shiftDate.year == now.year &&
          shiftDate.month == now.month &&
          shiftDate.day == now.day) {
        // Parse time from string like "10:00 AM" to DateTime
        DateTime shiftTime;
        if (application['start_time'] != null) {
          shiftTime = _parseTime(application['start_time'].toString());
        } else if (application['shift_start_time'] != null) {
          shiftTime = _parseTime(application['shift_start_time'].toString());
        } else {
          // Default to start of day if no time specified
          shiftTime = DateTime(2022, 1, 1, 0, 0);
        }

        // Combine date and time
        final shiftDateTime = DateTime(
          shiftDate.year,
          shiftDate.month,
          shiftDate.day,
          shiftTime.hour,
          shiftTime.minute,
        );

        // Debug logs
        print('Current time: $now');
        print('Shift date/time for ${application['shift_id']}: $shiftDateTime');
        print('Is after: ${shiftDateTime.isAfter(now)}');

        // For today's shifts, check the specific time
        return shiftDateTime.isAfter(now);
      } else {
        // For future dates, consider them upcoming regardless of time
        final today = DateTime(now.year, now.month, now.day);
        final shiftDay = DateTime(
          shiftDate.year,
          shiftDate.month,
          shiftDate.day,
        );

        // Debug logs
        print('Today: $today');
        print('Shift day for ${application['shift_id']}: $shiftDay');
        print('Is after or same day: ${shiftDay.compareTo(today) >= 0}');

        // A shift is upcoming if the date is today or later
        return shiftDay.compareTo(today) >= 0;
      }
    } catch (e) {
      print('Error determining if shift is upcoming: $e');
      return false; // Default to not showing cancel button if there's an error
    }
  }

  Future<void> refreshApplications() async {
    try {
      // Reset applications but keep search query
      applications.clear();

      // Show loading indicator during refresh
      isLoading.value = true;

      // Fetch new data
      await fetchApplications();

      // Show a success message or handle as needed
      Get.snackbar(
        'Refreshed',
        'Applications data has been updated',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      print('Error refreshing applications: $e');
      Get.snackbar(
        'Refresh Failed',
        'Could not update applications data',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _showCheckInCodeDialog(
    BuildContext context,
    Map<String, dynamic> application,
  ) async {
    final codeController = TextEditingController();

    // Store the result of the dialog
    final code = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          backgroundColor: Colors.white,
          elevation: 8.0,
          titlePadding: EdgeInsets.all(20.0),
          contentPadding: EdgeInsets.symmetric(horizontal: 20.0),
          title: Text(
            'Verify Check-In',
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please enter the Shift Seeker Code to verify check-in:',
                style: TextStyle(fontSize: 16.0),
              ),
              SizedBox(height: 16.0),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  hintText: 'Enter Shift Seeker Code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  prefixIcon: Icon(Icons.code),
                ),
                keyboardType: TextInputType.text,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                // Return the code entered
                Navigator.of(dialogContext).pop(codeController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: Text('Verify', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    // After dialog is closed, check if code exists and context is still valid
    if (code != null && code.isNotEmpty && context.mounted) {
      try {
        // Verify job seeker code
        final isValid = await _verifyJobSeekerCode(
          application['full_name'],
          code,
        );

        // Continue only if context is still valid
        if (!context.mounted) return;

        if (isValid) {
          // Perform check-in
          await _performCheckIn(application);
          _showSuccessSnackbar(context, 'Check-in successful!');
        } else {
          // Show error
          _showErrorSnackbar(context, 'Invalid job seeker code');
        }
      } catch (e) {
        // Handle errors if context is still valid
        if (context.mounted) {
          _showErrorSnackbar(context, 'Error during check-in: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _showCheckOutDialog(
    BuildContext context,
    Map<String, dynamic> application,
    Map<String, dynamic> checkInRecord,
  ) async {
    // Use RxInt to track the selected ratings
    final onTimeRating = RxInt(0);
    final performanceRating = RxInt(0);
    final feedbackController = TextEditingController();

    // Store the result of the dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Check Out'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'On-Time Rating',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < onTimeRating.value
                                ? Icons.star
                                : Icons.star_border,
                            color:
                                index < onTimeRating.value
                                    ? Colors.amber
                                    : Colors.grey,
                            size: 30,
                          ),
                          onPressed: () {
                            onTimeRating.value = index + 1;
                          },
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Performance Rating',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < performanceRating.value
                                ? Icons.star
                                : Icons.star_border,
                            color:
                                index < performanceRating.value
                                    ? Colors.amber
                                    : Colors.grey,
                            size: 25,
                          ),
                          onPressed: () {
                            performanceRating.value = index + 1;
                          },
                        );
                      }),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  decoration: InputDecoration(
                    labelText: 'Additional Feedback',
                    hintText: 'Enter any additional comments',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate ratings
                if (onTimeRating.value < 1 || performanceRating.value < 1) {
                  // Show error inside the dialog context
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Please rate both on-time and performance'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Return ratings when valid
                Navigator.of(dialogContext).pop({
                  'onTimeRating': onTimeRating.value,
                  'performanceRating': performanceRating.value,
                  'feedback': feedbackController.text,
                });
              },
              child: Text('Check Out'),
            ),
          ],
        );
      },
    );

    // After dialog is closed, check if result exists and context is still valid
    if (result != null && context.mounted) {
      try {
        // Perform check-out with the returned values
        await _performCheckOut(
          checkInRecord,
          result['onTimeRating'],
          result['performanceRating'],
          result['feedback'],
        );

        // Show success message if context is still valid
        if (context.mounted) {
          _showSuccessSnackbar(context, 'Check-out successful!');
        }
      } catch (e) {
        // Handle errors if context is still valid
        if (context.mounted) {
          _showErrorSnackbar(
            context,
            'Error during check-out: ${e.toString()}',
          );
        }
      }
    }
  }

  Future<Map<String, dynamic>?> _checkExistingCheckIn(
    Map<String, dynamic> application,
  ) async {
    try {
      final response =
          await supabase
              .from('worker_attendance')
              .select()
              .eq('application_id', application['id'])
              .eq('status', 'checked_in')
              .maybeSingle();

      return response;
    } catch (e) {
      print('Error checking existing check-in: $e');
      return null;
    }
  }

  Future<bool> _verifyJobSeekerCode(String fullName, String enteredCode) async {
    try {
      final response =
          await supabase
              .from('job_seekers')
              .select('id, job_seeker_code')
              .eq('full_name', fullName)
              .eq('job_seeker_code', enteredCode)
              .maybeSingle();

      print('Job Seeker Verification Response: $response');
      return response != null;
    } catch (e) {
      print('Error verifying job seeker code: $e');
      return false;
    }
  }

  Future<void> _updateWorkerRatings(
    String workerId,
    int onTimeRating,
    int performanceRating,
  ) async {
    try {
      // Fetch current worker ratings
      final workerResponse =
          await supabase
              .from('job_seekers')
              .select('on_time_percentage, average_rating, shifts_completed')
              .eq('id', workerId)
              .maybeSingle();

      if (workerResponse != null) {
        // Calculate new ratings
        final currentShiftsCompleted = workerResponse['shifts_completed'] ?? 0;
        final newShiftsCompleted = currentShiftsCompleted + 1;

        final currentOnTimePercentage =
            workerResponse['on_time_percentage'] ?? 0.0;
        final newOnTimePercentage =
            ((currentOnTimePercentage * currentShiftsCompleted) +
                onTimeRating) /
            newShiftsCompleted;

        final currentAverageRating = workerResponse['average_rating'] ?? 0.0;
        final newAverageRating =
            ((currentAverageRating * currentShiftsCompleted) +
                performanceRating) /
            newShiftsCompleted;

        // Update worker profile
        await supabase
            .from('job_seekers')
            .update({
              'on_time_percentage': newOnTimePercentage,
              'average_rating': newAverageRating,
              'shifts_completed': newShiftsCompleted,
            })
            .eq('id', workerId);
      }
    } catch (e) {
      print('Error updating worker ratings: $e');
    }
  }

  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void viewDetails(Map<String, dynamic> application) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Container(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Application Details',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B6BF8),
                      fontFamily: 'Inter',
                    ),
                  ),
                  InkWell(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.0),
              Divider(color: Colors.grey.shade200, thickness: 1),
              SizedBox(height: 16.0),
              _buildInfoRow('Full Name', application['full_name']),
              _buildInfoRow('Phone', application['phone_number']),
              _buildInfoRow('Email', application['email']),
              if (application['status'] != null)
                _buildStatusRow('Status', application['status']),
              if (application['submission_date'] != null)
                _buildInfoRow('Submitted', application['submission_date']),
              SizedBox(height: 24.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF5B6BF8),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
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

  Widget _buildStatusRow(String label, String status) {
    final Color statusColor =
        status.toLowerCase() == 'approved'
            ? Colors.green
            : status.toLowerCase() == 'rejected'
            ? Colors.red
            : status.toLowerCase() == 'pending'
            ? Colors.amber.shade700
            : Colors.blue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: statusColor,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not provided',
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> fetchApplications() async {
    isLoading.value = true;

    try {
      final employerId = supabase.auth.currentUser?.id;
      print('DEBUG: Current employer ID: $employerId');

      if (employerId == null) {
        print('DEBUG: No user ID found');
        applications.value = [];
        isLoading.value = false;
        return;
      }

      // Fetch job listings for the current employer
      final jobListingsResponse = await supabase
          .from('worker_job_listings')
          .select('*')
          .eq('user_id', employerId);

      print(
        'DEBUG: Employer Job Listings Count: ${jobListingsResponse.length}',
      );

      // Extract shift IDs from employer's job listings
      final employerShiftIds =
          jobListingsResponse.map((job) => job['shift_id'].toString()).toList();

      print('DEBUG: Employer Shift IDs: $employerShiftIds');

      // Fetch worker job applications for these shift IDs
      final applicationsResponse = await supabase
          .from('worker_job_applications')
          .select('*')
          .inFilter('shift_id', employerShiftIds)
          .order('application_date', ascending: true);

      print(
        'DEBUG: Matching Applications Count: ${applicationsResponse.length}',
      );

      // Process applications
      List<Map<String, dynamic>> processedApplications = [];

      for (var app in applicationsResponse) {
        // Find matching job listing
        final matchingJob = jobListingsResponse.firstWhere(
          (job) => job['shift_id'].toString() == app['shift_id'].toString(),
          // orElse: () => null,
        );

        if (matchingJob != null) {
          processedApplications.add({
            ...app,
            ...matchingJob,
            'id': app['id'], // Ensure the original application ID is preserved
            'worker_id':
                app['user_id'] ??
                matchingJob['user_id'], // Ensure worker ID is present
            'job_title':
                matchingJob['job_title'] ?? app['job_title'] ?? 'Unknown Job',
            'company':
                matchingJob['company'] ?? app['company'] ?? 'Unknown Company',
            'location':
                matchingJob['location'] ??
                app['location'] ??
                'Unknown Location',
            'formatted_date': _formatDate(app['date']),
            'pay_rate': app['pay_rate'] ?? matchingJob['pay_rate'] ?? 0,
            'status': app['application_status'] ?? 'Applied',
          });
        }
      }

      applications.value = processedApplications;
      print('Final Processed Applications Count: ${applications.length}');
    } catch (e) {
      print('CRITICAL FETCH ERROR: $e');
      applications.value = [];
    } finally {
      isLoading.value = false;
    }
  }

  // Helper method for date formatting
  String _formatDate(dynamic dateInput) {
    if (dateInput == null) return 'No date specified';
    try {
      final date = DateTime.parse(dateInput.toString());
      return DateFormat('MMMM d, yyyy').format(date);
    } catch (e) {
      print('Date parsing error: $e');
      return 'Invalid date';
    }
  }

  List<Map<String, dynamic>> get filteredApplications {
    if (searchQuery.isEmpty) {
      return applications;
    }

    final query = searchQuery.toLowerCase();
    return applications.where((app) {
      final shiftId = app['shift_id']?.toString().toLowerCase() ?? '';
      return shiftId.contains(query);
    }).toList();
  }

  // Method to update search query
  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }
}

class WorkerApplicationsScreen extends StatelessWidget {
  const WorkerApplicationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final WorkerApplicationsController controller = Get.put(
      WorkerApplicationsController(),
    );
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: StandardAppBar(
        onBackPressed: () {
          Get.off(() => EmployerDashboard());
        },
        title: 'Worker Applications',
        centerTitle: false,
      ),
      bottomNavigationBar: const ShiftHourBottomNavigation(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search by Job ID
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Applications',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: controller.updateSearchQuery,
                      decoration: InputDecoration(
                        hintText: 'Enter Job ID (e.g., SH-1767)',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              // In your WorkerApplicationsScreen class, replace the Expanded section in the build method with this:

              // Applications List
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (controller.applications.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: controller.refreshApplications,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(child: _buildEmptyState(theme)),
                          ),
                        ],
                      ),
                    );
                  }

                  final applications = controller.filteredApplications;

                  if (applications.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: controller.refreshApplications,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No applications found with that Job ID',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: controller.refreshApplications,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: applications.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final application = applications[index];
                        return _buildApplicationCard(
                          context,
                          application,
                          controller,
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_off_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No applications found', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'You haven\'t applied for any jobs yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  //
  Widget _buildApplicationCard(
    BuildContext context,
    Map<String, dynamic> application,
    WorkerApplicationsController controller,
  ) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appId = application['id'].toString();

    // Initialize the status in our cache if it doesn't exist yet
    if (!controller.checkInStatuses.containsKey(appId)) {
      controller.checkInStatuses[appId] = RxString('loading');

      // Fetch the initial status
      controller.getCheckInStatus(application).then((status) {
        // The status will be updated in the cache by getCheckInStatus
      });
    }

    // Determine application status color
    final status = application['application_status'] ?? 'Applied';
    Color statusColor;

    switch (status.toString().toLowerCase()) {
      case 'accepted':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        break;
      case 'in progress':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.blue;
    }

    // Check if cancelled or status is upcoming
    final bool isCancelled = status.toString().toLowerCase() == 'cancelled';
    final bool isCompleted = status.toString().toLowerCase() == 'completed';
    final bool isInProgress = status.toString().toLowerCase() == 'in progress';
    final bool isUpcoming = controller.isUpcomingShift(application);
    // In the _buildApplicationCard method, add this before the Wrap widget:
    print('Application ID: ${application['id']}');
    print('Status: ${application['application_status']}');
    print('Is Upcoming: $isUpcoming');
    print('Is Cancelled: $isCancelled');
    print('Is Completed: $isCompleted');
    print('Is In Progress: $isInProgress');
    print(
      'Date fields: date=${application['date']}, shift_date=${application['shift_date']}',
    );
    print(
      'Time fields: start_time=${application['start_time']}, shift_start_time=${application['shift_start_time']}',
    );
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job ID and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Shift ID: ${application['shift_id']}',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  application['formatted_date'],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Job Title
            Text(
              application['job_title'],
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Company and Location
            Row(
              children: [
                Icon(
                  Icons.business,
                  size: 18,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  application['company'],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.location_on,
                  size: 18,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    application['location'],
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Pay Rate and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${application['pay_rate']}/Day',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Buttons Row
            Wrap(
              spacing: 8, // horizontal spacing
              runSpacing: 8, // vertical spacing between "runs" or rows
              alignment: WrapAlignment.end,
              children: [
                // Cancel Shift Button - Show only for upcoming shifts that are not cancelled
                // Cancel Shift Button - Show only for upcoming shifts that are not cancelled
                // In the _buildApplicationCard method, modify the condition to:
                if (application['application_status'] == 'Upcoming')
                  ElevatedButton(
                    onPressed:
                        () => controller.cancelShift(application, context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: Text('Cancel Shift'),
                  ),
                // View Details Button
                ElevatedButton(
                  onPressed: () => controller.viewDetails(application),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                  ),
                  child: Text('View Details'),
                ),
                // Check-in/out Button
                // Only show if not cancelled
                if (!isCancelled)
                  Obx(() {
                    // Get current status from our cache
                    final checkStatus =
                        controller.checkInStatuses[appId]?.value ?? 'loading';

                    // Show loading spinner while fetching initial status
                    if (checkStatus == 'loading') {
                      return ElevatedButton(
                        onPressed: null,
                        child: Text('Loading...'),
                      );
                    }

                    // If already checked out, show Done with a grey color
                    if (checkStatus == 'checked_out') {
                      return Container();
                    }

                    // Check if this application is in loading state (during check-in/out)
                    final isLoading = controller.checkInLoading[appId] == true;

                    // Show loading button while performing check-in/out
                    if (isLoading) {
                      return ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              checkStatus == 'checked_in'
                                  ? Colors.red
                                  : Colors.green,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Processing...'),
                          ],
                        ),
                      );
                    }

                    // Regular button for check-in or check-out
                    return ElevatedButton(
                      onPressed: () async {
                        await controller.checkIn(application, context);
                        await controller.refreshApplications();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            checkStatus == 'checked_in'
                                ? Colors.red
                                : Colors.green,
                      ),
                      child: Text(
                        checkStatus == 'checked_in' ? 'Check Out' : 'Check In',
                      ),
                    );
                  }),
              ],
            ),
            const SizedBox(height: 12),

            // Application Details
            if (application['notes'] != null &&
                application['notes'].toString().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Application Notes:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(application['notes'], style: theme.textTheme.bodyMedium),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
