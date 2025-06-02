// lib/screens/main_app/edit_profile_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const EditProfileScreen({super.key, required this.arguments});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late Map<String, dynamic>? initialData;
  late File? _profileImage;
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
    _profileImage = widget.arguments['profileImage'] as File?;
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
        _profileImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadProfileImage(File image) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://api.cloudinary.com/v1_1/your-cloud-name/image/upload'), // Replace with your Cloudinary URL
      );
      request.fields['upload_preset'] =
          'your-upload-preset'; // Replace with your Cloudinary preset
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        image.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      print('Uploading image to Cloudinary'); // Debug log
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final imageUrl = data['secure_url'] as String?;
        print('Image uploaded successfully: $imageUrl'); // Debug log
        return imageUrl;
      } else {
        print('Image upload failed: $responseBody'); // Debug log
        return null;
      }
    } catch (error) {
      print('Image upload error: $error'); // Debug log
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final String? authToken = prefs.getString(AppConstants.authTokenKey);

    if (authToken == null || authToken.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    try {
      // Prepare the updated data
      final updatedData = {
        'fullName': _fullNameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'dob': _dobController.text,
        'location': _locationController.text,
        'bio': _bioController.text,
        'interests': _interestsController.text,
      };

      // Optionally include userID if required by the server
      final String? userId = prefs.getString(AppConstants.userIdKey);
      if (userId != null) {
        updatedData['user_id'] = userId;
      }

      // Handle dob format explicitly
      if (updatedData['dob'] != null && updatedData['dob'] is String) {
        final dob = updatedData['dob'] as String;
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dob)) {
          throw Exception('Invalid dob format. Use YYYY-MM-DD');
        }
      }

      // Handle profile image upload if present
      if (_profileImage != null) {
        final imageUrl = await _uploadProfileImage(_profileImage!);
        if (imageUrl != null) {
          updatedData['profileImage'] = imageUrl;
        } else {
          throw Exception('Failed to upload profile image');
        }
      }

      print(
          'Updating profile to: ${AppConstants.userServiceBaseUrl}${AppConstants.apiVersion}/auth/update-userprofile');
      print('Request payload: ${jsonEncode(updatedData)}'); // Debug log
      final url = Uri.parse(
          '${AppConstants.userServiceBaseUrl}${AppConstants.apiVersion}/auth/update-userprofile');
      final response = await http
          .patch(
            url,
            headers: {
              'Authorization': 'Bearer $authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(updatedData),
          )
          .timeout(const Duration(seconds: 30));

      print(
          'Update response status: ${response.statusCode} - ${response.body}'); // Debug log
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context); // Return to account screen
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Failed to update profile: ${response.statusCode} - ${response.body}';
        });
        print('Update error response: ${response.body}');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to connect to the server: $error';
      });
      print('Profile Update Error: $error');
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
          onPressed: () => Navigator.pop(context),
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
                                  child: CircleAvatar(
                                    radius: 70,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 65,
                                      backgroundImage: _profileImage != null
                                          ? FileImage(_profileImage!)
                                              as ImageProvider
                                          : initialData?['profileImageUrl'] !=
                                                  null
                                              ? NetworkImage(initialData![
                                                      'profileImageUrl'])
                                                  as ImageProvider
                                              : NetworkImage(
                                                      'https://via.placeholder.com/150')
                                                  as ImageProvider,
                                      child: Align(
                                        alignment: Alignment.bottomRight,
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundColor:
                                              AppConstants.accentColor,
                                          child: const Icon(
                                            Icons.camera_alt,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
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
          fillColor: Colors.white.withOpacity(0.2),
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
