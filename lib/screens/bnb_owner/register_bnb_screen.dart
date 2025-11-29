import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/bnb_service.dart';
import 'package:hook_app/models/bnb_session.dart';

class RegisterBnBScreen extends StatefulWidget {
  const RegisterBnBScreen({super.key});

  @override
  State<RegisterBnBScreen> createState() => _RegisterBnBScreenState();
}

class _RegisterBnBScreenState extends State<RegisterBnBScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _callNumberController = TextEditingController();
  bool _available = true;
  bool _isSubmitting = false;

  // Session management
  final List<BnBSession> _sessions = [];

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _callNumberController.dispose();
    super.dispose();
  }

  void _addSession(int duration, double price) {
    setState(() {
      _sessions.add(BnBSession(
        duration: duration,
        price: price,
        currency: 'KES',
      ));
    });
  }

  void _removeSession(int index) {
    setState(() {
      _sessions.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one session type'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Register the BnB with sessions in a single call
      final response = await BnBService.registerBnB(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        address: _addressController.text.trim(),
        priceKES: double.parse(_priceController.text.trim()),
        available: _available,
        callNumber: _callNumberController.text.trim(),
        sessions: _sessions,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BnB and sessions registered successfully!'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        Navigator.pop(context, true); // Return true to signal success
      }
    } catch (e) {
      print('[REGISTER BNB] Error: $e');
      
      String errorMessage;
      if (e.toString().contains('ClientException') || e.toString().contains('Failed to fetch')) {
        errorMessage = 'Unable to connect to server. Please check your internet connection.';
      } else if (e.toString().contains('unauthorized') || e.toString().contains('401')) {
        errorMessage = 'Session expired. Please login again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      } else {
        errorMessage = 'Failed to register BnB. Please try again later.';
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppConstants.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'BnB Name',
                          icon: Icons.home,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter BnB name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _locationController,
                          label: 'Location',
                          icon: Icons.location_on,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter location';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Address',
                          icon: Icons.map,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _priceController,
                          label: 'Base Price (24h session)',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter base price';
                            }
                            final price = double.tryParse(value);
                            if (price == null || price <= 0) {
                              return 'Please enter a valid price';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _callNumberController,
                          label: 'Contact Number',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Contact number is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildAvailabilityToggle(),
                        const SizedBox(height: 24),
                        _buildSessionsSection(),
                        const SizedBox(height: 32),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Session Types & Prices',
              style: TextStyle(
                color: AppConstants.softWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: _showAddSessionDialog,
              icon: const Icon(Icons.add_circle, color: AppConstants.primaryColor, size: 32),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_sessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppConstants.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppConstants.errorColor.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: AppConstants.errorColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add at least one session type',
                    style: TextStyle(color: AppConstants.errorColor),
                  ),
                ),
              ],
            ),
          )
        else
          ..._sessions.asMap().entries.map((entry) {
            final index = entry.key;
            final session = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppConstants.deepPurple.withOpacity(0.6),
                    AppConstants.surfaceColor.withOpacity(0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppConstants.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: AppConstants.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.displayName,
                          style: const TextStyle(
                            color: AppConstants.softWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${session.formattedPrice} • ${session.duration} hrs',
                          style: const TextStyle(
                            color: AppConstants.accentColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeSession(index),
                    icon: const Icon(Icons.delete, color: AppConstants.errorColor),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }



  Future<void> _showAddSessionDialog() async {
    int? selectedDuration;
    final priceController = TextEditingController();

    final sessionTypes = [
      {'duration': 1, 'label': '1 Hour'},
      {'duration': 2, 'label': '2 Hours'},
      {'duration': 6, 'label': '6 Hours'},
      {'duration': 12, 'label': 'Half Day (12 hrs)'},
      {'duration': 24, 'label': 'Full Day (24 hrs)'},
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppConstants.deepPurple,
          title: const Text('Add Session Type', style: TextStyle(color: AppConstants.softWhite)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedDuration,
                dropdownColor: AppConstants.deepPurple,
                decoration: const InputDecoration(
                  labelText: 'Session Duration',
                  labelStyle: TextStyle(color: AppConstants.softWhite),
                ),
                items: sessionTypes.map((st) {
                  return DropdownMenuItem<int>(
                    value: st['duration'] as int,
                    child: Text(st['label'] as String, style: const TextStyle(color: AppConstants.softWhite)),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedDuration = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                style: const TextStyle(color: AppConstants.softWhite),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (KES)',
                  labelStyle: TextStyle(color: AppConstants.softWhite),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.mutedGray)),
            ),
            TextButton(
              onPressed: () {
                if (selectedDuration != null && priceController.text.isNotEmpty) {
                  _addSession(selectedDuration!, double.parse(priceController.text));
                  Navigator.pop(context);
                }
              },
              child: const Text('Add', style: TextStyle(color: AppConstants.primaryColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: AppConstants.softWhite,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register New BnB',
                style: TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Add your property details',
                style: TextStyle(
                  color: AppConstants.mutedGray,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.deepPurple.withOpacity(0.6),
            AppConstants.surfaceColor.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: AppConstants.softWhite),
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppConstants.softWhite.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: AppConstants.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildAvailabilityToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.deepPurple.withOpacity(0.6),
            AppConstants.surfaceColor.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.toggle_on, color: AppConstants.primaryColor, size: 28),
              SizedBox(width: 12),
              Text(
                'Available for Booking',
                style: TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Switch(
            value: _available,
            onChanged: (value) {
              setState(() => _available = value);
            },
            activeColor: AppConstants.successColor,
            inactiveThumbColor: AppConstants.mutedGray,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppConstants.primaryColor, AppConstants.accentColor],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSubmitting ? null : _submitForm,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppConstants.softWhite,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Register BnB',
                    style: TextStyle(
                      color: AppConstants.softWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
