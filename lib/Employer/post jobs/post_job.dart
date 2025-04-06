import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({Key? key}) : super(key: key);

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _payRateController = TextEditingController();
  final TextEditingController _supervisorNameController =
      TextEditingController();
  final TextEditingController _supervisorPhoneController =
      TextEditingController();
  final TextEditingController _supervisorEmailController =
      TextEditingController();
  final TextEditingController _jobPincodeController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _dressCodeController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _jobTitleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _payRateController.dispose();
    _supervisorNameController.dispose();
    _supervisorPhoneController.dispose();
    _supervisorEmailController.dispose();
    _jobPincodeController.dispose();
    _websiteController.dispose();
    _dressCodeController.dispose();
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

  // Method to pick start time
  Future<void> _selectStartTime(BuildContext context) async {
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
      });
    }
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

  // Method to post the job
  // Method to post the job
  // Method to post the job
  void _postJob() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Get the Supabase client instance
        final supabase = Supabase.instance.client;

        // Create job data to be inserted
        final jobData = {
          'job_title': _jobTitleController.text,
          'company': _companyController.text,
          'location': _locationController.text,
          'date': _dateController.text,
          'start_time': _startTimeController.text,
          'end_time': _endTimeController.text,
          'pay_rate': double.parse(_payRateController.text),
          'pay_currency': 'INR', // Hardcoded as per requirement
          'supervisor_name': _supervisorNameController.text,
          'supervisor_phone': _supervisorPhoneController.text,
          'supervisor_email': _supervisorEmailController.text,
          'job_pincode': int.parse(_jobPincodeController.text),
          'website':
              _websiteController.text.isEmpty ? null : _websiteController.text,
          'dress_code': _dressCodeController.text,
          'status': 'Active',
          // These might be set by the database, but we'll include them
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          // You may need to include the user_id to associate jobs with employers
          'user_id': supabase.auth.currentUser?.id,
        };

        print('Job data to be posted: $jobData');

        // Insert the job data into the worker_job_listings table
        final response = await supabase
            .from('worker_job_listings')
            .insert(jobData);

        print('Response from database: $response');

        // Show success message and navigate back
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job posted successfully!'),
              backgroundColor: Colors.green,
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
        print('Error saving job: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      appBar: AppBar(
        title: const Text(
          'Post a New Job',
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
                                'Create a New Job Listing',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter Tight',
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Fill in the details below to post a new job opportunity',
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
                                'Job Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter Tight',
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Job Title
                              _buildTextField(
                                controller: _jobTitleController,
                                label: 'Job Title',
                                hint: 'e.g. Barista, Cashier, Server',
                                icon: Icons.work_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter job title';
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
                                hint: 'Job location (full address)',
                                icon: Icons.location_on_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter job location';
                                  }
                                  return null;
                                },
                              ),

                              // Job Pincode
                              _buildTextField(
                                controller: _jobPincodeController,
                                label: 'Job Location Pincode',
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
                                hint: 'Select job date',
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
                              Row(
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
                                  // End Time
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _endTimeController,
                                      label: 'End Time',
                                      hint: 'Select',
                                      icon: Icons.access_time,
                                      readOnly: true,
                                      onTap: () => _selectEndTime(context),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              // Pay Rate
                              _buildTextField(
                                controller: _payRateController,
                                label: 'Pay Rate (₹)',
                                hint: 'Hourly rate in INR',
                                icon: Icons.payments_outlined,
                                prefixText: '₹ ',
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter pay rate';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Please enter a valid amount';
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
                                hint: 'Name of job supervisor',
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
                                hint: 'Required attire for the job',
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
                                    'Post Job',
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
