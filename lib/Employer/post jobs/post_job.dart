import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shifthour_employeer/Employer/payments/employeer_payments_dashboard.dart';
import 'package:shifthour_employeer/const/Activity_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_typeahead/flutter_typeahead.dart'; // Keep only this one

class PostShiftScreen extends StatefulWidget {
  const PostShiftScreen({Key? key, this.jobId}) : super(key: key);
  final String? jobId;
  @override
  State<PostShiftScreen> createState() => _PostShiftScreenState();
}

class _PostShiftScreenState extends State<PostShiftScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _ShiftTitleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  TextEditingController _locationController = TextEditingController();
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
  final TextEditingController _hourlyRateController = TextEditingController();
  bool _isEditMode = false;

  PlaceModel? _selectedPlace;
  @override
  void initState() {
    super.initState();

    // Check if we're in edit mode
    if (widget.jobId != null) {
      _isEditMode = true;
      _fetchJobDetails();
    }

    // Add listener to hourly rate to calculate total pay automatically
    _hourlyRateController.addListener(() {
      if (selectedHours != null) {
        final hourlyRate = double.tryParse(_hourlyRateController.text) ?? 0;
        final totalPayRate = hourlyRate * selectedHours!;
        _payRateController.text = totalPayRate.toStringAsFixed(2);
      }
    });
  }

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

  void _handleParseError(String startTime, String endTime, dynamic error) {
    // Log error details for debugging
    print(
      'Error parsing job times - start: $startTime, end: $endTime, error: $error',
    );

    // Show user-friendly error message
    final errorMessage =
        'The start time or end time for this job appears to be in an '
        'invalid format. Please check the job data to ensure the times '
        'are entered correctly in HH:MM format.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 30),
        action: SnackBarAction(label: 'Retry', onPressed: _fetchJobDetails),
      ),
    );

    // Populate with raw values as fallback
    _startTimeController.text = startTime;
    _endTimeController.text = endTime;
  }

  Future<void> _fetchJobDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase
              .from('worker_job_listings')
              .select('*')
              .eq('shift_id', widget.jobId as Object)
              .single();

      // Populate form controllers with fetched data
      _ShiftTitleController.text = response['job_title'] ?? '';
      _companyController.text = response['company'] ?? '';
      _locationController.text = response['location'] ?? '';
      _dateController.text = response['date'] ?? '';
      _supervisorNameController.text = response['supervisor_name'] ?? '';
      _supervisorPhoneController.text = response['supervisor_phone'] ?? '';
      _supervisorEmailController.text = response['supervisor_email'] ?? '';
      _ShiftPincodeController.text =
          (response['job_pincode']?.toString() ?? '');
      _websiteController.text = response['website'] ?? '';
      _dressCodeController.text = response['dress_code'] ?? '';

      // Set selected hours if available
      try {
        if (response['start_time'] != null && response['end_time'] != null) {
          // Parse times in 24-hour format (HH:MM:SS)
          final startTime = TimeOfDay.fromDateTime(
            DateFormat.Hms().parse(response['start_time']),
          );
          final endTime = TimeOfDay.fromDateTime(
            DateFormat.Hms().parse(response['end_time']),
          );

          // Calculate hours
          final startMinutes = startTime.hour * 60 + startTime.minute;
          final endMinutes = endTime.hour * 60 + endTime.minute;
          final hoursDiff = (endMinutes - startMinutes) / 60;

          selectedHours =
              hourOptions.contains(hoursDiff.round())
                  ? hoursDiff.round()
                  : null;

          // Set start and end time controllers
          _startTimeController.text = startTime.format(context);
          _endTimeController.text = endTime.format(context);
        }
      } catch (formatError) {
        _handleParseError(
          response['start_time'] ?? '',
          response['end_time'] ?? '',
          formatError,
        );
      }

      // Update pay rate and positions
      _payRateController.text = (response['pay_rate']?.toString() ?? '');
      _positionsController.text =
          (response['number_of_positions']?.toString() ?? '1');

      // Update state
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Handle fetch error
      print('Error fetching job details: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load job details. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } // Time format validation method

  bool _isValidTimeFormat(String time) {
    // Example simple format check: HH:MM AM/PM
    return RegExp(r'^\d{1,2}:\d{2} (AM|PM)$').hasMatch(time);
  }

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
          isExpanded: true,
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
              // Clear previous pay rate when hours change
              _payRateController.clear();
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
    final random = Random();
    final randomDigits = random.nextInt(9000) + 1000;
    return 'SH-$randomDigits';
  }

  void _postJob() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
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

        // Check wallet balance
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

        if (_isEditMode && widget.jobId != null) {
          // Update existing job
          final jobData = {
            'job_title': _ShiftTitleController.text,
            'company': _companyController.text,
            'location':
                _locationController.text.isNotEmpty
                    ? _locationController.text
                    : 'Unspecified Location',
            'date': _dateController.text,
            'start_time': _startTimeController.text,
            'end_time': _endTimeController.text,
            'pay_rate': double.parse(_payRateController.text),
            'pay_currency': 'INR',
            'number_of_positions': int.parse(_positionsController.text),
            'supervisor_name': _supervisorNameController.text,
            'supervisor_phone': _supervisorPhoneController.text,
            'supervisor_email': _supervisorEmailController.text,
            'job_pincode': int.parse(_ShiftPincodeController.text),
            'website':
                _websiteController.text.isEmpty
                    ? null
                    : _websiteController.text,
            'dress_code': _dressCodeController.text,
            'updated_at': DateTime.now().toIso8601String(),
            'user_id': userId,
          };

          await supabase
              .from('worker_job_listings')
              .update(jobData)
              .eq('shift_id', widget.jobId as Object);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shift updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pop(context, true);
        } else {
          // Create a batch ID to group related positions
          final batchId = 'B-${DateTime.now().millisecondsSinceEpoch}';
          final List<String> createdShiftIds = [];

          // For each position, create a separate shift record
          for (int i = 0; i < numberOfPositions; i++) {
            // Generate a unique custom job ID for each position
            final customJobId = _generateCustomJobId();

            // Prepare job data with the custom ID in shift_id
            final jobData = {
              'shift_id': customJobId,
              'batch_id': batchId,
              'position_number': i + 1, // Track position number within batch
              'job_title': _ShiftTitleController.text,
              'company': _companyController.text,
              'number_of_positions': 1, // Each record represents 1 position
              'location':
                  _locationController.text.isNotEmpty
                      ? _locationController.text
                      : 'Unspecified Location',
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

            createdShiftIds.add(jobResponse['shift_id']);
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

          // Log activity
          await ActivityLogger.logJobPosting({
            'job_title': _ShiftTitleController.text,
            'company': _companyController.text,
            'location': _locationController.text,
            'pay_rate': double.parse(_payRateController.text),
            'number_of_positions': numberOfPositions,
          });

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

          Navigator.pop(context, true);
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error ${_isEditMode ? 'updating' : 'posting'} job: $e',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        print('Error in job ${_isEditMode ? 'update' : 'posting'} process: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<PlaceModel> _getPlaceDetails(String placeId) async {
    try {
      final apiKey = 'YOUR_GOOGLE_PLACES_API_KEY';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?'
        'place_id=$placeId&key=$apiKey&fields=name,formatted_address,geometry',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['status'] == 'OK') {
          final placeDetails = result['result'];

          // Extract formatted address
          final formattedAddress = placeDetails['formatted_address'];

          // Extract location coordinates
          final location = placeDetails['geometry']['location'];
          final latitude = location['lat'];
          final longitude = location['lng'];

          // Update pincode if possible
          final components = placeDetails['address_components'] ?? [];
          for (var component in components) {
            final types = component['types'];
            if (types.contains('postal_code')) {
              _ShiftPincodeController.text = component['long_name'];
              break;
            }
          }

          return PlaceModel(
            placeId: placeId,
            description: placeDetails['name'] ?? formattedAddress,
            formattedAddress: formattedAddress,
            latitude: latitude,
            longitude: longitude,
          );
        }
      }
    } catch (e) {
      print('Error fetching place details: $e');
    }

    // Fallback
    return PlaceModel(placeId: placeId, description: _locationController.text);
  }

  Future<List<PlaceModel>> _getPlaceSuggestions(String input) async {
    if (input.trim().length < 1) {
      return [];
    }

    try {
      final apiKey =
          'AIzaSyC7eH8S98TXVYSSpGa5HvaDRaCD_YgRJk0'; // Replace with your actual API key
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
        'input=$input&key=$apiKey'
        '&types=geocode' // This will include various geocode types including pincodes
        '&components=country:in' // Restrict to India
        '&language=en',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('Timeout', 408),
          );

      if (kDebugMode) {
        print('🌐 Autocomplete Input: $input');
        print('🌐 Request URL: $url');
        print('🌐 Response Status: ${response.statusCode}');
        print('🌐 Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['status'] == 'OK') {
          final suggestions =
              (result['predictions'] as List)
                  .map<PlaceModel>(
                    (p) => PlaceModel(
                      placeId: p['place_id'],
                      description: p['description'],
                    ),
                  )
                  .toList();

          if (kDebugMode) {
            print('✅ Suggestions Found: ${suggestions.length}');
            suggestions.forEach((suggestion) {
              print('📍 Suggestion: ${suggestion.description}');
            });
          }

          return suggestions;
        } else {
          print('❌ API Error: ${result['status']}');
          print('❌ Error Details: ${result['error_message'] ?? 'No details'}');
          return [];
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Unexpected Error: $e');
      return [];
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Widget _buildPlacesAutocomplete() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Autocomplete<PlaceModel>(
            optionsBuilder: (TextEditingValue textEditingValue) async {
              final input = textEditingValue.text.trim();

              if (kDebugMode) {
                print('🔍 Autocomplete Input: $input');
              }

              // Reduce minimum input length to 1 character
              if (input.length < 1) {
                if (kDebugMode) {
                  print('❌ Input too short');
                }
                return const Iterable<PlaceModel>.empty();
              }

              try {
                final suggestions = await _getPlaceSuggestions(input);

                if (kDebugMode) {
                  print('✅ Suggestions Found: ${suggestions.length}');
                }

                return suggestions;
              } catch (e) {
                if (kDebugMode) {
                  print('❌ Autocomplete Error: $e');
                }
                return const Iterable<PlaceModel>.empty();
              }
            },
            displayStringForOption: (PlaceModel option) => option.description,
            onSelected: (PlaceModel selection) async {
              try {
                // Fetch detailed place information
                final detailedPlace = await _getPlaceDetails(selection.placeId);

                // Update location controllers
                setState(() {
                  _locationController.text =
                      detailedPlace.formattedAddress ??
                      selection.description ??
                      'Unspecified Location';
                  _selectedPlace = detailedPlace;

                  // Optionally update pincode if available
                  if (detailedPlace.formattedAddress != null) {
                    // Try to extract pincode from formatted address
                    final pincodeMatch = RegExp(
                      r'\b\d{6}\b',
                    ).firstMatch(detailedPlace.formattedAddress!);
                    if (pincodeMatch != null) {
                      _ShiftPincodeController.text =
                          pincodeMatch.group(0) ?? '';
                    }
                  }
                });

                if (kDebugMode) {
                  print('Selected Place Details: ${detailedPlace.toJson()}');
                }
              } catch (e) {
                print('Error processing selected place: $e');
                setState(() {
                  _locationController.text =
                      selection.description ?? 'Unspecified Location';
                });

                // Show a snackbar to inform user about the error
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unable to fetch complete location details'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            optionsViewBuilder: (
              BuildContext context,
              AutocompleteOnSelected<PlaceModel> onSelected,
              Iterable<PlaceModel> options,
            ) {
              if (kDebugMode) {
                print('🏗️ Options View Builder Called');
                print('🏗️ Options Count: ${options.length}');
              }

              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 300, // Limit height to 300 pixels
                      minWidth: MediaQuery.of(context).size.width - 32,
                      maxWidth: MediaQuery.of(context).size.width - 32,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child:
                          options.isEmpty
                              ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No locations found',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                              : ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.symmetric(vertical: 8),
                                itemCount: options.length,
                                separatorBuilder:
                                    (context, index) => Divider(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Color(
                                          0xFF5B6BF8,
                                        ).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.location_on_outlined,
                                        color: Color(0xFF5B6BF8),
                                        size: 24,
                                      ),
                                    ),
                                    title: Text(
                                      option.description,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    onTap: () {
                                      if (kDebugMode) {
                                        print(
                                          '✅ Option Selected: ${option.description}',
                                        );
                                      }
                                      onSelected(option);
                                    },
                                    trailing: Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.grey.shade400,
                                      size: 16,
                                    ),
                                  );
                                },
                              ),
                    ),
                  ),
                ),
              );
            },
            fieldViewBuilder: (
              BuildContext context,
              TextEditingController textEditingController,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted,
            ) {
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Enter location',
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF5B6BF8),
                  ),
                  suffixIcon:
                      textEditingController.text.isNotEmpty
                          ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              textEditingController.clear();
                              setState(() {
                                _selectedPlace = null;
                                _locationController.text = '';
                              });
                            },
                          )
                          : null,
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
                style: const TextStyle(fontSize: 16, fontFamily: 'Inter'),
                onFieldSubmitted: (value) => onFieldSubmitted(),
              );
            },
          ),
        ],
      ),
    );
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
        title: Text(
          _isEditMode ? 'Edit Shift' : 'Post a New Shift',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
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
                              // Location with autocomplete
                              _buildPlacesAutocomplete(),

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
                              // Pay RateExpanded(
                              Row(
                                children: [
                                  // Total Pay Rate
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _hourlyRateController,
                                      label: 'Hourly Pay (₹)',
                                      hint: 'Enter hourly rate',
                                      icon: Icons.payments_outlined,
                                      prefixText: '₹ ',
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter hourly rate';
                                        }
                                        if (double.tryParse(value) == null ||
                                            double.parse(value) <= 0) {
                                          return 'Please enter a valid rate';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _payRateController,
                                      label: 'Total Pay (₹)',
                                      hint: 'Calculated pay rate',
                                      icon: Icons.payments_outlined,
                                      prefixText: '₹ ',
                                      readOnly: true,
                                    ),
                                  ),
                                ],
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
                                  child: Text(
                                    _isEditMode ? 'Update Shift' : 'Post Shift',
                                    style: const TextStyle(
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

  void _calculatePayRate() {
    if (selectedHours != null) {
      // Show a dialog to input hourly rate
      showDialog(
        context: context,
        builder: (BuildContext context) {
          final hourlyRateController = TextEditingController();

          return AlertDialog(
            title: Text('Enter Hourly Rate'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You selected ${selectedHours} hours',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: hourlyRateController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter hourly rate in ₹',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Validate hourly rate
                  final hourlyRate = double.tryParse(hourlyRateController.text);

                  if (hourlyRate != null && hourlyRate > 0) {
                    // Calculate total pay rate
                    final totalPayRate = hourlyRate * selectedHours!;

                    setState(() {
                      _payRateController.text = totalPayRate.toStringAsFixed(2);
                    });

                    Navigator.pop(context);
                  } else {
                    // Show error if invalid input
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid hourly rate'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text('Calculate Total Pay'),
              ),
            ],
          );
        },
      );
    } else {
      // Show a snackbar to select hours first
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select shift duration first'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    void Function(String)? onChanged,
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

class PlaceModel {
  final String placeId;
  final String description;
  String? formattedAddress;
  double? latitude;
  double? longitude;

  PlaceModel({
    required this.placeId,
    required this.description,
    this.formattedAddress,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'description': description,
      'formattedAddress': formattedAddress,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
