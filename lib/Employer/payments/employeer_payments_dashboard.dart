import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shifthour_employeer/Employer/employer_dashboard.dart';
import 'package:shifthour_employeer/const/Bottom_Navigation.dart';
import 'package:shifthour_employeer/const/Standard_Appbar.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Use a safer approach to set the navigation index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Directly set the tab index
        Get.find<NavigationController>().currentIndex.value = 3;
      } catch (e) {
        print('Error setting navigation tab: $e');
        // You can add fallback logic here if needed
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsiveness
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      appBar: StandardAppBar(
        onBackPressed: () {
          Get.off(() => EmployerDashboard());
        },
        title: 'Payments',
        centerTitle: false,
        actions: [
          const SizedBox(width: 12),
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
      // Use the standard bottom navigation
      bottomNavigationBar: const ShiftHourBottomNavigation(),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Payment Overview',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontFamily: 'Inter Tight'),
              ),
              const SizedBox(height: 16),

              // Process Payment Button
              ElevatedButton.icon(
                onPressed: () {
                  print('Process Payment pressed');
                },
                icon: Icon(Icons.attach_money, color: Colors.white, size: 15),
                label: Text('Process Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  minimumSize: Size(isSmallScreen ? double.infinity : 180, 40),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Stats Row
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 2,
                      color: Colors.grey.withOpacity(0.1),
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildStatRow(
                      context,
                      title: 'Total Payments',
                      value: '\$12,450.75',
                      color: Colors.blue.shade700,
                    ),
                    SizedBox(height: 12),
                    _buildStatRow(
                      context,
                      title: 'Pending',
                      value: '\$2,340.00',
                      color: Colors.amber.shade700,
                    ),
                    SizedBox(height: 12),
                    _buildStatRow(
                      context,
                      title: 'This Month',
                      value: '\$8,975.50',
                      color: Colors.green.shade600,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Search Bar
              TextField(
                controller: _textController,
                focusNode: _textFieldFocusNode,
                decoration: InputDecoration(
                  labelText: 'Search payments',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Filter Button
              ElevatedButton.icon(
                onPressed: () {
                  print('Filter pressed');
                },
                icon: Icon(Icons.filter_list),
                label: Text('Filter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.grey.shade800,
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 24),

              // Payment Status Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatusTab('Pending', isSelected: true),
                  _buildStatusTab('Processing'),
                  _buildStatusTab('Completed'),
                  _buildStatusTab('Failed'),
                ],
              ),
              Container(
                height: 2,
                width: double.infinity,
                color: Colors.amber.shade700,
                margin: EdgeInsets.symmetric(vertical: 8),
              ),

              // Payment Items
              ...List.generate(3, (index) {
                final paymentData =
                    [
                      {
                        'name': 'Sarah Johnson',
                        'id': 'W-12345',
                        'amount': '\$450.00',
                        'date': 'Due: May 15, 2023',
                      },
                      {
                        'name': 'Michael Chen',
                        'id': 'W-67890',
                        'amount': '\$720.00',
                        'date': 'Due: May 17, 2023',
                      },
                      {
                        'name': 'Emily Rodriguez',
                        'id': 'W-54321',
                        'amount': '\$325.50',
                        'date': 'Due: May 20, 2023',
                      },
                    ][index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildSimplePaymentItem(
                    context,
                    name: paymentData['name']!,
                    id: paymentData['id']!,
                    amount: paymentData['amount']!,
                    date: paymentData['date']!,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Simple stat row builder
  Widget _buildStatRow(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontFamily: 'Inter', color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter Tight',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Simple status tab builder
  Widget _buildStatusTab(String label, {bool isSelected = false}) {
    return Text(
      label,
      style: TextStyle(
        color: isSelected ? Colors.amber.shade700 : Colors.grey.shade600,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  // Simple payment item builder
  Widget _buildSimplePaymentItem(
    BuildContext context, {
    required String name,
    required String id,
    required String amount,
    required String date,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Avatar or initials
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Text(
              name[0],
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 12),
          // Name and ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Worker ID: $id',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          // Amount and date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                date,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
