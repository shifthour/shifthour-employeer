// File: common/bottom_navigation.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shifthour_employeer/Employer/Employee%20%20workers/Eworkers_dashboard.dart';
import 'package:shifthour_employeer/Employer/Manage%20Jobs/manage_jobs_dashboard.dart';
import 'package:shifthour_employeer/Employer/employeer_profile.dart';
import 'package:shifthour_employeer/Employer/employer_dashboard.dart';
import 'package:shifthour_employeer/Employer/payments/employeer_payments_dashboard.dart';

// GetX controller for navigation with permanent flag
class NavigationController extends GetxController {
  // Make this controller permanent to avoid recreation
  static NavigationController get to => Get.find();

  // Observable for current index
  final RxInt currentIndex = 0.obs;

  // Flag to control if navigation should happen
  final RxBool enableNavigation = true.obs;

  // Method to change the selected index
  void changePage(int index) {
    // Update the index
    currentIndex.value = index;

    // Only navigate if navigation is enabled
    if (enableNavigation.value) {
      navigateToPage(index);
    }
  }

  // Method to handle navigation based on index
  void navigateToPage(int index) {
    switch (index) {
      case 0:
        Get.off(() => const EmployerDashboard(), preventDuplicates: true);
        break;
      case 1:
        Get.off(() => const Manage_Jobs_HomePage(), preventDuplicates: true);
        break;
      case 2:
        Get.off(
          () => const WorkerApplicationsScreen(),
          preventDuplicates: true,
        );
        break;
      case 3:
        Get.off(() => const PaymentsScreen(), preventDuplicates: true);
        break;
      case 4:
        Get.off(() => const EmployerProfileScreen(), preventDuplicates: true);
        break;
    }
  }

  // Helper method to safely set current tab without navigation
  void setTabWithoutNavigation(int index) {
    // Temporarily disable navigation
    enableNavigation.value = false;

    // Set the index
    currentIndex.value = index;

    // Re-enable navigation after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      enableNavigation.value = true;
    });
  }
}

// This is the shared bottom navigation component using GetX
class ShiftHourBottomNavigation extends StatelessWidget {
  const ShiftHourBottomNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Put the controller with permanent flag
    final NavigationController controller = Get.put(
      NavigationController(),
      permanent: true, // This makes it permanent
    );

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
    try {
      // Try to find the existing controller
      final controller = Get.find<NavigationController>();
      // Use the safer method instead of directly setting the value
      controller.setTabWithoutNavigation(index);
    } catch (e) {
      // If not found, put a new permanent one
      final controller = Get.put(NavigationController(), permanent: true);
      controller.setTabWithoutNavigation(index);
    }
  }
}
