import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/widgets/modern_stepper.dart';
import 'package:duitkita/widgets/modern_text_field.dart';
import 'package:duitkita/utils/utils.dart';

class KycVerificationScreen extends StatefulWidget {
  const KycVerificationScreen({Key? key}) : super(key: key);

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // Step 1: Personal Details
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Step 2: ID Proof
  String? _selectedIdType;
  File? _idProofImage;

  // Step 3: Bank Details
  String? _selectedAccountType;
  final _accountHolderController = TextEditingController();
  final _ifscController = TextEditingController();
  final _accountNumberController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _pincodeController.dispose();
    _accountHolderController.dispose();
    _ifscController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _idProofImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed to pick image: $e', isError: true);
    }
  }

  void _nextStep() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_currentStep < 2) {
        setState(() {
          _currentStep++;
        });
      } else {
        _submitForm();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _submitForm() {
    showSnackBar(context, 'KYC verification submitted successfully!');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Upload KYC'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentStep > 0 ? _previousStep : () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stepper
          Container(
            color: Colors.white,
            child: ModernStepper(
              steps: const ['Personal Details', 'ID Proof', 'Bank Details'],
              currentStep: _currentStep,
            ),
          ),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildStepContent(),
                ),
              ),
            ),
          ),

          // Next Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _currentStep < 2 ? 'Next' : 'Submit',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalDetailsStep();
      case 1:
        return _buildIdProofStep();
      case 2:
        return _buildBankDetailsStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildPersonalDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Your Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ModernTextField(
          controller: _nameController,
          label: 'Name',
          hintText: 'Ankit Mahajan',
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Name is required';
            return null;
          },
        ),
        const SizedBox(height: 20),
        ModernTextField(
          controller: _mobileController,
          label: 'Mobile',
          hintText: '9899999999',
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Mobile is required';
            return null;
          },
        ),
        const SizedBox(height: 20),
        ModernTextField(
          controller: _emailController,
          label: 'Email',
          hintText: 'mn.ankit@yahoo.in',
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Email is required';
            if (!value!.contains('@')) return 'Invalid email';
            return null;
          },
        ),
        const SizedBox(height: 20),
        ModernTextField(
          controller: _pincodeController,
          label: 'Pincode',
          hintText: '122003',
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Pincode is required';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildIdProofStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Document Type',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        ModernChipSelector(
          options: const ['Aadhar Card', 'Pan Card', 'Driving License'],
          selectedOption: _selectedIdType,
          onSelected: (option) {
            setState(() {
              _selectedIdType = option;
            });
          },
        ),
        const SizedBox(height: 32),
        const Text(
          'Upload ID Proof',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep document on a plain dark surface and make sure all 4 corners of your document are visible.',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        if (_idProofImage == null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ModernUploadButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              ModernUploadButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ],
          )
        else
          Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _idProofImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.red,
                  radius: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _idProofImage = null;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBankDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Account Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Account Type',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        ModernToggleButtons(
          options: const ['Savings', 'Current'],
          selectedOption: _selectedAccountType,
          onSelected: (option) {
            setState(() {
              _selectedAccountType = option;
            });
          },
        ),
        const SizedBox(height: 20),
        ModernTextField(
          controller: _accountHolderController,
          label: 'Account Holder Name',
          hintText: 'Ankit Mahajan',
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Account holder name is required';
            return null;
          },
        ),
        const SizedBox(height: 20),
        ModernTextField(
          controller: _ifscController,
          label: 'IFSC Number',
          hintText: 'SBIN0001234',
          validator: (value) {
            if (value?.isEmpty ?? true) return 'IFSC is required';
            return null;
          },
        ),
        const SizedBox(height: 20),
        ModernTextField(
          controller: _accountNumberController,
          label: 'Account Number',
          hintText: '66666666',
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Account number is required';
            return null;
          },
        ),
      ],
    );
  }
}
