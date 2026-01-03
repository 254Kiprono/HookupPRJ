import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/user_service.dart';
import 'package:intl/intl.dart';

class ProfileDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final Function(bool) onStatusChanged;
  final bool isOnline;
  final bool isEditable;

  const ProfileDetailsScreen({
    super.key,
    required this.userProfile,
    required this.onStatusChanged,
    required this.isOnline,
    this.isEditable = false,
  });

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  late bool _isOnline;
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _locationController;
  late TextEditingController _bioController;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.isOnline;
    _nameController = TextEditingController(text: widget.userProfile['full_name'] ?? widget.userProfile['fullName'] ?? '');
    _dobController = TextEditingController(text: _formatDob(widget.userProfile['dob']));
    _locationController = TextEditingController(text: widget.userProfile['location'] ?? '');
    _bioController = TextEditingController(text: widget.userProfile['bio'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String _formatPhone(String? phone) {
    if (phone == null) return 'N/A';
    // Remove any non-digit characters
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    
    // Check if it starts with 254 and has 12 digits
    if (cleanPhone.startsWith('254') && cleanPhone.length == 12) {
      return '0${cleanPhone.substring(3)}';
    }
    // Check if it starts with +254
    if (phone.startsWith('+254')) {
       return '0${phone.substring(4)}';
    }
    
    return phone;
  }

  String _formatDob(String? dob) {
    if (dob == null || dob.isEmpty) return '';
    try {
      // Try parsing YYYY-MM-DD
      final date = DateTime.parse(dob);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dob; // Return as is if parsing fails
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppConstants.primaryColor,
              onPrimary: Colors.white,
              surface: AppConstants.deepPurple,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppConstants.darkBackground,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _updateOnlineStatus(bool value) async {
    setState(() {
      _isOnline = value;
    });

    try {
      await UserService.updateActiveStatus(value);
      widget.onStatusChanged(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now ${value ? 'Online' : 'Offline'}'),
            backgroundColor: value ? AppConstants.successColor : AppConstants.mutedGray,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOnline = !value; // Revert
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update online status: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Convert DD/MM/YYYY back to YYYY-MM-DD for API if needed, or send as is depending on backend
      // Assuming backend accepts YYYY-MM-DD
      String? dobToSend;
      if (_dobController.text.isNotEmpty) {
        try {
          final date = DateFormat('dd/MM/yyyy').parse(_dobController.text);
          dobToSend = DateFormat('yyyy-MM-dd').format(date);
        } catch (e) {
          dobToSend = _dobController.text;
        }
      }

      await UserService.updateUserProfile(
        fullName: _nameController.text,
        location: _locationController.text,
        dob: dobToSend,
        // bio: _bioController.text, // Add bio to UserService if supported
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        setState(() {
          _isEditing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.midnightPurple,
              AppConstants.deepPurple,
              AppConstants.darkBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppConstants.softWhite),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Personal Info',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.softWhite,
                          ),
                        ),
                      ],
                    ),
                    if (widget.isEditable && !_isEditing)
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppConstants.primaryColor),
                        onPressed: () {
                          setState(() {
                            _isEditing = true;
                          });
                        },
                      ),
                    if (_isEditing)
                      IconButton(
                        icon: const Icon(Icons.close, color: AppConstants.errorColor),
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            // Reset controllers
                            _nameController.text = widget.userProfile['full_name'] ?? widget.userProfile['fullName'] ?? '';
                            _dobController.text = _formatDob(widget.userProfile['dob']);
                            _locationController.text = widget.userProfile['location'] ?? '';
                            _bioController.text = widget.userProfile['bio'] ?? '';
                          });
                        },
                      ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildInfoCard(),
                      if (_isEditing) ...[
                        const SizedBox(height: 20),
                        _buildSaveButton(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEditableRow(
            Icons.person_outline,
            'Full Name',
            _nameController,
            enabled: _isEditing,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.email_outlined,
            'Email',
            widget.userProfile['email'] ?? 'N/A',
            isVerified: widget.userProfile['emailVerified'] == true,
            isReadOnly: true,
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.phone_outlined,
            'Phone',
            _formatPhone(widget.userProfile['phone']),
            isVerified: widget.userProfile['phoneVerified'] == true,
            isReadOnly: true,
          ),
          _buildDivider(),
          _buildEditableRow(
            Icons.cake_outlined,
            'Date of Birth',
            _dobController,
            enabled: _isEditing,
            isDate: true,
          ),
          _buildDivider(),
          _buildEditableRow(
            Icons.location_on_outlined,
            'Location',
            _locationController,
            enabled: _isEditing,
          ),
          _buildDivider(),
          // Online Status Toggle
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppConstants.accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.wifi,
                        color: AppConstants.accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Online Status',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppConstants.softWhite,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isOnline,
                  onChanged: _updateOnlineStatus,
                  activeColor: AppConstants.accentColor,
                  activeTrackColor: AppConstants.accentColor.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isVerified = false, bool isReadOnly = false}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppConstants.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppConstants.mutedGray,
                        fontSize: 12,
                      ),
                    ),
                    if (isReadOnly)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: AppConstants.mutedGray.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: isReadOnly ? AppConstants.softWhite.withOpacity(0.7) : AppConstants.softWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isVerified) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppConstants.successColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppConstants.successColor.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: AppConstants.successColor,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Verified',
                              style: TextStyle(
                                color: AppConstants.successColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(
    IconData icon,
    String label,
    TextEditingController controller, {
    bool enabled = false,
    bool isDate = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppConstants.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppConstants.mutedGray,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                enabled
                    ? GestureDetector(
                        onTap: isDate ? () => _selectDate(context) : null,
                        child: AbsorbPointer(
                          absorbing: isDate,
                          child: TextField(
                            controller: controller,
                            style: const TextStyle(
                              color: AppConstants.softWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: AppConstants.mutedGray),
                            ),
                          ),
                        ),
                      )
                    : Text(
                        controller.text.isEmpty ? 'Not set' : controller.text,
                        style: const TextStyle(
                          color: AppConstants.softWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ],
            ),
          ),
          if (enabled)
            Icon(
              isDate ? Icons.calendar_today : Icons.edit,
              size: 16,
              color: AppConstants.primaryColor.withOpacity(0.5),
            ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: AppConstants.mutedGray.withOpacity(0.2),
      indent: 60,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 5,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Save Changes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
