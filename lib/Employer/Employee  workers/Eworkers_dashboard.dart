import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shifthour_employeer/Employer/employer_dashboard.dart';
import 'package:shifthour_employeer/const/Bottom_Navigation.dart';
import 'package:shifthour_employeer/const/Standard_Appbar.dart';

class EmployerWorkersController extends GetxController {
  // Reactive variables for state management
  final RxString selectedCategory = 'All'.obs;
  final RxList<Worker> workers =
      <Worker>[
        Worker(
          name: 'Alex Johnson',
          role: 'Carpenter',
          isVerified: true,
          profileColor: Colors.blue.shade100,
        ),
        Worker(
          name: 'Sarah Williams',
          role: 'Electrician',
          isVerified: true,
          profileColor: Colors.green.shade100,
        ),
        Worker(
          name: 'Michael Chen',
          role: 'Plumber',
          isVerified: true,
          profileColor: Colors.orange.shade100,
        ),
      ].obs;

  // Method to change selected category
  void selectCategory(String category) {
    selectedCategory.value = category;
  }
}

// Worker model to represent worker details
class Worker {
  final String name;
  final String role;
  final bool isVerified;
  final Color profileColor;

  Worker({
    required this.name,
    required this.role,
    this.isVerified = false,
    required this.profileColor,
  });
}

class EmployerWorkersScreen extends StatelessWidget {
  const EmployerWorkersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final EmployerWorkersController controller = Get.put(
      EmployerWorkersController(),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: StandardAppBar(
        onBackPressed: () {
          Get.off(() => EmployerDashboard());
        },

        title: 'Worker Management',
        subtitle: 'Manage your workforce efficiently',
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
            child: IconButton(
              icon: const Icon(Icons.download, size: 16, color: Colors.blue),
              onPressed: () {},
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Obx(
                  () => Row(
                    children: [
                      _buildCategoryChip(controller, 'All', Icons.people_alt),
                      _buildCategoryChip(
                        controller,
                        'Shortlisted',
                        Icons.star_border,
                      ),
                      _buildCategoryChip(
                        controller,
                        'Hired',
                        Icons.check_circle_outline,
                      ),
                      _buildCategoryChip(controller, 'Rejected', Icons.block),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Recent Workers Title
              Text('Recent Workers', style: theme.textTheme.titleMedium),

              const SizedBox(height: 8),

              // Workers List
              Expanded(
                child: Obx(
                  () => ListView.separated(
                    itemCount: controller.workers.length,
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final worker = controller.workers[index];
                      return _buildWorkerCard(context, worker);
                    },
                  ),
                ),
              ),

              // Quick Actions
              Text('Quick Actions', style: theme.textTheme.titleMedium),

              const SizedBox(height: 8),

              // Quick Action Buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickActionButton(
                      context,
                      icon: Icons.calendar_today,
                      label: 'Schedule\nInterviews',
                      onTap: () {
                        // TODO: Implement interview scheduling
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildQuickActionButton(
                      context,
                      icon: Icons.payments,
                      label: 'Process\nPayments',
                      onTap: () {
                        // TODO: Implement payment processing
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildQuickActionButton(
                      context,
                      icon: Icons.location_on,
                      label: 'Track\nWorkers',
                      onTap: () {
                        // TODO: Implement worker tracking
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: Theme.of(context).primaryColor),
        onPressed: onPressed,
        iconSize: 20,
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildCategoryChip(
    EmployerWorkersController controller,
    String label,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: controller.selectedCategory.value == label,
        onSelected: (_) => controller.selectCategory(label),
        selectedColor: Theme.of(Get.context!).primaryColor.withOpacity(0.2),
        backgroundColor: Colors.grey.shade100,
      ),
    );
  }

  Widget _buildWorkerCard(BuildContext context, Worker worker) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Profile Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: worker.profileColor,
                shape: BoxShape.circle,
                border: Border.all(color: worker.profileColor.withOpacity(0.5)),
              ),
              child: Center(
                child: Text(
                  worker.name.substring(0, 2).toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: worker.profileColor.withOpacity(0.8),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Worker Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Role Chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          worker.role,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.primaryColor,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Verified Chip
                      if (worker.isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Verified',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons
            Row(
              children: [
                _buildSmallIconButton(
                  icon: Icons.message,
                  onPressed: () {
                    // TODO: Implement messaging
                  },
                ),
                const SizedBox(width: 8),
                _buildSmallIconButton(
                  icon: Icons.call,
                  onPressed: () {
                    // TODO: Implement calling
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: 110,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: theme.primaryColor, size: 24),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddWorkerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final roleController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Worker'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Worker Name',
                    hintText: 'Enter full name',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roleController,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    hintText: 'Enter worker\'s role',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      roleController.text.isNotEmpty) {
                    final controller = Get.find<EmployerWorkersController>();
                    final newWorker = Worker(
                      name: nameController.text,
                      role: roleController.text,
                      isVerified: false,
                      profileColor: Colors.grey.shade200,
                    );
                    controller.workers.add(newWorker);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Add Worker'),
              ),
            ],
          ),
    );
  }
}
