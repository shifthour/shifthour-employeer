// File: common/bottom_navigation.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shifthour_employeer/Employer/Employee%20%20workers/Eworkers_dashboard.dart';
import 'package:shifthour_employeer/Employer/Manage%20Jobs/manage_jobs_dashboard.dart';
import 'package:shifthour_employeer/Employer/employeer_profile.dart';
import 'package:shifthour_employeer/Employer/employer_dashboard.dart';
import 'package:shifthour_employeer/Employer/payments/employeer_payments_dashboard.dart';

// GetX controller for navigation
class NavigationController extends GetxController {
  // Observable for current index
  final RxInt currentIndex = 0.obs;

  // Method to change the selected index
  void changePage(int index) {
    currentIndex.value = index;
    navigateToPage(index);
  }

  // Method to handle navigation based on index
  void navigateToPage(int index) {
    switch (index) {
      case 0:
        // Navigate to Home (WorkerDashboard)
        Get.offAll(() => const EmployerDashboard());
        break;
      case 1:
        // Navigate to Shifts (FindJobsPage)
        Get.offAll(() => const Manage_Jobs_HomePage());
        break;
      case 2:
        // Navigate to Earnings Dashboard
        Get.offAll(() => const EmployerWorkersScreen());
        break;
      case 3:
        // Navigate to Earnings Dashboard
        Get.offAll(() => const PaymentsScreen());
        break;
      case 4:
        // Navigate to Profile screen
        Get.offAll(() => const EmployerProfileScreen());
        break;
    }
  }
}

// This is the shared bottom navigation component using GetX
class ShiftHourBottomNavigation extends StatelessWidget {
  const ShiftHourBottomNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the controller
    final NavigationController controller = Get.put(NavigationController());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Obx(
        () => BottomNavigationBar(
          currentIndex: controller.currentIndex.value,
          onTap: controller.changePage,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue.shade700,
          unselectedItemColor: Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.work_outline_rounded),
              activeIcon: Icon(Icons.work_outline_rounded),
              label: 'Shifts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_outline_rounded),
              label: 'Workers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Payments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
          elevation: 0,
        ),
      ),
    );
  }
}

// Helper mixin that can be used in pages
mixin NavigationMixin {
  // Method to set the current tab when entering a page
  void setCurrentTab(int index) {
    // Get the navigation controller and update the index
    // without triggering navigation
    final controller = Get.find<NavigationController>();
    controller.currentIndex.value = index;
  }
}

// Example of how to use the mixin in a page
/*
class WorkerDashboard extends StatelessWidget with NavigationMixin {
  const WorkerDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Set the current tab to Home (index 0)
    setCurrentTab(0);
    
    return Scaffold(
      // Your page content here
      bottomNavigationBar: const ShiftHourBottomNavigation(),
    );
  }
}
*/
