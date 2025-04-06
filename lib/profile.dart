import 'package:flutter/material.dart';
import 'package:shifthour_employeer/Employer/employer_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEmployer;

  const ProfileSetupScreen({Key? key, required this.isEmployer})
    : super(key: key);

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Employer form controllers
  final companyNameController = TextEditingController();
  final companyWebsiteController = TextEditingController();
  final contactPersonController = TextEditingController();
  final contactEmailController = TextEditingController();
  final contactPhoneController = TextEditingController();

  // Worker form controllers
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final pinCodeController = TextEditingController();

  String? selectedEducation;
  List<String> selectedIndustries = [];
  List<String> selectedAvailability = [];
  String? selectedDuration;

  final List<String> educationLevels = [
    'High School',
    'Associate Degree',
    'Bachelor\'s Degree',
    'Master\'s Degree',
    'PhD or Doctorate',
    'Trade School',
    'Other',
  ];

  final List<String> industries = [
    'Hospitality',
    'Retail',
    'Food Service',
    'Customer Service',
    'Warehouse',
    'Office Admin',
    'Healthcare',
    'Event Staff',
  ];

  final List<String> shiftAvailability = [
    'Weekdays',
    'Weekends',
    'Evenings',
    'Mornings',
    'Overnight',
    'On-Call',
  ];

  final List<String> shiftDurations = [
    '4 hours',
    '6 hours',
    '8 hours',
    '12 hours',
    'Flexible',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      appBar: AppBar(
        title: Text(
          widget.isEmployer ? 'Employer Profile Setup' : 'Worker Profile Setup',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF5B6BF8),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF5B6BF8), Color(0xFF8B65D9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Shift',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            'Hour',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.isEmployer
                            ? 'Complete your employer profile'
                            : 'Complete your worker profile',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isEmployer
                            ? 'These details will help workers find your business'
                            : 'These details will help you find matching shifts',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child:
                        widget.isEmployer
                            ? _buildEmployerForm()
                            : _buildWorkerForm(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== EMPLOYER FORM =====
  Widget _buildEmployerForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormField(
            label: 'Company Name',
            hintText: 'e.g. Acme Corp',
            controller: companyNameController,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Company Website',
            hintText: 'e.g. https://acme.com',
            controller: companyWebsiteController,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Contact Person Name',
            hintText: 'e.g. John Doe',
            controller: contactPersonController,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Contact Email',
            hintText: 'e.g. john@acme.com',
            controller: contactEmailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Contact Phone',
            hintText: 'e.g. 123-456-7890',
            controller: contactPhoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _saveEmployerProfile(
                    companyName: companyNameController.text,
                    companyWebsite: companyWebsiteController.text,
                    contactPerson: contactPersonController.text,
                    contactEmail: contactEmailController.text,
                    contactPhone: contactPhoneController.text,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B6BF8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Complete Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== WORKER FORM =====
  Widget _buildWorkerForm() {
    return StatefulBuilder(
      builder: (context, setState) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormField(
                label: 'Full Name',
                hintText: 'e.g. Alex Johnson',
                controller: fullNameController,
              ),
              const SizedBox(height: 16),
              _buildFormField(
                label: 'Email',
                hintText: 'e.g. alex@example.com',
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildFormField(
                label: 'Phone Number',
                hintText: 'e.g. 555-123-4567',
                controller: phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildFormField(
                label: 'Pin Code',
                hintText: 'e.g. 10001',
                controller: pinCodeController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                value: selectedEducation,
                hint: const Text('Select highest education'),
                validator:
                    (value) =>
                        value == null
                            ? 'Please select your education level'
                            : null,
                items:
                    educationLevels
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (value) => setState(() => selectedEducation = value),
              ),
              const SizedBox(height: 24),

              Text(
                'Industries of Interest',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    industries.map((industry) {
                      final isSelected = selectedIndustries.contains(industry);
                      return FilterChip(
                        label: Text(industry),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedIndustries.add(industry);
                            } else {
                              selectedIndustries.remove(industry);
                            }
                          });
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),

              Text(
                'Preferred Shift Availability',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    shiftAvailability.map((shift) {
                      final isSelected = selectedAvailability.contains(shift);
                      return FilterChip(
                        label: Text(shift),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedAvailability.add(shift);
                            } else {
                              selectedAvailability.remove(shift);
                            }
                          });
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                value: selectedDuration,
                hint: const Text('Select preferred shift duration'),
                validator:
                    (value) =>
                        value == null ? 'Please select shift duration' : null,
                items:
                    shiftDurations
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (value) => setState(() => selectedDuration = value),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      if (selectedIndustries.isEmpty ||
                          selectedAvailability.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select at least one industry and shift availability',
                            ),
                          ),
                        );
                        return;
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B6BF8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Complete Profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? 'This field is required'
                      : null,
        ),
      ],
    );
  }

  // ===== Save to Supabase =====
  Future<void> _saveEmployerProfile({
    required String companyName,
    required String companyWebsite,
    required String contactPerson,
    required String contactEmail,
    required String contactPhone,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('employers').insert({
        'company_name': companyName,
        'website': companyWebsite,
        'contact_name': contactPerson,
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employer profile saved!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const EmployerDashboard()),
        (route) => false,
      );
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
