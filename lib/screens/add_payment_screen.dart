import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/storage_service.dart';
import 'package:duitkita/widgets/custom_text_field.dart';
import 'package:duitkita/utils/utils.dart';

class AddPaymentScreen extends ConsumerStatefulWidget {
  final String groupId;
  final double monthlyAmount;
  final int selectedMonth;
  final int selectedYear;

  const AddPaymentScreen({
    super.key,
    required this.groupId,
    required this.monthlyAmount,
    required this.selectedMonth,
    required this.selectedYear,
  });

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  late TextEditingController _amountController;
  final TextEditingController _notesController = TextEditingController();
  late DateTime _selectedDate;
  final ImagePicker _imagePicker = ImagePicker();
  File? _receiptFile;
  String? _receiptFileName;
  bool _isPdf = false;

  String? _amountError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.monthlyAmount.toStringAsFixed(2),
    );

    // Calculate initial date, but ensure it's not in the future
    final calculatedDate = DateTime(
      widget.selectedYear,
      widget.selectedMonth,
      DateTime.now().day,
    );
    final now = DateTime.now();
    _selectedDate = calculatedDate.isAfter(now) ? now : calculatedDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _amountError = 'Please enter a valid amount';
      });
      return false;
    } else {
      setState(() {
        _amountError = null;
      });
      return true;
    }
  }

  Future<void> _addPayment() async {
    if (!_validateInputs()) {
      return;
    }

    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        showSnackBar(context, 'User not logged in', isError: true);
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? receiptUrl;

    try {
      // Upload receipt if selected
      if (_receiptFile != null) {
        final storageService = ref.read(storageServiceProvider);
        receiptUrl = await storageService.uploadReceipt(
          groupId: widget.groupId,
          userId: userId,
          file: _receiptFile!,
        );
      }

      // Get user profile for name
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getUserProfile(userId);

      // Add payment
      final paymentService = ref.read(paymentServiceProvider);
      await paymentService.addPayment(
        groupId: widget.groupId,
        userId: userId,
        userName: profile?.name ?? 'Unknown',
        amount: double.parse(_amountController.text.trim()),
        paymentDate: _selectedDate,
        notes:
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
        receiptUrl: receiptUrl,
      );

      // Update member stats
      final groupService = ref.read(groupServiceProvider);
      await groupService.updateMemberStats(
        groupId: widget.groupId,
        userId: userId,
        amount: double.parse(_amountController.text.trim()),
      );

      if (mounted) {
        showSnackBar(context, 'Payment added successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Failed to add payment: ${e.toString()}',
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _receiptFile = File(image.path);
          _receiptFileName = image.name;
          _isPdf = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Failed to pick image: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _takeReceiptPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _receiptFile = File(image.path);
          _receiptFileName = image.name;
          _isPdf = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Failed to take photo: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _receiptFile = File(result.files.single.path!);
          _receiptFileName = result.files.single.name;
          _isPdf = true;
        });
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Failed to pick PDF: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  void _removeReceiptFile() {
    setState(() {
      _receiptFile = null;
      _receiptFileName = null;
      _isPdf = false;
    });
  }

  void _showFileSourceDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Receipt'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Image from Gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickReceiptImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _takeReceiptPhoto();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF Document'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickPdfFile();
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Payment')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Record a payment',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your monthly contribution',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // Amount field
              CustomTextField(
                controller: _amountController,
                labelText: 'Amount (RM)',
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
              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Payment Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes field
              CustomTextField(
                controller: _notesController,
                labelText: 'Notes (optional)',
              ),
              const SizedBox(height: 8),
              Text(
                'Add any additional notes about this payment',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 24),

              // Receipt upload section
              const Text(
                'Receipt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              if (_receiptFile == null)
                OutlinedButton.icon(
                  onPressed: _showFileSourceDialog,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Add Receipt'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      if (_isPdf)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.picture_as_pdf,
                                size: 48,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _receiptFileName ?? 'PDF Document',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'PDF Document',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          child: Image.file(
                            _receiptFile!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: _showFileSourceDialog,
                              icon: const Icon(Icons.edit),
                              label: const Text('Change'),
                            ),
                            TextButton.icon(
                              onPressed: _removeReceiptFile,
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text(
                                'Remove',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Attach a photo or PDF of your payment receipt (optional)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _addPayment,
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
                          'Add Payment',
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
