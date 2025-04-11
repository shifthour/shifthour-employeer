import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:intl/intl.dart';
import 'package:shifthour_employeer/Employer/payments/employeer_payments_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostShiftScreen extends StatefulWidget {
  const PostShiftScreen({Key? key}) : super(key: key);

  @override
  State<PostShiftScreen> createState() => _PostShiftScreenState();
}

class _PostShiftScreenState extends State<PostShiftScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _ShiftTitleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _payRateController = TextEditingController();
  final TextEditingController _positionsController = TextEditingController();
  final TextEditingController _supervisorNameController =
      TextEditingController();
  final TextEditingController _supervisorPhoneController =
      TextEditingController();
  final TextEditingController _supervisorEmailController =
      TextEditingController();
  final TextEditingController _ShiftPincodeController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _dressCodeController = TextEditingController();
  final List<int> hourOptions = [4, 5, 6, 7, 8, 9]; // Shift duration options
  int? selectedHours;
  DateTime? selectedDate;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _ShiftTitleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _payRateController.dispose();
    _supervisorNameController.dispose();
    _supervisorPhoneController.dispose();
    _supervisorEmailController.dispose();
    _ShiftPincodeController.dispose();
    _websiteController.dispose();
    _dressCodeController.dispose();
    _positionsController.dispose();
    super.dispose();
  }

  // Method to pick date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF5B6BF8)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedStartTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF5B6BF8)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedStartTime) {
      setState(() {
        selectedStartTime = picked;
        _startTimeController.text = picked.format(context);

        // Reset end time and hours when start time changes
        selectedEndTime = null;
        _endTimeController.clear();
        selectedHours = null;
      });
    }
  }

  // New method to calculate end time based on start time and hours
  void _calculateEndTime() {
    if (selectedStartTime != null && selectedHours != null) {
      // Convert start time to minutes
      int startMinutes =
          selectedStartTime!.hour * 60 + selectedStartTime!.minute;

      // Add selected hours
      int endMinutes = startMinutes + (selectedHours! * 60);

      // Convert back to TimeOfDay
      int endHour = endMinutes ~/ 60;
      int endMinute = endMinutes % 60;

      // Adjust for day overflow
      endHour = endHour % 24;

      final endTime = TimeOfDay(hour: endHour, minute: endMinute);

      setState(() {
        selectedEndTime = endTime;
        _endTimeController.text = endTime.format(context);
      });
    }
  }

  Widget _buildTimeSelectionRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if we have enough width for a row layout
        if (constraints.maxWidth > 600) {
          return Row(
            children: [
              // Start Time
              Expanded(
                child: _buildTextField(
                  controller: _startTimeController,
                  label: 'Start Time',
                  hint: 'Select',
                  icon: Icons.access_time,
                  readOnly: true,
                  onTap: () => _selectStartTime(context),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Hours Dropdown
              Expanded(child: _buildHoursDropdown()),
              const SizedBox(width: 16),
              // End Time
              Expanded(
                child: _buildTextField(
                  controller: _endTimeController,
                  label: 'End Time',
                  hint: 'Calculated',
                  icon: Icons.access_time,
                  readOnly: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          );
        } else {
          // Vertical layout for smaller screens
          return Column(
            children: [
              // Start Time
              _buildTextField(
                controller: _startTimeController,
                label: 'Start Time',
                hint: 'Select',
                icon: Icons.access_time,
                readOnly: true,
                onTap: () => _selectStartTime(context),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Hours Dropdown
              _buildHoursDropdown(),
              const SizedBox(height: 16),
              // End Time
              _buildTextField(
                controller: _endTimeController,
                label: 'End Time',
                hint: 'Calculated',
                icon: Icons.access_time,
                readOnly: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ],
          );
        }
      },
    );
  }

  // Extracted hours dropdown to a separate method for reusability
  Widget _buildHoursDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shift Duration',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          isExpanded: true, // This helps prevent overflow
          value: selectedHours,
          decoration: InputDecoration(
            hintText: 'Select Hours',
            prefixIcon: Icon(Icons.timer_outlined, color: Color(0xFF5B6BF8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF5B6BF8)),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          items:
              hourOptions.map((hours) {
                return DropdownMenuItem<int>(
                  value: hours,
                  child: Text('$hours Hours'),
                );
              }).toList(),
          onChanged: (value) {
            if (selectedStartTime == null) {
              // Show a snackbar to select start time first
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please select a start time first'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            setState(() {
              selectedHours = value;
            });

            _calculateEndTime();
          },
          validator: (value) {
            if (value == null) {
              return 'Select shift duration';
            }
            return null;
          },
        ),
      ],
    );
  }

  // Method to pick end time
  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedEndTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF5B6BF8)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedEndTime) {
      setState(() {
        selectedEndTime = picked;
        _endTimeController.text = picked.format(context);
      });
    }
  }

  String _generateCustomJobId() {
    // Create a Random object for generating random numbers
    final random = Random();

    // Generate a random 4-digit number
    final randomDigits =
        random.nextInt(9000) +
        1000; // This ensures a 4-digit number (1000-9999)

    // Return the formatted job ID
    return 'SH-$randomDigits';
  }

  void _postJob() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Get the Supabase client instance
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;

        if (userId == null) {
          throw Exception('User is not logged in');
        }

        // Get the number of positions and calculate required balance
        final int numberOfPositions = int.parse(_positionsController.text);
        final double requiredBalance =
            numberOfPositions *
            (double.tryParse(_payRateController.text) ?? 0.0);

        // Check wallet balance - using employer_id instead of user_id
        final walletData =
            await supabase
                .from('employer_wallet')
                .select('id, balance, currency')
                .eq('employer_id', userId)
                .maybeSingle();

        if (walletData == null) {
          // No wallet exists
          _showNoWalletDialog();
          return;
        }

        // Parse balance (handling different types)
        final dynamic balanceValue = walletData['balance'];
        double walletBalance = 0.0;

        if (balanceValue is int) {
          walletBalance = balanceValue.toDouble();
        } else if (balanceValue is double) {
          walletBalance = balanceValue;
        } else if (balanceValue is String) {
          walletBalance = double.tryParse(balanceValue) ?? 0.0;
        }

        // Check if there's enough balance
        if (walletBalance < requiredBalance) {
          _showInsufficientBalanceDialog(requiredBalance, walletBalance);
          return;
        }

        // Show confirmation dialog for balance deduction
        final bool shouldProceed = await _showDeductionConfirmationDialog(
          requiredBalance,
        );

        if (!shouldProceed) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Create a batch ID to group related positions
        // Using a prefix "B-" followed by timestamp for easy identification
        final batchId = 'B-${DateTime.now().millisecondsSinceEpoch}';

        // List to store all created shift IDs
        final List<String> createdShiftIds = [];

        // For each position, create a separate shift record
        for (int i = 0; i < numberOfPositions; i++) {
          // Generate a unique custom job ID for each position
          final customJobId = _generateCustomJobId();

          // Prepare job data with the custom ID in shift_id
          final jobData = {
            // Do NOT set the primary 'id' field - let Supabase generate a UUID
            'shift_id': customJobId,
            'batch_id': batchId, // Add the batch ID
            'position_number':
                i + 1, // Track position number within batch (1-based)
            'job_title': _ShiftTitleController.text,
            'company': _companyController.text,
            'number_of_positions': 1, // Each record represents 1 position
            'location': _locationController.text,
            'date': _dateController.text,
            'start_time': _startTimeController.text,
            'end_time': _endTimeController.text,
            'pay_rate': double.parse(_payRateController.text),
            'pay_currency': 'INR',
            'supervisor_name': _supervisorNameController.text,
            'supervisor_phone': _supervisorPhoneController.text,
            'supervisor_email': _supervisorEmailController.text,
            'job_pincode': int.parse(_ShiftPincodeController.text),
            'website':
                _websiteController.text.isEmpty
                    ? null
                    : _websiteController.text,
            'dress_code': _dressCodeController.text,
            'status': 'Active',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'user_id': userId,
          };

          // Insert the job listing with our custom shift_id
          final jobResponse =
              await supabase
                  .from('worker_job_listings')
                  .insert(jobData)
                  .select('id, shift_id')
                  .single();

          final shiftId = jobResponse['shift_id'];
          createdShiftIds.add(shiftId);
        }

        // Deduct the amount from the wallet
        final newBalance = walletBalance - requiredBalance;
        final timestamp = DateTime.now().toIso8601String();

        await supabase
            .from('employer_wallet')
            .update({'balance': newBalance, 'last_updated': timestamp})
            .eq('id', walletData['id']);

        // Record the transaction
        await supabase.from('wallet_transactions').insert({
          'wallet_id': walletData['id'],
          'amount': -requiredBalance,
          'transaction_type': 'job_posting',
          'description':
              'Deducted for posting $numberOfPositions position(s) for ${_ShiftTitleController.text} (Batch ID: $batchId)',
          'status': 'completed',
          'created_at': timestamp,
        });

        // Show success message and navigate back
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully posted $numberOfPositions positions! ' +
                    'Batch ID: $batchId. ' +
                    '₹${requiredBalance.toStringAsFixed(2)} has been deducted from your wallet.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error posting job: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        print('Error in job posting process: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showNoWalletDialog() {
    setState(() {
      _isLoading = false;
    });

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Wallet Required'),
            content: const Text(
              'You need to set up a wallet to post Shifts. Please add funds to your wallet to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to wallet setup screen
                  // Replace with your actual wallet screen navigation
                  Get.to(() => PaymentsScreen());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text('Set Up Wallet'),
              ),
            ],
          ),
    );
  }

  // Show a dialog when balance is insufficient
  void _showInsufficientBalanceDialog(double required, double available) {
    setState(() {
      _isLoading = false;
    });

    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Insufficient Balance'),
            content: Text(
              'You need ${formatter.format(required)} to post this Shift, but your wallet only has ${formatter.format(available)}. Please add funds to your wallet to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to add funds screen
                  // Replace with your actual wallet screen navigation
                  Get.to(() => PaymentsScreen());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text('Add Funds'),
              ),
            ],
          ),
    );
  }

  // Show confirmation dialog for balance deduction
  // Show confirmation dialog for balance deduction with improved styling
  Future<bool> _showDeductionConfirmationDialog(double amount) async {
    setState(() {
      _isLoading = false;
    });

    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final int positions = int.parse(_positionsController.text);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Confirm Shift Posting',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                color: Color(0xFF1F2937),
              ),
            ),
            content: Container(
              constraints: BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Charges information
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'Inter',
                        color: Color(0xFF374151),
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: 'You will be charged '),
                        TextSpan(
                          text: formatter.format(amount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5B6BF8),
                          ),
                        ),
                        TextSpan(
                          text:
                              ' from your wallet for posting this Shift with ',
                        ),
                        TextSpan(
                          text: '$positions position(s)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Calculation details
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Breakdown:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4B5563),
                            fontFamily: 'Inter',
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Per position charge:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              _payRateController.text,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Number of positions:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              '$positions',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Divider(),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total amount:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF374151),
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              formatter.format(amount),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5B6BF8),
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Confirmation question
                  Text(
                    'Do you want to proceed with this Shift posting?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  foregroundColor: Color(0xFF6B7280),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5B6BF8),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Confirm & Post',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
            actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
    );

    setState(() {
      _isLoading = true;
    });

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      appBar: AppBar(
        title: const Text(
          'Post a New Shift',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF5B6BF8)),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF5B6BF8)),
              )
              : GestureDetector(
                onTap: () {
                  // Dismiss keyboard when tapping outside of input fields
                  FocusScope.of(context).unfocus();
                },
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5B6BF8), Color(0xFF8B65D9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 4,
                                color: const Color(0x10000000),
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Create a New Shift Listing',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter Tight',
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Fill in the details below to post a new Shift opportunity',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Form Container
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 4,
                                color: const Color(0x10000000),
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Shift Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter Tight',
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Shift Title
                              _buildTextField(
                                controller: _ShiftTitleController,
                                label: 'Shift Title',
                                hint: 'e.g. Barista, Cashier, Server',
                                icon: Icons.work_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter Shift title';
                                  }
                                  return null;
                                },
                              ),

                              // Company
                              _buildTextField(
                                controller: _companyController,
                                label: 'Company',
                                hint: 'Your company name',
                                icon: Icons.business,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter company name';
                                  }
                                  return null;
                                },
                              ),

                              // Location
                              _buildTextField(
                                controller: _locationController,
                                label: 'Location',
                                hint: 'Shift location (full address)',
                                icon: Icons.location_on_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter Shift location';
                                  }
                                  return null;
                                },
                              ),

                              // Shift Pincode
                              _buildTextField(
                                controller: _ShiftPincodeController,
                                label: 'Shift Location Pincode',
                                hint: 'e.g. 400001',
                                icon: Icons.pin_drop_outlined,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter pincode';
                                  }
                                  if (value.length != 6 ||
                                      int.tryParse(value) == null) {
                                    return 'Please enter a valid 6-digit pincode';
                                  }
                                  return null;
                                },
                              ),

                              // Date
                              _buildTextField(
                                controller: _dateController,
                                label: 'Date',
                                hint: 'Select Shift date',
                                icon: Icons.calendar_today,
                                readOnly: true,
                                onTap: () => _selectDate(context),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a date';
                                  }
                                  return null;
                                },
                              ),

                              // Row for Start Time and End Time
                              _buildTimeSelectionRow(), // Pay Rate
                              // Pay Rate
                              _buildTextField(
                                controller: _payRateController,
                                label: 'Pay Rate (₹)',
                                hint: 'Per Day Rate in INR',
                                icon: Icons.payments_outlined,
                                prefixText: '₹ ',
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter pay rate';
                                  }
                                  final payRate = double.tryParse(value);
                                  if (payRate == null) {
                                    return 'Please enter a valid amount';
                                  }
                                  if (payRate < 1000) {
                                    return 'Pay rate must be ₹1000 or more';
                                  }
                                  return null;
                                },
                              ),
                              // Number of Positions
                              _buildTextField(
                                controller: _positionsController,
                                label: 'Number of Positions',
                                hint: 'How many workers needed',
                                icon: Icons.people_outline,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter number of positions';
                                  }
                                  if (int.tryParse(value) == null ||
                                      int.parse(value) < 1) {
                                    return 'Please enter a valid number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Contact Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter Tight',
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Website
                              _buildTextField(
                                controller: _websiteController,
                                label: 'Website (Optional)',
                                hint: 'Company website URL',
                                icon: Icons.language,
                              ),

                              // Supervisor Name
                              _buildTextField(
                                controller: _supervisorNameController,
                                label: 'Supervisor Name',
                                hint: 'Name of Shift supervisor',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter supervisor name';
                                  }
                                  return null;
                                },
                              ),

                              // Supervisor Phone
                              _buildTextField(
                                controller: _supervisorPhoneController,
                                label: 'Supervisor Phone',
                                hint: 'Contact number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter phone number';
                                  }
                                  if (value.length < 10) {
                                    return 'Please enter a valid phone number';
                                  }
                                  return null;
                                },
                              ),

                              // Supervisor Email
                              _buildTextField(
                                controller: _supervisorEmailController,
                                label: 'Supervisor Email',
                                hint: 'Email address',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter email address';
                                  }
                                  if (!RegExp(
                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  ).hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),
                              const Text(
                                'Additional Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter Tight',
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Dress Code
                              _buildTextField(
                                controller: _dressCodeController,
                                label: 'Dress Code',
                                hint: 'Required attire for the Shift',
                                icon: Icons.checkroom_outlined,
                                maxLines: 3,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter dress code information';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 32),
                              // Submit Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _postJob,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5B6BF8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Text(
                                    'Post Shift',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  // Helper method to build consistent text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    String? prefixText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: const Color(0xFF5B6BF8)),
              prefixText: prefixText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF5B6BF8)),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: const TextStyle(fontSize: 16, fontFamily: 'Inter'),
            readOnly: readOnly,
            onTap: onTap,
            maxLines: maxLines,
            keyboardType: keyboardType,
            validator: validator,
          ),
        ],
      ),
    );
  }
}
