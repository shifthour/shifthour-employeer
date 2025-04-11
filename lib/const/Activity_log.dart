import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityLogger {
  static final _supabase = Supabase.instance.client;

  // Generic method to log an activity
  static Future<void> logActivity({
    required String activityType,
    required String title,
    required String description,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Prepare additional data as JSONB
      final jsonbData =
          additionalData != null ? jsonEncode(additionalData) : null;

      // Call the PostgreSQL function
      await _supabase.rpc(
        'insert_recent_activity',
        params: {
          'p_user_id': user.id,
          'p_activity_type': activityType,
          'p_title': title,
          'p_description': description,
          'p_additional_data': jsonbData,
        },
      );
    } catch (e) {
      print('Error logging activity: $e');
    }
  }

  // Predefined methods for common activities
  static Future<void> logJobPosting(Map<String, dynamic> jobDetails) async {
    await logActivity(
      activityType: 'job_posted',
      title: 'New Shift Posted',
      description:
          'Posted ${jobDetails['job_title']} shift at ${jobDetails['company']}',
      additionalData: jobDetails,
    );
  }

  static Future<void> logWorkerAssignment(
    Map<String, dynamic> applicationDetails,
  ) async {
    await logActivity(
      activityType: 'worker_assigned',
      title: 'Worker Assigned',
      description:
          'Assigned ${applicationDetails['full_name']} to ${applicationDetails['job_title']}',
      additionalData: applicationDetails,
    );
  }

  static Future<void> logWorkerCheckIn(
    Map<String, dynamic> checkInDetails,
  ) async {
    await logActivity(
      activityType: 'check_in',
      title: 'Worker Check-In',
      description:
          '${checkInDetails['full_name']} checked in for ${checkInDetails['job_title']}',
      additionalData: checkInDetails,
    );
  }

  static Future<void> logWorkerCheckOut(
    Map<String, dynamic> checkOutDetails,
  ) async {
    await logActivity(
      activityType: 'check_out',
      title: 'Worker Check-Out',
      description:
          '${checkOutDetails['full_name']} checked out from ${checkOutDetails['job_title']}',
      additionalData: checkOutDetails,
    );
  }

  // Added the method inside the class
  static Future<void> logShiftCancellation(
    Map<String, dynamic> application,
  ) async {
    await logActivity(
      activityType: 'shift_cancelled',
      title: 'Shift Cancellation',
      description: 'Cancelled ${application['job_title']} shift',
      additionalData: {
        'shift_id': application['shift_id'],
        'job_title': application['job_title'],
        'company': application['company'],
      },
    );
  }
}
