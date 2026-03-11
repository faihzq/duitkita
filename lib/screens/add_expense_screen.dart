import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/storage_service.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/utils/utils.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;

  const AddExpenseScreen({super.key, required this.groupId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final ImagePicker _imagePicker = ImagePicker();
  File? _receiptFile;
  String? _receiptFileName;
  bool _isPdf = false;
  bool _isLoading = false;

  Future<void> _submitExpense() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;

    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) {
      if (mounted) showSnackBar(context, 'User not logged in', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    String? receiptUrl;

    try {
      if (_receiptFile != null) {
        final storageService = ref.read(storageServiceProvider);
        receiptUrl = await storageService.uploadReceipt(
          groupId: widget.groupId, userId: userId, file: _receiptFile!,
        );
      }

      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getUserProfile(userId);

      final values = _formKey.currentState!.value;
      final expenseService = ref.read(expenseServiceProvider);
      final userName = profile?.name ?? 'Unknown';

      // Check if auto-approve is enabled
      final group = await ref.read(groupStreamProvider(widget.groupId).future);
      final autoApprove = group?.autoApproveExpenses ?? false;

      await expenseService.submitExpense(
        groupId: widget.groupId,
        requestedBy: userId,
        requestedByName: userName,
        title: (values['title'] as String).trim(),
        description: (values['description'] as String?)?.trim().isEmpty == true ? null : (values['description'] as String?)?.trim(),
        amount: double.parse((values['amount'] as String).trim()),
        receiptUrl: receiptUrl,
        autoApprove: autoApprove,
        approvedByName: autoApprove ? userName : null,
      );

      if (mounted) {
        showSnackBar(context, autoApprove ? 'Expense auto-approved!' : 'Expense request submitted!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed to submit expense: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickReceiptImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1920, imageQuality: 85,
      );
      if (image != null) {
        setState(() { _receiptFile = File(image.path); _receiptFileName = image.name; _isPdf = false; });
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed to pick image: $e', isError: true);
    }
  }

  Future<void> _takeReceiptPhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera, maxWidth: 1920, maxHeight: 1920, imageQuality: 85,
      );
      if (image != null) {
        setState(() { _receiptFile = File(image.path); _receiptFileName = image.name; _isPdf = false; });
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed to take photo: $e', isError: true);
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null && result.files.single.path != null) {
        setState(() { _receiptFile = File(result.files.single.path!); _receiptFileName = result.files.single.name; _isPdf = true; });
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed to pick PDF: $e', isError: true);
    }
  }

  void _removeReceiptFile() {
    setState(() { _receiptFile = null; _receiptFileName = null; _isPdf = false; });
  }

  void _showFileSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Receipt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 16),
              _buildSourceOption(Icons.photo_library_outlined, 'Image from Gallery', AppTheme.primary, () { Navigator.pop(ctx); _pickReceiptImage(); }),
              _buildSourceOption(Icons.camera_alt_outlined, 'Take Photo', AppTheme.success, () { Navigator.pop(ctx); _takeReceiptPhoto(); }),
              _buildSourceOption(Icons.picture_as_pdf_outlined, 'PDF Document', AppTheme.error, () { Navigator.pop(ctx); _pickPdfFile(); }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      onTap: onTap,
    );
  }

  Widget _buildUploadChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('New Expense'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.request_quote_outlined, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Submit Expense Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('Admin approval required', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
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
              child: FormBuilder(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    FormBuilderTextField(
                      name: 'title',
                      maxLength: 100,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      validator: FormBuilderValidators.required(errorText: 'Please enter a title'),
                      decoration: AppTheme.styledInput(
                        label: 'Title',
                        prefixIcon: Icons.title,
                        hint: 'What is this expense for?',
                      ).copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    FormBuilderTextField(
                      name: 'amount',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(errorText: 'Amount is required'),
                        FormBuilderValidators.numeric(errorText: 'Enter a valid number'),
                        FormBuilderValidators.min(0.01, errorText: 'Amount must be greater than 0'),
                      ]),
                      decoration: AppTheme.styledInput(
                        label: 'Amount',
                        prefixIcon: Icons.payments_outlined,
                        prefixText: 'RM ',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    FormBuilderTextField(
                      name: 'description',
                      maxLines: 3,
                      maxLength: 300,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                      decoration: AppTheme.styledInput(
                        label: 'Description',
                        prefixIcon: Icons.description_outlined,
                        hint: 'Describe what this expense is for (optional)',
                      ).copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 20),

                    // Receipt Upload
                    if (_receiptFile == null)
                      GestureDetector(
                        onTap: _showFileSourceDialog,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              width: 1.5,
                              strokeAlign: BorderSide.strokeAlignInside,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.cloud_upload_outlined, color: AppTheme.primary, size: 32),
                              ),
                              const SizedBox(height: 12),
                              const Text('Upload Receipt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              const SizedBox(height: 4),
                              Text('Photo or PDF (optional)', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildUploadChip(Icons.photo_library_outlined, 'Gallery'),
                                  const SizedBox(width: 8),
                                  _buildUploadChip(Icons.camera_alt_outlined, 'Camera'),
                                  const SizedBox(width: 8),
                                  _buildUploadChip(Icons.picture_as_pdf_outlined, 'PDF'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          children: [
                            if (_isPdf)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.04),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.picture_as_pdf, size: 32, color: AppTheme.error),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _receiptFileName ?? 'PDF Document',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              )
                            else
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                    child: Image.file(_receiptFile!, height: 200, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 8, right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text('Attached', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _showFileSourceDialog,
                                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                                      label: const Text('Change', style: TextStyle(fontWeight: FontWeight.w600)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primary,
                                        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _removeReceiptFile,
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      label: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w600)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.error,
                                        side: BorderSide(color: AppTheme.error.withValues(alpha: 0.3)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitExpense,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Submit Expense Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
