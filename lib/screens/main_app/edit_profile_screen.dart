// lib/screens/main_app/edit_profile_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:hook_app/services/user_service.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/utils/nav.dart';
import 'package:hook_app/widgets/web_image.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const EditProfileScreen({super.key, required this.arguments});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late Map<String, dynamic>? initialData;
  XFile? _profileImage;
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _locationController;
  late TextEditingController _bioController;
  late TextEditingController _interestsController;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    initialData = widget.arguments['initialData'] as Map<String, dynamic>?;
    _profileImage = widget.arguments['profileImage'] as XFile?;
    _fullNameController =
        TextEditingController(text: initialData?['fullName'] ?? '');
    _emailController = TextEditingController(text: initialData?['email'] ?? '');
    _phoneController = TextEditingController(text: initialData?['phone'] ?? '');
    _dobController = TextEditingController(text: initialData?['dob'] ?? '');
    _locationController =
        TextEditingController(text: initialData?['location'] ?? '');
    _bioController = TextEditingController(text: initialData?['bio'] ?? '');
    _interestsController =
        TextEditingController(text: initialData?['interests'] ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = image;
      });
    }
  }

  Future<String?> _uploadMedia(XFile file, String type) async {
    try {
      final String? authToken = await StorageService.getAuthToken();

      final uri = Uri.parse('${AppConstants.mediaUpload}?type=$type');
      print('📤 Uploading $type to $uri');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $authToken';

      final bytes = await file.readAsBytes();
      print('📦 File size: ${bytes.length} bytes, Name: ${file.name}');

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name.isNotEmpty
            ? file.name
            : 'upload_${DateTime.now().millisecondsSinceEpoch}',
        contentType: type == 'video'
            ? MediaType('video', 'mp4')
            : MediaType('image', 'jpeg'),
      ));

      print('Sending request...');
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      print('Response Status: ${streamedResponse.statusCode}');
      print('Response Body: $responseBody');

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['url'] as String?;
      } else {
        debugPrint('Upload failed: $responseBody');
        return null;
      }
    } catch (error) {
      debugPrint('Upload error: $error');
      print('Upload error: $error');
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String? authToken = await StorageService.getAuthToken();

    if (authToken == null || authToken.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    try {
      String? profileImageUrl;
      if (_profileImage != null) {
        profileImageUrl = await _uploadMedia(_profileImage!, 'profile');
        if (profileImageUrl == null)
          throw Exception('Failed to upload profile image');
      }

      await UserService.updateUserProfile(
        fullName: _fullNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        dob: _dobController.text,
        location: _locationController.text,
        bio: _bioController.text,
        interests: _interestsController.text,
        profileImage: profileImageUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Nav.safePop(context); // Return to account screen
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to update profile: $error';
      });
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^\d{10,12}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid phone number (10-12 digits)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Nav.safePop(context),
        ),
        title: const Text('Edit Your Profile'),
        backgroundColor: AppConstants.primaryColor,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pinkAccent, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _updateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.accentColor,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              GestureDetector(
                                onTap: _pickProfileImage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: ClipOval(
                                              child: _profileImage != null
                                                  ? (kIsWeb
                                                      ? Image.network(_profileImage!.path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                                                      : Image.file(
                                                          File(_profileImage!.path),
                                                          fit: BoxFit.cover,
                                                        ))
                                                  : (initialData?['profileImageUrl'] != null || initialData?['profileImage'] != null || initialData?['profile_image'] != null)
                                                      ? platformAwareImage(
                                                          (initialData?['profileImageUrl'] ?? initialData?['profileImage'] ?? initialData?['profile_image'] ?? '').toString(),
                                                          fit: BoxFit.cover,
                                                        )
                                                      : const Icon(
                                                          Icons.person,
                                                          size: 60,
                                                          color: Colors.grey,
                                                        ),
                                            ),

                                          ),
                                        ),
                                        const Align(
                                          alignment: Alignment.bottomRight,
                                          child: CircleAvatar(
                                            radius: 20,
                                            backgroundColor:
                                                AppConstants.accentColor,
                                            child: Icon(
                                              Icons.camera_alt,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _fullNameController,
                                label: 'Full Name',
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Name is required'
                                        : null,
                              ),
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                validator: _validateEmail,
                              ),
                              _buildTextField(
                                controller: _phoneController,
                                label: 'Phone',
                                validator: _validatePhone,
                              ),
                              _buildTextField(
                                controller: _dobController,
                                label: 'Date of Birth',
                                readOnly: true,
                                onTap: () async {
                                  DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    _dobController.text =
                                        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                  }
                                },
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Date of Birth is required'
                                        : null,
                              ),
                              _buildTextField(
                                controller: _locationController,
                                label: 'Location',
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Location is required'
                                        : null,
                              ),
                              _buildTextField(
                                controller: _bioController,
                                label: 'Bio (Tell us about yourself)',
                                maxLines: 3,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Bio is required'
                                        : null,
                              ),
                              _buildTextField(
                                controller: _interestsController,
                                label: 'Interests (e.g., hiking, movies)',
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Interests are required'
                                        : null,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _updateProfile,
                                icon: const Icon(Icons.favorite,
                                    color: Colors.white),
                                label: const Text(
                                  'Save Profile',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16, horizontal: 24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
        ),
        style: const TextStyle(color: Colors.white),
        validator: validator,
      ),
    );
  }
}
