import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/storage_service.dart';
import 'package:duitkita/config/app_theme.dart';
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
  final _formKey = GlobalKey<FormBuilderState>();
  late TextEditingController _amountController;
  final TextEditingController _notesController = TextEditingController();
  late DateTime _selectedDate;
  final ImagePicker _imagePicker = ImagePicker();
  File? _receiptFile;
  String? _receiptFileName;
  bool _isPdf = false;

  bool _isLoading = false;

  // Multi-month selection
  final Set<(int year, int month)> _selectedMonths = {};
  late int _pickerYear;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonths.add((widget.selectedYear, widget.selectedMonth));
    _pickerYear = widget.selectedYear;
    _amountController = TextEditingController(
      text: widget.monthlyAmount.toStringAsFixed(2),
    );
    final calculatedDate = DateTime(widget.selectedYear, widget.selectedMonth, DateTime.now().day);
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
    return _formKey.currentState?.saveAndValidate() ?? false;
  }

  void _toggleMonth(int year, int month) {
    setState(() {
      final key = (year, month);
      if (_selectedMonths.contains(key)) {
        if (_selectedMonths.length > 1) {
          _selectedMonths.remove(key);
        }
      } else {
        _selectedMonths.add(key);
      }
      // Update amount based on selected months
      _amountController.text = (widget.monthlyAmount * _selectedMonths.length).toStringAsFixed(2);
    });
  }

  Future<void> _addPayment() async {
    if (!_validateInputs()) return;
    if (_selectedMonths.isEmpty) return;

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

      final group = ref.read(groupStreamProvider(widget.groupId)).valueOrNull;
      final autoApprove = group?.autoApprovePayments ?? false;

      final paymentService = ref.read(paymentServiceProvider);
      final perMonthAmount = widget.monthlyAmount;
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      // Create a payment for each selected month
      final sortedMonths = _selectedMonths.toList()..sort((a, b) {
        final cmp = a.$1.compareTo(b.$1);
        return cmp != 0 ? cmp : a.$2.compareTo(b.$2);
      });

      for (final (year, month) in sortedMonths) {
        final paymentDate = DateTime(year, month, _selectedDate.day.clamp(1, 28));
        await paymentService.addPayment(
          groupId: widget.groupId,
          userId: userId,
          userName: profile?.name ?? 'Unknown',
          amount: perMonthAmount,
          paymentDate: paymentDate,
          notes: _selectedMonths.length > 1
              ? '${notes != null ? '$notes | ' : ''}${_monthNames[month - 1]} $year'
              : notes,
          receiptUrl: receiptUrl,
          autoApprove: autoApprove,
        );
      }

      final totalAmount = perMonthAmount * _selectedMonths.length;
      final groupService = ref.read(groupServiceProvider);
      await groupService.updateMemberStats(
        groupId: widget.groupId, userId: userId,
        amount: totalAmount,
      );

      if (mounted) {
        final monthCount = _selectedMonths.length;
        final msg = monthCount > 1
            ? '$monthCount months ${autoApprove ? 'confirmed' : 'submitted for review'}!'
            : autoApprove ? 'Payment confirmed automatically!' : 'Payment submitted for review!';
        showSnackBar(context, msg);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed to add payment: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMonthPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Months',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _pickerYear--),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_left, size: 18, color: AppTheme.textSecondary),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('$_pickerYear',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _pickerYear++),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Month grid (4 columns x 3 rows)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isSelected = _selectedMonths.contains((_pickerYear, month));

              return GestureDetector(
                onTap: () => _toggleMonth(_pickerYear, month),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.primaryGradient : null,
                    color: isSelected ? null : AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _monthShort[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),

          // Selected months summary
          if (_selectedMonths.length > 1) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_selectedMonths.length} months \u00d7 RM${widget.monthlyAmount.toStringAsFixed(2)} = RM${(widget.monthlyAmount * _selectedMonths.length).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _styledInputDecoration({
    required String label,
    required IconData prefixIcon,
    String? hint,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textHint),
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textHint),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(prefixIcon, size: 20, color: AppTheme.primary),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Add Payment'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedMonths.length == 1
                      ? '${_monthNames[_selectedMonths.first.$2 - 1]} ${_selectedMonths.first.$1}'
                      : '${_selectedMonths.length} months selected',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedMonths.length > 1
                      ? 'RM${widget.monthlyAmount.toStringAsFixed(0)} x ${_selectedMonths.length} months'
                      : 'Record your monthly contribution',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
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
                    // Bank Account Info
                    if (groupAsync.valueOrNull?.bankName != null &&
                        groupAsync.valueOrNull?.accountNumber != null) ...[
                      _buildBankInfoCard(groupAsync.valueOrNull!),
                      const SizedBox(height: 20),
                    ],

                    // Month Picker
                    _buildMonthPicker(),
                    const SizedBox(height: 16),

                    // Amount
                    FormBuilderTextField(
                      name: 'amount',
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(errorText: 'Amount is required'),
                        FormBuilderValidators.numeric(errorText: 'Enter a valid number'),
                        FormBuilderValidators.min(0.01, errorText: 'Amount must be greater than 0'),
                      ]),
                      decoration: _styledInputDecoration(
                        label: 'Amount',
                        prefixIcon: Icons.payments_outlined,
                        prefixText: 'RM ',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Date
                    FormBuilderDateTimePicker(
                      name: 'paymentDate',
                      initialValue: _selectedDate,
                      inputType: InputType.date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      decoration: _styledInputDecoration(
                        label: 'Payment Date',
                        prefixIcon: Icons.calendar_month_outlined,
                      ),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDate = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    Builder(
                      builder: (context) {
                        final groupName = groupAsync.valueOrNull?.name ?? 'Group';
                        final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
                        final profileAsync = userId != null
                            ? ref.watch(userProfileStreamProvider(userId))
                            : null;
                        final payerName = profileAsync?.valueOrNull?.name ?? 'Name';
                        final monthName = _monthNames[widget.selectedMonth - 1];

                        return FormBuilderTextField(
                          name: 'notes',
                          controller: _notesController,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                          decoration: _styledInputDecoration(
                            label: 'Notes',
                            prefixIcon: Icons.note_outlined,
                            hint: 'e.g. $groupName, $payerName, $monthName ${widget.selectedYear}',
                          ),
                        );
                      },
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
                            const Text(
                              'Upload Receipt',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Photo or PDF (optional)',
                              style: TextStyle(fontSize: 12, color: AppTheme.textHint),
                            ),
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
                          // Preview
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                                  top: 8,
                                  right: 8,
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

                          // Actions
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
                      onPressed: _isLoading ? null : _addPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Submit Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  // Bank brand colors and gradients
  static final Map<String, _BankTheme> _bankThemes = {
    'maybank': _BankTheme(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFC72C), Color(0xFFFFB300)],
      ),
      textColor: Color(0xFF1A1A1A),
      subtextColor: Color(0xFF4A4A4A),
      accentColor: Color(0xFF1A1A1A),
    ),
    'cimb': _BankTheme(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEC1C24), Color(0xFFC41019)],
      ),
      textColor: Colors.white,
      subtextColor: Color(0xFFFFCDD2),
      accentColor: Colors.white,
    ),
    'rhb': _BankTheme(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF003DA5), Color(0xFF002D7A)],
      ),
      textColor: Colors.white,
      subtextColor: Color(0xFFBBDEFB),
      accentColor: Colors.white,
    ),
    'public bank': _BankTheme(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE8E8E8), Color(0xFFD0D0D0)],
      ),
      textColor: Color(0xFF1A1A1A),
      subtextColor: Color(0xFF616161),
      accentColor: Color(0xFFC62828),
    ),
    'bank islam': _BankTheme(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00695C), Color(0xFF004D40)],
      ),
      textColor: Colors.white,
      subtextColor: Color(0xFFB2DFDB),
      accentColor: Color(0xFFFFD54F),
    ),
    'bank rakyat': _BankTheme(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
      ),
      textColor: Colors.white,
      subtextColor: Color(0xFFC8E6C9),
      accentColor: Color(0xFFFFD54F),
    ),
    'hong leong': _BankTheme(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
      ),
      textColor: Colors.white,
      subtextColor: Color(0xFFBBDEFB),
      accentColor: Colors.white,
    ),
    'ambank': _BankTheme(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A237E), Color(0xFF283593)],
      ),
      textColor: Colors.white,
      subtextColor: Color(0xFFC5CAE9),
      accentColor: Color(0xFFFF8F00),
    ),
    'bsn': _BankTheme(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE65100), Color(0xFFEF6C00)],
      ),
      textColor: Colors.white,
      subtextColor: Color(0xFFFFE0B2),
      accentColor: Colors.white,
    ),
    'affin': _BankTheme(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF880E4F), Color(0xFFAD1457)],
      ),
      textColor: Colors.white,
      subtextColor: Color(0xFFF8BBD0),
      accentColor: Colors.white,
    ),
  };

  static final _defaultBankTheme = _BankTheme(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF37474F), Color(0xFF546E7A)],
    ),
    textColor: Colors.white,
    subtextColor: Color(0xFFB0BEC5),
    accentColor: Colors.white,
  );

  _BankTheme _getBankTheme(String? bankName) {
    if (bankName == null) return _defaultBankTheme;
    final lower = bankName.toLowerCase();
    for (final entry in _bankThemes.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return _defaultBankTheme;
  }

  Widget _buildBankInfoCard(dynamic group) {
    final theme = _getBankTheme(group.bankName);
    final bankName = group.bankName ?? 'Bank';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: theme.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bank name and chip icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bankName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(Icons.account_balance, color: theme.accentColor.withValues(alpha: 0.6), size: 28),
            ],
          ),
          const SizedBox(height: 20),

          // Account number
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: group.accountNumber ?? ''));
              showSnackBar(context, 'Account number copied');
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatAccountNumber(group.accountNumber ?? ''),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                      letterSpacing: 2.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Icon(Icons.copy_rounded, color: theme.textColor.withValues(alpha: 0.5), size: 18),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account holder name
          if (group.accountHolderName != null) ...[
            Text(
              'ACCOUNT HOLDER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.subtextColor,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              (group.accountHolderName as String).toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatAccountNumber(String number) {
    final clean = number.replaceAll(RegExp(r'[\s-]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
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
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _BankTheme {
  final LinearGradient gradient;
  final Color textColor;
  final Color subtextColor;
  final Color accentColor;

  const _BankTheme({
    required this.gradient,
    required this.textColor,
    required this.subtextColor,
    required this.accentColor,
  });
}
