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
import 'package:hook_app/services/user_service.dart';

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

  // Gallery and Video state
  List<String> _galleryUrls = [];
  List<File> _galleryFiles = [];
  String? _videoUrl;
  File? _videoFile;

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

    // Initialize gallery and video from initialData
    if (initialData?['photoGallery'] != null) {
      if (initialData!['photoGallery'] is List) {
        _galleryUrls = List<String>.from(initialData!['photoGallery']);
      } else if (initialData!['photoGallery'] is String) {
        try {
          _galleryUrls =
              List<String>.from(jsonDecode(initialData!['photoGallery']));
        } catch (e) {
          _galleryUrls = [];
        }
      }
    }
    _videoUrl = initialData?['profileVideoUrl'];
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

  Future<void> _pickGalleryImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        // Limit to 6 total including existing
        int remaining = 6 - _galleryFiles.length - _galleryUrls.length;
        if (remaining > 0) {
          _galleryFiles.addAll(
            images.take(remaining).map((xfile) => File(xfile.path)),
          );
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (video != null) {
      setState(() {
        _videoFile = File(video.path);
      });
    }
  }

  Future<String?> _uploadMedia(File file, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? authToken = prefs.getString(AppConstants.authTokenKey);

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.mediaUpload}?type=$type'),
      );
      request.headers['Authorization'] = 'Bearer $authToken';
      
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: type == 'video' 
          ? MediaType('video', 'mp4')
          : MediaType('image', 'jpeg'),
      ));

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['url'] as String?;
      } else {
        debugPrint('Upload failed: $responseBody');
        return null;
      }
    } catch (error) {
      debugPrint('Upload error: $error');
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
      String? profileImageUrl;
      if (_profileImage != null) {
        profileImageUrl = await _uploadMedia(_profileImage!, 'profile');
        if (profileImageUrl == null) throw Exception('Failed to upload profile image');
      }

      // Handle Gallery Uploads
      List<String> finalGallery = List.from(_galleryUrls);
      for (var file in _galleryFiles) {
        final url = await _uploadMedia(file, 'gallery');
        if (url != null) {
          finalGallery.add(url);
        }
      }

      // Handle Video Upload
      String? finalVideoUrl = _videoUrl;
      if (_videoFile != null) {
        finalVideoUrl = await _uploadMedia(_videoFile!, 'video');
        if (finalVideoUrl == null) throw Exception('Failed to upload profile video');
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
        photoGallery: finalGallery,
        profileVideoUrl: finalVideoUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context); // Return to account screen
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
                                              : const NetworkImage(
                                                      'https://via.placeholder.com/150')
                                                  as ImageProvider,
                                      child: const Align(
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
                              _buildGalleryPicker(),
                              const SizedBox(height: 20),
                              _buildVideoPicker(),
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

  Widget _buildGalleryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photo Gallery (Max 6)',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: (_galleryUrls.length + _galleryFiles.length + 1).clamp(0, 7),
          itemBuilder: (context, index) {
            if (index < _galleryUrls.length) {
              return _buildMediaItem(
                image: NetworkImage(_galleryUrls[index]),
                onDelete: () => setState(() => _galleryUrls.removeAt(index)),
              );
            }
            int fileIndex = index - _galleryUrls.length;
            if (fileIndex < _galleryFiles.length) {
              return _buildMediaItem(
                image: FileImage(_galleryFiles[fileIndex]),
                onDelete: () => setState(() => _galleryFiles.removeAt(fileIndex)),
              );
            }
            if (_galleryUrls.length + _galleryFiles.length < 6) {
              return GestureDetector(
                onTap: _pickGalleryImages,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.add_a_photo, color: Colors.white, size: 40),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildVideoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profile Video (30s max)',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickVideo,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: _videoFile != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.video_library, color: Colors.white, size: 50),
                      Text(
                        _videoFile!.path.split('/').last,
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      TextButton(
                        onPressed: () => setState(() => _videoFile = null),
                        child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                      )
                    ],
                  )
                : _videoUrl != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 50),
                          const Text('Video Uploaded', style: TextStyle(color: Colors.white)),
                          TextButton(
                            onPressed: () => setState(() => _videoUrl = null),
                            child: const Text('Change', style: TextStyle(color: Colors.white60)),
                          )
                        ],
                      )
                    : const Icon(Icons.video_call, color: Colors.white, size: 50),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItem({required ImageProvider image, required VoidCallback onDelete}) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            image: DecorationImage(image: image, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onDelete,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
              child: Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
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
