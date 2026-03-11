import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/utils/utils.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController(text: '30.00');
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Group name is required';
    if (value.trim().length < 3) return 'At least 3 characters';
    return null;
  }

  String? _validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) return 'Description is required';
    return null;
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Amount is required';
    final num = double.tryParse(value.trim());
    if (num == null) return 'Enter a valid number';
    if (num <= 0) return 'Amount must be greater than 0';
    return null;
  }

  Future<void> _createGroup() async {
    final nameError = _validateName(_nameController.text);
    final descError = _validateDescription(_descController.text);
    final amountError = _validateAmount(_amountController.text);

    if (nameError != null || descError != null || amountError != null) {
      // Trigger rebuild to show errors
      setState(() {});
      return;
    }

    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    final userEmail = ref.read(authControllerProvider.notifier).currentUser?.email;

    if (userId == null) {
      if (mounted) showSnackBar(context, 'User not logged in', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getUserProfile(userId);

      final groupService = ref.read(groupServiceProvider);
      await groupService.createGroup(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
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
      if (mounted) showSnackBar(context, 'Failed to create group: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group_add_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('New Family Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('Set up a group to track monthly payments',
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group Name
                  TextFormField(
                    controller: _nameController,
                    maxLength: 50,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: _validateName,
                    decoration: AppTheme.styledInput(
                      label: 'Group Name',
                      prefixIcon: Icons.badge_outlined,
                      hint: 'e.g. Sibling Monthly Fund',
                    ).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descController,
                    maxLength: 200,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: _validateDescription,
                    decoration: AppTheme.styledInput(
                      label: 'Description',
                      prefixIcon: Icons.description_outlined,
                      hint: 'What is this group for?',
                    ).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 16),

                  // Monthly Amount
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: _validateAmount,
                    decoration: AppTheme.styledInput(
                      label: 'Monthly Amount',
                      prefixIcon: Icons.payments_outlined,
                      prefixText: 'RM ',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Amount each member pays monthly',
                    style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  const SizedBox(height: 36),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createGroup,
                      icon: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Icon(Icons.add_circle_outline, size: 22),
                      label: Text(_isLoading ? '' : 'Create Group',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
