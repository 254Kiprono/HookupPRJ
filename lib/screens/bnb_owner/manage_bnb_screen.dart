import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/bnb_service.dart';
import 'package:hook_app/models/bnb.dart';

class ManageBnBScreen extends StatefulWidget {
  final BnB bnb;

  const ManageBnBScreen({super.key, required this.bnb});

  @override
  State<ManageBnBScreen> createState() => _ManageBnBScreenState();
}

class _ManageBnBScreenState extends State<ManageBnBScreen> {
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _priceController;
  late TextEditingController _callNumberController;
  late bool _available;
  bool _isEditing = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bnb.name);
    _locationController = TextEditingController(text: widget.bnb.location);
    _priceController = TextEditingController(text: widget.bnb.price.toString());
    _callNumberController = TextEditingController(text: widget.bnb.callNumber ?? '');
    _available = widget.bnb.available;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _callNumberController.dispose();
    super.dispose();
  }

  Future<void> _updateBnB() async {
    setState(() => _isSubmitting = true);

    try {
      await BnBService.updateBnB(
        bnbId: widget.bnb.bnbId,
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        available: _available,
        callNumber: _callNumberController.text.trim().isNotEmpty 
            ? _callNumberController.text.trim() 
            : null,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BnB updated successfully!'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        setState(() => _isEditing = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteBnB() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.deepPurple,
        title: const Text(
          'Delete BnB',
          style: TextStyle(color: AppConstants.softWhite),
        ),
        content: const Text(
          'Are you sure you want to delete this BnB? This action cannot be undone.',
          style: TextStyle(color: AppConstants.softWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppConstants.mutedGray),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppConstants.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      await BnBService.deleteBnB(widget.bnb.bnbId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BnB deleted successfully'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
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
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 20),
                      if (_isEditing) ...[
                        _buildEditForm(),
                        const SizedBox(height: 20),
                        _buildActionButtons(),
                      ] else ...[
                        _buildViewButtons(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Edit BnB' : 'BnB Details',
                    style: const TextStyle(
                      color: AppConstants.softWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isEditing ? 'Update property details' : 'View and manage',
                    style: const TextStyle(
                      color: AppConstants.mutedGray,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    if (_isEditing) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.deepPurple.withOpacity(0.8),
            AppConstants.surfaceColor.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.bnb.name,
                  style: const TextStyle(
                    color: AppConstants.softWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.bnb.available 
                      ? AppConstants.successColor.withOpacity(0.2)
                      : AppConstants.mutedGray.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.bnb.available 
                        ? AppConstants.successColor
                        : AppConstants.mutedGray,
                  ),
                ),
                child: Text(
                  widget.bnb.availabilityStatus,
                  style: TextStyle(
                    color: widget.bnb.available 
                        ? AppConstants.successColor
                        : AppConstants.mutedGray,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow(Icons.location_on, 'Location', widget.bnb.location),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.attach_money, 'Price', widget.bnb.formattedPrice),
          if (widget.bnb.callNumber != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.phone, 'Contact', widget.bnb.callNumber!),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppConstants.primaryColor, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppConstants.softWhite.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: AppConstants.softWhite,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        _buildTextField(_nameController, 'BnB Name', Icons.home),
        const SizedBox(height: 16),
        _buildTextField(_locationController, 'Location', Icons.location_on),
        const SizedBox(height: 16),
        _buildTextField(
          _priceController, 
          'Price per Night', 
          Icons.attach_money,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          _callNumberController, 
          'Contact Number', 
          Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        _buildAvailabilityToggle(),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
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
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppConstants.softWhite),
        keyboardType: keyboardType,
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

  Widget _buildViewButtons() {
    return Column(
      children: [
        _buildGradientButton(
          onPressed: () {
            setState(() => _isEditing = true);
          },
          label: 'Edit Details',
          icon: Icons.edit,
          gradient: const LinearGradient(
            colors: [AppConstants.primaryColor, AppConstants.accentColor],
          ),
        ),
        const SizedBox(height: 16),
        _buildGradientButton(
          onPressed: _deleteBnB,
          label: 'Delete BnB',
          icon: Icons.delete,
          gradient: LinearGradient(
            colors: [AppConstants.errorColor, AppConstants.errorColor.withOpacity(0.7)],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildGradientButton(
          onPressed: _isSubmitting ? null : _updateBnB,
          label: _isSubmitting ? 'Updating...' : 'Save Changes',
          icon: Icons.check,
          gradient: const LinearGradient(
            colors: [AppConstants.successColor, AppConstants.accentColor],
          ),
        ),
        const SizedBox(height: 16),
        _buildGradientButton(
          onPressed: () {
            setState(() => _isEditing = false);
          },
          label: 'Cancel',
          icon: Icons.close,
          gradient: LinearGradient(
            colors: [AppConstants.mutedGray, AppConstants.mutedGray.withOpacity(0.7)],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppConstants.softWhite),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppConstants.softWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
