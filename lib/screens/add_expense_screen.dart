import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/storage_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/widgets/floating_field.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;
  const AddExpenseScreen({super.key, required this.groupId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  File? _receiptFile;
  String? _receiptFileName;
  String? _receiptSource; // 'camera' | 'gallery' | 'pdf'
  bool _isLoading = false;
  String _category = 'food';

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_rebuild);
    _titleCtrl.addListener(_rebuild);
    _notesCtrl.addListener(_rebuild);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_rebuild);
    _titleCtrl.removeListener(_rebuild);
    _notesCtrl.removeListener(_rebuild);
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  double? get _parsedAmount =>
      double.tryParse(_amountCtrl.text.replaceAll(',', ''));
  bool get _canSubmit =>
      _titleCtrl.text.trim().isNotEmpty && (_parsedAmount ?? 0) > 0;
  String get _amountDisplay {
    final a = _parsedAmount;
    return (a != null && a > 0) ? 'RM ${a.toStringAsFixed(2)}' : 'Enter amount';
  }

  void _addAmount(double delta) {
    final current = _parsedAmount ?? 0;
    _amountCtrl.text = (current + delta).toStringAsFixed(2);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final title = _titleCtrl.text.trim();
    final amount = _parsedAmount!;
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) {
      showSnackBar(context, 'Not logged in', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    String? receiptUrl;
    try {
      if (_receiptFile != null) {
        receiptUrl = await ref
            .read(storageServiceProvider)
            .uploadReceipt(
              groupId: widget.groupId,
              userId: userId,
              file: _receiptFile!,
            );
      }
      final profile = await ref
          .read(profileServiceProvider)
          .getUserProfile(userId);
      final group = await ref.read(groupStreamProvider(widget.groupId).future);
      final autoApprove = group?.autoApproveExpenses ?? false;
      final userName = profile?.name ?? 'Unknown';

      await ref
          .read(expenseServiceProvider)
          .submitExpense(
            groupId: widget.groupId,
            requestedBy: userId,
            requestedByName: userName,
            title: title,
            description:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            amount: amount,
            receiptUrl: receiptUrl,
            autoApprove: autoApprove,
            approvedByName: autoApprove ? userName : null,
          );

      if (mounted) {
        showSnackBar(
          context,
          autoApprove ? 'Expense auto-approved!' : 'Request submitted!',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final img = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (img != null) {
        setState(() {
          _receiptFile = File(img.path);
          _receiptFileName = img.name;
          _receiptSource = 'gallery';
        });
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed: $e', isError: true);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final img = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (img != null) {
        setState(() {
          _receiptFile = File(img.path);
          _receiptFileName = img.name;
          _receiptSource = 'camera';
        });
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed: $e', isError: true);
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result?.files.single.path != null) {
        setState(() {
          _receiptFile = File(result!.files.single.path!);
          _receiptFileName = result.files.single.name;
          _receiptSource = 'pdf';
        });
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed: $e', isError: true);
    }
  }

  void _removeReceipt() => setState(() {
    _receiptFile = null;
    _receiptFileName = null;
    _receiptSource = null;
  });

  @override
  Widget build(BuildContext context) {
    final cats = [
      (
        id: 'food',
        label: 'Food',
        icon: Icons.restaurant_outlined,
        color: DT.catBills,
        soft: DT.catBillsSoft,
      ),
      (
        id: 'travel',
        label: 'Travel',
        icon: Icons.flight_takeoff_outlined,
        color: DT.catGroups,
        soft: DT.catGroupsSoft,
      ),
      (
        id: 'utility',
        label: 'Utility',
        icon: Icons.home_outlined,
        color: DT.catDebts,
        soft: DT.catDebtsSoft,
      ),
      (
        id: 'other',
        label: 'Other',
        icon: Icons.apps_outlined,
        color: DT.accent,
        soft: DT.accentSoft,
      ),
    ];

    return Scaffold(
      backgroundColor: DT.bg,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            color: DT.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DS.xl, DS.sm, DS.xl, DS.xxl),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Expense',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Submit an expense request',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: DT.accent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.request_quote_outlined,
                        size: 18,
                        color: Color(0xFF003830),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Scrollable body ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Amount hero card — floats 12 px over the header
                  Transform.translate(
                    offset: const Offset(0, -12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DS.xl),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        decoration: BoxDecoration(
                          color: DT.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: DT.border),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0B1F3A,
                              ).withValues(alpha: 0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AMOUNT',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: DT.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'RM',
                                  style: GoogleFonts.manrope(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: DT.textTertiary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _amountCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: GoogleFonts.manrope(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      color: DT.text,
                                      letterSpacing: -1.2,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      hintStyle: GoogleFonts.manrope(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800,
                                        color: DT.border,
                                        letterSpacing: -1.2,
                                      ),
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Quick-add buttons
                            Row(
                              children:
                                  [10.0, 25.0, 50.0, 100.0].asMap().entries.map(
                                    (e) {
                                      final isLast = e.key == 3;
                                      return Expanded(
                                        child: GestureDetector(
                                          onTap: () => _addAmount(e.value),
                                          child: Container(
                                            margin: EdgeInsets.only(
                                              right: isLast ? 0 : 6,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: DT.surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              border: Border.all(
                                                color: DT.border,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '+${e.value.toInt()}',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: DT.text,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Form fields (4 px top gap accounts for the -12 hero transform above)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(DS.xl, 4, DS.xl, DS.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title ──────────────────────────────────────────
                        FloatingField(
                          controller: _titleCtrl,
                          label: 'Title',
                          icon: Icons.edit_outlined,
                          hint: "What's this expense for?",
                          maxLength: 60,
                          showCounter: true,
                          capitalization: TextCapitalization.sentences,
                        ),

                        const SizedBox(height: DS.sm),

                        // ── Category ───────────────────────────────────────
                        Text(
                          'CATEGORY',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: DT.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children:
                              cats.asMap().entries.map((e) {
                                final cat = e.value;
                                final isLast = e.key == 3;
                                final active = _category == cat.id;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap:
                                        () =>
                                            setState(() => _category = cat.id),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      margin: EdgeInsets.only(
                                        right: isLast ? 0 : 8,
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        6,
                                        10,
                                        6,
                                        10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: active ? cat.soft : DT.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: active ? cat.color : DT.border,
                                          width: active ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            cat.icon,
                                            size: 18,
                                            color:
                                                active
                                                    ? cat.color
                                                    : DT.textSecondary,
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            cat.label,
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  active ? cat.color : DT.text,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),

                        const SizedBox(height: DS.md),

                        // ── Notes ──────────────────────────────────────────
                        FloatingField(
                          controller: _notesCtrl,
                          label: 'Notes',
                          icon: Icons.notes_rounded,
                          hint: 'Add any relevant details…',
                          optional: true,
                          maxLines: 3,
                          maxLength: 200,
                          showCounter: true,
                          capitalization: TextCapitalization.sentences,
                        ),

                        const SizedBox(height: DS.md),

                        // ── Receipt ────────────────────────────────────────
                        Text(
                          'RECEIPT',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: DT.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (_receiptFile == null)
                          // Empty state — direct chip actions
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
                            decoration: BoxDecoration(
                              color: DT.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: DT.borderStrong),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: DT.surfaceAlt,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.upload_outlined,
                                    size: 20,
                                    color: DT.text,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Attach receipt',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: DT.text,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Helps approval go faster',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: DT.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ReceiptChip(
                                        icon: Icons.camera_alt_outlined,
                                        label: 'Camera',
                                        onTap: _takePhoto,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ReceiptChip(
                                        icon: Icons.photo_library_outlined,
                                        label: 'Gallery',
                                        onTap: _pickImage,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ReceiptChip(
                                        icon: Icons.picture_as_pdf_outlined,
                                        label: 'PDF',
                                        onTap: _pickPdf,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          // Attached state
                          Container(
                            decoration: BoxDecoration(
                              color: DT.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: DT.border),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(13),
                                    bottomLeft: Radius.circular(13),
                                  ),
                                  child:
                                      _receiptSource == 'pdf'
                                          ? Container(
                                            width: 62,
                                            height: 70,
                                            color: DT.dangerSoft,
                                            child: const Icon(
                                              Icons.picture_as_pdf,
                                              size: 26,
                                              color: DT.danger,
                                            ),
                                          )
                                          : Image.file(
                                            _receiptFile!,
                                            width: 62,
                                            height: 70,
                                            fit: BoxFit.cover,
                                          ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _receiptFileName ?? 'Attached file',
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: DT.text,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'via ${_receiptSource ?? 'file'}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          color: DT.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _removeReceipt,
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: DT.surfaceAlt,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                      color: DT.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sticky submit footer ───────────────────────────────────────
          Container(
            color: DT.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DS.xl, DS.sm, DS.xl, DS.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(height: 1, color: DT.border),
                    const SizedBox(height: DS.sm),
                    GestureDetector(
                      onTap: (_isLoading || !_canSubmit) ? null : _submit,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 54,
                        decoration: BoxDecoration(
                          color: _canSubmit ? DT.text : DT.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _amountDisplay,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _canSubmit
                                          ? Colors.white.withValues(alpha: 0.65)
                                          : DT.textTertiary,
                                ),
                              ),
                              if (_isLoading)
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Text(
                                      'Submit request',
                                      style: GoogleFonts.manrope(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                        color:
                                            _canSubmit
                                                ? Colors.white
                                                : DT.textTertiary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                      color:
                                          _canSubmit
                                              ? Colors.white
                                              : DT.textTertiary,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
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

// ─── Receipt action chip ───────────────────────────────────────────────────────

class _ReceiptChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ReceiptChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DT.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: DT.text),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DT.text,
            ),
          ),
        ],
      ),
    ),
  );
}
