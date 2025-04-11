import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StandaloneVerificationForm extends StatefulWidget {
  final VoidCallback? onComplete;

  const StandaloneVerificationForm({Key? key, this.onComplete})
    : super(key: key);

  @override
  State<StandaloneVerificationForm> createState() =>
      _StandaloneVerificationFormState();
}

class _StandaloneVerificationFormState
    extends State<StandaloneVerificationForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _panController = TextEditingController();

  File? _panPhoto;
  File? _incorporationCertificate;

  bool _isUploading = false;
  String _errorMessage = '';

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _panController.dispose();
    super.dispose();
  }

  void _showImageSourceDialog(bool isPanPhoto) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Image Source"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text("Take a photo"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageDirectly(ImageSource.camera, isPanPhoto);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text("Choose from gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageDirectly(ImageSource.gallery, isPanPhoto);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageDirectly(ImageSource source, bool isPanPhoto) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  source == ImageSource.camera
                      ? "Taking photo..."
                      : "Selecting from gallery...",
                ),
              ],
            ),
          );
        },
      );

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      // Close the loading dialog
      if (mounted) Navigator.of(context).pop();

      if (pickedFile != null && mounted) {
        setState(() {
          if (isPanPhoto) {
            _panPhoto = File(pickedFile.path);
          } else {
            _incorporationCertificate = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      // Close the loading dialog if there's an error
      if (mounted) Navigator.of(context).pop();

      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
      print('Error picking image: $e');
    }
  }

  Future<void> _uploadDocuments() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      print('Current User: ${user?.id}'); // Debug print
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Get user's email
      final userEmail = user.email;
      print('User Email: $userEmail');

      // Generate unique file names for uploads
      final panPhotoName =
          'pan_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final incorporationName =
          'incorporation_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload PAN photo
      final panPhotoPath = await _uploadFile(
        _panPhoto!,
        'business_documents',
        panPhotoName,
      );

      // Upload incorporation certificate
      final incorporationPath = await _uploadFile(
        _incorporationCertificate!,
        'business_documents',
        incorporationName,
      );

      // Insert into business_verifications table
      final insertResponse =
          await Supabase.instance.client.from('business_verifications').upsert({
            'user_id': user.id,
            'email': userEmail, // Add email to the record
            'pan_number': _panController.text,
            'pan_photo_url': panPhotoPath,
            'incorporation_certificate_url': incorporationPath,
            'is_verified': true, // Set to true immediately
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id') // If record exists, update it
          .select();

      print('Insert/Update Response: $insertResponse');

      // Show success message and close the form
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Business verification documents uploaded successfully!',
            ),
          ),
        );

        _closeForm();
      }
    } catch (e, stackTrace) {
      print('Full Error Details: $e');
      print('Stack Trace: $stackTrace');

      setState(() {
        _errorMessage = 'Failed to upload documents: ${e.toString()}';
        _isUploading = false;
      });
    }
  }

  Future<String> _uploadFile(File file, String bucket, String fileName) async {
    try {
      final bytes = await file.readAsBytes();

      // Upload binary data
      final uploadResponse = await Supabase.instance.client.storage
          .from(bucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(upsert: true),
          );

      print('Upload Response: $uploadResponse'); // Debug print

      // Get the public URL
      final publicUrl = Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(fileName);

      print('Public URL: $publicUrl'); // Debug print

      return publicUrl;
    } catch (e) {
      print('File Upload Error: $e');
      rethrow;
    }
  }

  void _closeForm() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text('Business Verification'),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _closeForm,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Business Verification',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please provide your company\'s PAN number and upload required documents to verify your business.',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // PAN Number field
            TextFormField(
              controller: _panController,
              decoration: InputDecoration(
                labelText: 'Company PAN Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.credit_card),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter company PAN number';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // PAN Photo upload
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAN Card Photo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showImageSourceDialog(true),
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child:
                        _panPhoto != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _panPhoto!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                            : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.upload_file,
                                    size: 40,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload PAN Card Photo',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Incorporation Certificate upload
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Incorporation Certificate',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showImageSourceDialog(false),
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child:
                        _incorporationCertificate != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _incorporationCertificate!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                            : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.upload_file,
                                    size: 40,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload Incorporation Certificate',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ),
                ),
              ],
            ),

            // Error message
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Submit button
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadDocuments,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child:
                  _isUploading
                      ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Uploading...'),
                        ],
                      )
                      : const Text('Submit Documents'),
            ),
          ],
        ),
      ),
    );
  }
}
