import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shifthour_employeer/Employer/employer_dashboard.dart';
import 'package:shifthour_employeer/Employer/payments/payments.model.dart';
import 'package:shifthour_employeer/const/Bottom_Navigation.dart';
import 'package:shifthour_employeer/const/Standard_Appbar.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFieldFocusNode = FocusNode();
  final PaymentsController _paymentsController = Get.put(PaymentsController());

  // Tab controller for wallet/payments tabs
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['Payments', 'Wallet'];

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
    _searchController.dispose();
    _searchFieldFocusNode.dispose();
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

            // Tabs for Payments and Wallet
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children:
                    _tabs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final title = entry.value;
                      final isSelected = _selectedTabIndex == index;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTabIndex = index;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.shade700 : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child:
                  _selectedTabIndex == 0
                      ? _buildPaymentsTab(context, isSmallScreen)
                      : _buildWalletTab(context, isSmallScreen),
            ),
          ],
        ),
      ),
    );
  }

  // Payments Tab
  Widget _buildPaymentsTab(BuildContext context, bool isSmallScreen) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Process Payment Button
          ElevatedButton.icon(
            onPressed: () {
              _showProcessPaymentDialog();
            },
            icon: Icon(Icons.currency_rupee, color: Colors.white, size: 15),
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
          Obx(
            () => Container(
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
                    value: _paymentsController.formatCurrency(
                      _paymentsController.totalPayments.value,
                    ),
                    color: Colors.blue.shade700,
                  ),
                  SizedBox(height: 12),
                  _buildStatRow(
                    context,
                    title: 'Pending',
                    value: _paymentsController.formatCurrency(
                      _paymentsController.pendingPayments.value,
                    ),
                    color: Colors.amber.shade700,
                  ),
                  SizedBox(height: 12),
                  _buildStatRow(
                    context,
                    title: 'This Month',
                    value: _paymentsController.formatCurrency(
                      _paymentsController.monthlyPayments.value,
                    ),
                    color: Colors.green.shade600,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Search Bar
          TextField(
            controller: _searchController,
            focusNode: _searchFieldFocusNode,
            decoration: InputDecoration(
              labelText: 'Search payments',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              // Implement search functionality
            },
          ),
          const SizedBox(height: 16),

          // Filter Button
          ElevatedButton.icon(
            onPressed: () {
              // Show filter options
              _showFilterDialog();
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
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusTab(
                  'Pending',
                  isSelected:
                      _paymentsController.selectedStatus.value ==
                      PaymentStatus.pending,
                  onTap:
                      () => _paymentsController.changeStatus(
                        PaymentStatus.pending,
                      ),
                ),
                _buildStatusTab(
                  'Processing',
                  isSelected:
                      _paymentsController.selectedStatus.value ==
                      PaymentStatus.processing,
                  onTap:
                      () => _paymentsController.changeStatus(
                        PaymentStatus.processing,
                      ),
                ),
                _buildStatusTab(
                  'Completed',
                  isSelected:
                      _paymentsController.selectedStatus.value ==
                      PaymentStatus.completed,
                  onTap:
                      () => _paymentsController.changeStatus(
                        PaymentStatus.completed,
                      ),
                ),
                _buildStatusTab(
                  'Failed',
                  isSelected:
                      _paymentsController.selectedStatus.value ==
                      PaymentStatus.failed,
                  onTap:
                      () => _paymentsController.changeStatus(
                        PaymentStatus.failed,
                      ),
                ),
              ],
            ),
          ),
          Container(
            height: 2,
            width: double.infinity,
            color: Colors.amber.shade700,
            margin: EdgeInsets.symmetric(vertical: 8),
          ),

          // Payment Items
          Obx(() {
            if (_paymentsController.isLoading.value) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final filteredPayments = _paymentsController.getPaymentsByStatus(
              _paymentsController.selectedStatus.value,
            );

            if (filteredPayments.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No ${_paymentsController.selectedStatus.value.name} payments',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children:
                  filteredPayments.map((payment) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildPaymentItem(context, payment: payment),
                    );
                  }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // Wallet Tab
  Widget _buildWalletTab(BuildContext context, bool isSmallScreen) {
    return SingleChildScrollView(
      child: Obx(() {
        if (_paymentsController.isLoading.value) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 100.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_paymentsController.error.value.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 100.0),
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error loading wallet data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(_paymentsController.error.value),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _paymentsController.fetchWalletData();
                      _paymentsController.fetchTransactions();
                      _paymentsController.fetchPaymentMethods();
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!_paymentsController.hasWallet()) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 100.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No Wallet Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('You don\'t have a wallet set up yet.'),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // This would typically open a setup wallet flow
                      Get.snackbar(
                        'Coming Soon',
                        'Wallet setup will be available soon.',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                    icon: Icon(Icons.add),
                    label: Text('Setup Wallet'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Balance Card
            _buildWalletBalanceCard(),
            SizedBox(height: 24),

            // Payment Methods Section
            Text(
              'Payment Methods',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter Tight',
              ),
            ),
            SizedBox(height: 16),

            // Payment Methods Cards
            _paymentsController.paymentMethods.isEmpty
                ? _buildNoPaymentMethodsCard()
                : Column(
                  children:
                      _paymentsController.paymentMethods.map((method) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildPaymentMethodCard(
                            icon: _getPaymentMethodIcon(method['method_type']),
                            title: method['display_name'],
                            subtitle:
                                method['expiry_date'] != null
                                    ? 'Expires ${method['expiry_date']}'
                                    : method['provider'],
                            isDefault: method['is_default'],
                          ),
                        );
                      }).toList(),
                ),

            SizedBox(height: 24),

            // Add Payment Method Button
            OutlinedButton.icon(
              onPressed: () {
                _showAddPaymentMethodDialog();
              },
              icon: Icon(Icons.add),
              label: Text('Add Payment Method'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade700),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 24),

            // Recent Transactions Section
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter Tight',
              ),
            ),
            SizedBox(height: 16),

            // Transaction Items
            _paymentsController.transactions.isEmpty
                ? _buildNoTransactionsCard()
                : Column(
                  children:
                      _paymentsController.transactions.take(3).map((
                        transaction,
                      ) {
                        final amount = transaction['amount'] as num;
                        final isCredit = amount > 0;
                        final formattedAmount =
                            isCredit
                                ? '+${_paymentsController.formatCurrency(amount.toDouble())}'
                                : _paymentsController.formatCurrency(
                                  amount.toDouble(),
                                );

                        final createdAt = DateTime.parse(
                          transaction['created_at'],
                        );
                        final formattedDate = DateFormat(
                          'MMM dd, yyyy',
                        ).format(createdAt);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTransactionItem(
                            title:
                                transaction['description'] ??
                                transaction['transaction_type']
                                    .toString()
                                    .capitalize!,
                            amount: formattedAmount,
                            date: formattedDate,
                            isCredit: isCredit,
                          ),
                        );
                      }).toList(),
                ),

            SizedBox(height: 24),

            // View All Transactions Button
            Center(
              child: TextButton(
                onPressed: () {
                  _showAllTransactionsDialog();
                },
                child: Text(
                  'View All Transactions',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // Wallet Balance Card
  Widget _buildWalletBalanceCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5B6BF8), Color(0xFF8B65D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Business Wallet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: () => _paymentsController.fetchWalletData(),
                tooltip: 'Refresh wallet data',
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            'Available Balance',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 8),
          Text(
            _paymentsController.getFormattedWalletBalance(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter Tight',
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWalletButton(
                icon: Icons.add,
                label: 'Add Funds',
                onPressed: () => _showAddFundsDialog(),
              ),
              _buildWalletButton(
                icon: Icons.arrow_outward,
                label: 'Withdraw',
                onPressed: () => _showWithdrawDialog(),
              ),
              _buildWalletButton(
                icon: Icons.history,
                label: 'History',
                onPressed: () => _showAllTransactionsDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // No payment methods card
  Widget _buildNoPaymentMethodsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No Payment Methods',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Add a payment method to easily add funds to your wallet.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // No transactions card
  Widget _buildNoTransactionsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No Transactions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Your transaction history will appear here.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Wallet action button
  Widget _buildWalletButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Payment method card
  Widget _buildPaymentMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isDefault = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
          if (isDefault)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Default',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
              onPressed: () {
                // Show options for this payment method
                _showPaymentMethodOptionsDialog(title);
              },
            ),
        ],
      ),
    );
  }

  // Transaction item
  Widget _buildTransactionItem({
    required String title,
    required String amount,
    required String date,
    required bool isCredit,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCredit ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  date,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Payment item
  Widget _buildPaymentItem(BuildContext context, {required Payment payment}) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar or initials
              CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  payment.workerName[0],
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
                    Text(
                      payment.workerName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Worker ID: ${payment.workerId}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Amount and date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _paymentsController.formatCurrency(payment.amount),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    _paymentsController.formatDate(payment.dueDate),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),

          // Only show actions for pending payments
          if (payment.status == PaymentStatus.pending)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      // Show payment details
                      _showPaymentDetailsDialog(payment);
                    },
                    child: Text('Details'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Process this payment
                      _processPayment(payment);
                    },
                    child: Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // For other statuses, show status badge
          if (payment.status != PaymentStatus.pending)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      // Show payment details
                      _showPaymentDetailsDialog(payment);
                    },
                    child: Text('Details'),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(payment.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      payment.status.name,
                      style: TextStyle(
                        color: _getStatusColor(payment.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
  Widget _buildStatusTab(
    String label, {
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.amber.shade700 : Colors.grey.shade600,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // Get payment method icon based on type
  IconData _getPaymentMethodIcon(String type) {
    switch (type) {
      case 'credit_card':
      case 'debit_card':
        return Icons.credit_card;
      case 'bank_account':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  // Get status color
  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return Colors.amber.shade700;
      case PaymentStatus.processing:
        return Colors.blue.shade700;
      case PaymentStatus.completed:
        return Colors.green.shade700;
      case PaymentStatus.failed:
        return Colors.red.shade700;
    }
  }

  // Show all transactions dialog
  void _showAllTransactionsDialog() {
    Get.dialog(
      Dialog(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Transaction History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (_paymentsController.transactions.isEmpty)
                  _buildNoTransactionsCard()
                else
                  ...(_paymentsController.transactions.map((transaction) {
                    final amount = transaction['amount'] as num;
                    final isCredit = amount > 0;
                    final formattedAmount =
                        isCredit
                            ? '+${_paymentsController.formatCurrency(amount.toDouble())}'
                            : _paymentsController.formatCurrency(
                              amount.toDouble(),
                            );

                    final createdAt = DateTime.parse(transaction['created_at']);
                    final formattedDate = DateFormat(
                      'MMM dd, yyyy',
                    ).format(createdAt);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTransactionItem(
                        title:
                            transaction['description'] ??
                            transaction['transaction_type']
                                .toString()
                                .capitalize!,
                        amount: formattedAmount,
                        date: formattedDate,
                        isCredit: isCredit,
                      ),
                    );
                  }).toList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show add funds dialog
  void _showAddFundsDialog() {
    if (!_paymentsController.hasPaymentMethods()) {
      Get.snackbar(
        'No Payment Methods',
        'Please add a payment method first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final TextEditingController amountController = TextEditingController();
    final defaultMethodId = _paymentsController.getDefaultPaymentMethodId();

    if (defaultMethodId == null) {
      Get.snackbar(
        'Error',
        'No default payment method found.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.dialog(
      Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Funds',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Icon(Icons.credit_card),
                  title: Text(
                    _paymentsController.paymentMethods.firstWhere(
                      (method) => method['id'] == defaultMethodId,
                    )['display_name'],
                  ),
                  subtitle: Text('Default payment method'),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Default',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (amountController.text.isEmpty) {
                        Get.snackbar(
                          'Error',
                          'Please enter an amount.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }

                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        Get.snackbar(
                          'Error',
                          'Please enter a valid amount.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }

                      Get.back();
                      _paymentsController
                          .addFundsToWallet(amount, defaultMethodId)
                          .then((success) {
                            if (success) {
                              Get.snackbar(
                                'Success',
                                'Funds added successfully.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.green.shade100,
                                colorText: Colors.green.shade700,
                              );
                            } else {
                              Get.snackbar(
                                'Error',
                                _paymentsController.error.value.isEmpty
                                    ? 'Failed to add funds.'
                                    : _paymentsController.error.value,
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red.shade100,
                                colorText: Colors.red.shade700,
                              );
                            }
                          });
                    },
                    child: Text('Add Funds'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show withdraw dialog
  void _showWithdrawDialog() {
    if (!_paymentsController.hasPaymentMethods()) {
      Get.snackbar(
        'No Payment Methods',
        'Please add a payment method first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final TextEditingController amountController = TextEditingController();
    final defaultMethodId = _paymentsController.getDefaultPaymentMethodId();

    if (defaultMethodId == null) {
      Get.snackbar(
        'Error',
        'No default payment method found.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final walletBalance = _paymentsController.walletData.value!['balance'];
    final numBalance =
        walletBalance is int
            ? walletBalance.toDouble()
            : walletBalance as double;

    Get.dialog(
      Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Withdraw Funds',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Available Balance: ${_paymentsController.formatCurrency(numBalance)}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Icon(Icons.credit_card),
                  title: Text(
                    _paymentsController.paymentMethods.firstWhere(
                      (method) => method['id'] == defaultMethodId,
                    )['display_name'],
                  ),
                  subtitle: Text('Default payment method'),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Default',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (amountController.text.isEmpty) {
                        Get.snackbar(
                          'Error',
                          'Please enter an amount.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }

                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        Get.snackbar(
                          'Error',
                          'Please enter a valid amount.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }

                      if (amount > numBalance) {
                        Get.snackbar(
                          'Error',
                          'Insufficient balance.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }

                      Get.back();
                      _paymentsController
                          .withdrawFunds(amount, defaultMethodId)
                          .then((success) {
                            if (success) {
                              Get.snackbar(
                                'Success',
                                'Funds withdrawn successfully.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.green.shade100,
                                colorText: Colors.green.shade700,
                              );
                            } else {
                              Get.snackbar(
                                'Error',
                                _paymentsController.error.value.isEmpty
                                    ? 'Failed to withdraw funds.'
                                    : _paymentsController.error.value,
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red.shade100,
                                colorText: Colors.red.shade700,
                              );
                            }
                          });
                    },
                    child: Text('Withdraw'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show payment method options dialog
  void _showPaymentMethodOptionsDialog(String paymentMethodTitle) {
    Get.dialog(
      Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paymentMethodTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Set as Default'),
                onTap: () {
                  Get.back();
                  // Implement set as default
                  Get.snackbar(
                    'Coming Soon',
                    'This feature will be available soon.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Remove'),
                onTap: () {
                  Get.back();
                  // Implement remove
                  Get.dialog(
                    AlertDialog(
                      title: Text('Remove Payment Method'),
                      content: Text(
                        'Are you sure you want to remove this payment method?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Get.back();
                            // Implement remove
                            Get.snackbar(
                              'Coming Soon',
                              'This feature will be available soon.',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          },
                          child: Text('Remove'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show add payment method dialog
  void _showAddPaymentMethodDialog() {
    final TextEditingController cardNumberController = TextEditingController();
    final TextEditingController cardholderNameController =
        TextEditingController();
    final TextEditingController expiryDateController = TextEditingController();
    final TextEditingController cvvController = TextEditingController();

    Get.dialog(
      Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Payment Method',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: cardNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Card Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: cardholderNameController,
                  decoration: InputDecoration(
                    labelText: 'Cardholder Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: expiryDateController,
                        keyboardType: TextInputType.datetime,
                        decoration: InputDecoration(
                          labelText: 'Expiry Date (MM/YY)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: cvvController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'CVV',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green.shade700,
                    ),
                    SizedBox(width: 8),
                    Text('Set as default payment method'),
                  ],
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text('Cancel'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Validate fields
                        if (cardNumberController.text.isEmpty ||
                            cardholderNameController.text.isEmpty ||
                            expiryDateController.text.isEmpty ||
                            cvvController.text.isEmpty) {
                          Get.snackbar(
                            'Error',
                            'Please fill all fields.',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                          return;
                        }

                        Get.back();
                        // Implement add payment method
                        Get.snackbar(
                          'Coming Soon',
                          'Adding payment methods will be available soon.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                      child: Text('Add Card'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show payment details dialog
  void _showPaymentDetailsDialog(Payment payment) {
    Get.dialog(
      Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              _buildDetailRow('Payment ID', payment.id),
              _buildDetailRow('Worker Name', payment.workerName),
              _buildDetailRow('Worker ID', payment.workerId),
              _buildDetailRow(
                'Amount',
                _paymentsController.formatCurrency(payment.amount),
              ),
              _buildDetailRow(
                'Due Date',
                DateFormat('MMM dd, yyyy').format(payment.dueDate),
              ),
              _buildDetailRow('Status', payment.status.name),
              if (payment.jobReference != null)
                _buildDetailRow('Job Reference', payment.jobReference!),
              if (payment.hoursWorked != null)
                _buildDetailRow(
                  'Hours Worked',
                  payment.hoursWorked!.toString(),
                ),
              if (payment.paymentMethod != null)
                _buildDetailRow('Payment Method', payment.paymentMethod!),
              if (payment.transactionId != null)
                _buildDetailRow('Transaction ID', payment.transactionId!),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Get.back(), child: Text('Close')),
                  if (payment.status == PaymentStatus.pending)
                    SizedBox(width: 8),
                  if (payment.status == PaymentStatus.pending)
                    ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _processPayment(payment);
                      },
                      child: Text('Pay Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
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

  // Build detail row
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  // Process payment
  void _processPayment(Payment payment) {
    // Check if wallet has sufficient balance
    if (!_paymentsController.hasWallet()) {
      Get.snackbar(
        'No Wallet',
        'You need to set up a wallet first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final walletBalance = _paymentsController.walletData.value!['balance'];
    final numBalance =
        walletBalance is int
            ? walletBalance.toDouble()
            : walletBalance as double;

    if (numBalance < payment.amount) {
      Get.snackbar(
        'Insufficient Balance',
        'Your wallet does not have enough funds. Please add funds first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        title: Text('Process Payment'),
        content: Text(
          'Are you sure you want to process payment of ${_paymentsController.formatCurrency(payment.amount)} to ${payment.workerName}?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _paymentsController.processPayment(payment.id).then((success) {
                if (success) {
                  Get.snackbar(
                    'Success',
                    'Payment processed successfully.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.shade100,
                    colorText: Colors.green.shade700,
                  );
                } else {
                  Get.snackbar(
                    'Error',
                    _paymentsController.error.value.isEmpty
                        ? 'Failed to process payment.'
                        : _paymentsController.error.value,
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.shade100,
                    colorText: Colors.red.shade700,
                  );
                }
              });
            },
            child: Text('Process Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Show process payment dialog
  void _showProcessPaymentDialog() {
    if (!_paymentsController.hasWallet()) {
      Get.snackbar(
        'No Wallet',
        'You need to set up a wallet first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final pendingPayments = _paymentsController.getPaymentsByStatus(
      PaymentStatus.pending,
    );

    if (pendingPayments.isEmpty) {
      Get.snackbar(
        'No Pending Payments',
        'There are no pending payments to process.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.dialog(
      Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Process Payment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Select a payment to process:'),
              SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children:
                        pendingPayments.map((payment) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                payment.workerName[0],
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(payment.workerName),
                            subtitle: Text(
                              _paymentsController.formatDate(payment.dueDate),
                            ),
                            trailing: Text(
                              _paymentsController.formatCurrency(
                                payment.amount,
                              ),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onTap: () {
                              Get.back();
                              _processPayment(payment);
                            },
                          );
                        }).toList(),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show filter dialog
  void _showFilterDialog() {
    Get.dialog(
      Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Payments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Date Range'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text('Amount Range'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Min Amount',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Max Amount',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Get.back();
                      Get.snackbar(
                        'Coming Soon',
                        'Advanced filtering will be available soon.',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                    child: Text('Apply Filters'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
