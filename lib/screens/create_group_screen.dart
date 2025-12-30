import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/widgets/custom_text_field.dart';
import 'package:duitkita/utils/utils.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(
    text: '30.00',
  );

  String? _nameError;
  String? _descriptionError;
  String? _amountError;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    bool isValid = true;

    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _nameError = 'Group name is required';
      });
      isValid = false;
    } else if (_nameController.text.trim().length < 3) {
      setState(() {
        _nameError = 'Group name must be at least 3 characters';
      });
      isValid = false;
    } else {
      setState(() {
        _nameError = null;
      });
    }

    if (_descriptionController.text.trim().isEmpty) {
      setState(() {
        _descriptionError = 'Description is required';
      });
      isValid = false;
    } else {
      setState(() {
        _descriptionError = null;
      });
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _amountError = 'Please enter a valid amount';
      });
      isValid = false;
    } else {
      setState(() {
        _amountError = null;
      });
    }

    return isValid;
  }

  Future<void> _createGroup() async {
    if (!_validateInputs()) {
      return;
    }

    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    final userEmail =
        ref.read(authControllerProvider.notifier).currentUser?.email;

    if (userId == null) {
      if (mounted) {
        showSnackBar(context, 'User not logged in', isError: true);
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getUserProfile(userId);

      final groupService = ref.read(groupServiceProvider);
      await groupService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        createdBy: userId,
        creatorName: profile?.name ?? 'Unknown',
        creatorEmail: userEmail,
        monthlyAmount: double.parse(_amountController.text.trim()),
      );

      if (mounted) {
        showSnackBar(context, 'Group created successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Failed to create group: ${e.toString()}',
          isError: true,
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
      appBar: AppBar(title: const Text('Create Group')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Create a new sibling group',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Set up a group to track monthly payments',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _nameController,
                labelText: 'Group Name',
                errorText: _nameError,
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() {
                      _nameError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _descriptionController,
                labelText: 'Description',
                errorText: _descriptionError,
                onChanged: (_) {
                  if (_descriptionError != null) {
                    setState(() {
                      _descriptionError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _amountController,
                labelText: 'Monthly Amount (RM)',
                errorText: _amountError,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() {
                      _amountError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'This is the amount each member needs to pay monthly',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Create Group',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
