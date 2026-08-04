import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/config/bank_brands.dart';
import 'package:duitkita/models/payment_model.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/storage_service.dart';
import 'package:duitkita/widgets/floating_field.dart';
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
  String _dateChoice = 'today'; // 'today' | 'yesterday' | 'custom'

  final ImagePicker _imagePicker = ImagePicker();
  File? _receiptFile;
  String? _receiptFileName;
  bool _isPdf = false;
  bool _isLoading = false;
  bool _amountLocked = true;
  bool _copied = false;

  // months are 1-based (1–12)
  final Set<(int year, int month)> _selectedMonths = {};
  late int _pickerYear;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _monthShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonths.add((widget.selectedYear, widget.selectedMonth));
    _pickerYear = widget.selectedYear;
    _amountController = TextEditingController(
      text: widget.monthlyAmount.toStringAsFixed(2),
    );
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Derived state ──────────────────────────────────────────────────────────

  bool get _amountValid {
    final v = double.tryParse(_amountController.text);
    return v != null && v > 0;
  }

  List<(int, int)> get _sortedMonths =>
      _selectedMonths.toList()..sort((a, b) {
        final cmp = a.$1.compareTo(b.$1);
        return cmp != 0 ? cmp : a.$2.compareTo(b.$2);
      });

  DateTime get _effectiveDate {
    final now = DateTime.now();
    return switch (_dateChoice) {
      'yesterday' => now.subtract(const Duration(days: 1)),
      'custom' => _selectedDate,
      _ => now,
    };
  }

  String get _dateLabel {
    final now = DateTime.now();
    return switch (_dateChoice) {
      'yesterday' => () {
        final y = now.subtract(const Duration(days: 1));
        return 'Yesterday, ${y.day} ${_monthShort[y.month - 1]}';
      }(),
      'custom' =>
        '${_selectedDate.day} ${_monthShort[_selectedDate.month - 1]} ${_selectedDate.year}',
      _ => 'Today, ${now.day} ${_monthShort[now.month - 1]}',
    };
  }

  String get _selectionLabel {
    if (_selectedMonths.length == 1) {
      final m = _sortedMonths.first;
      return '${_monthNames[m.$2 - 1]} ${m.$1}';
    }
    return '${_selectedMonths.length} months';
  }

  // ── Data-layer methods (unchanged) ─────────────────────────────────────────

  void _toggleMonth(int year, int month, Set<(int, int)> paidMonths) {
    if (paidMonths.contains((year, month))) return; // locked — already paid
    setState(() {
      final key = (year, month);
      if (_selectedMonths.contains(key)) {
        if (_selectedMonths.length > 1) _selectedMonths.remove(key);
      } else {
        _selectedMonths.add(key);
      }
      if (_amountLocked) {
        _amountController.text = (widget.monthlyAmount * _selectedMonths.length)
            .toStringAsFixed(2);
      }
    });
  }

  void _selectMonthsAhead(int n, Set<(int, int)> paidMonths) {
    final now = DateTime.now();
    final result = <(int, int)>[];
    int y = now.year;
    int m = now.month;
    while (result.length < n) {
      if (!paidMonths.contains((y, m))) result.add((y, m));
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    setState(() {
      _selectedMonths
        ..clear()
        ..addAll(result);
      if (_amountLocked) {
        _amountController.text = (widget.monthlyAmount * _selectedMonths.length)
            .toStringAsFixed(2);
      }
    });
  }

  Future<void> _addPayment({required bool autoApprove}) async {
    if (!_amountValid || _selectedMonths.isEmpty) return;

    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        showSnackBar(context, 'User not logged in');
      }
      return;
    }

    setState(() => _isLoading = true);
    final nav = Navigator.of(context);
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
      final paymentService = ref.read(paymentServiceProvider);
      final notes =
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim();
      final date = _effectiveDate;

      // Use the amount the user actually entered (Full / Half / Custom), not the
      // group's full monthly figure. For multi-month it's the total, split
      // evenly across the selected months.
      final totalAmount =
          double.tryParse(_amountController.text) ?? widget.monthlyAmount;
      final perMonthAmount = totalAmount / _selectedMonths.length;

      for (final (year, month) in _sortedMonths) {
        final paymentDate = DateTime(year, month, date.day.clamp(1, 28));
        await paymentService.addPayment(
          groupId: widget.groupId,
          userId: userId,
          userName: profile?.name ?? 'Unknown',
          amount: perMonthAmount,
          paymentDate: paymentDate,
          notes:
              _selectedMonths.length > 1
                  ? '${notes != null ? '$notes | ' : ''}${_monthNames[month - 1]} $year'
                  : notes,
          receiptUrl: receiptUrl,
          autoApprove: autoApprove,
        );
      }

      await ref
          .read(groupServiceProvider)
          .updateMemberStats(
            groupId: widget.groupId,
            userId: userId,
            amount: totalAmount,
            count: _selectedMonths.length,
          );

      if (!mounted) return;
      final monthCount = _selectedMonths.length;
      final msg =
          monthCount > 1
              ? '$monthCount months ${autoApprove ? 'confirmed' : 'submitted for review'}!'
              : autoApprove
              ? 'Payment confirmed automatically!'
              : 'Payment submitted for review!';
      showSnackBar(context, msg);
      nav.pop();
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Failed to add payment: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickReceiptImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _receiptFile = File(image.path);
          _receiptFileName = image.name;
          _isPdf = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _takeReceiptPhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _receiptFile = File(image.path);
          _receiptFileName = image.name;
          _isPdf = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to take photo: $e');
      }
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null && mounted) {
        setState(() {
          _receiptFile = File(result.files.single.path!);
          _receiptFileName = result.files.single.name;
          _isPdf = true;
        });
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to pick PDF: $e');
      }
    }
  }

  void _removeReceiptFile() => setState(() {
    _receiptFile = null;
    _receiptFileName = null;
    _isPdf = false;
  });

  void _showFileSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DT.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.lg, DS.xl, DS.lg, DS.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Receipt',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: DT.text,
                    ),
                  ),
                  const SizedBox(height: DS.lg),
                  _sourceOption(
                    Icons.photo_library_outlined,
                    'Image from Gallery',
                    DT.accent,
                    () {
                      Navigator.pop(ctx);
                      _pickReceiptImage();
                    },
                  ),
                  _sourceOption(
                    Icons.camera_alt_outlined,
                    'Take Photo',
                    DT.info,
                    () {
                      Navigator.pop(ctx);
                      _takeReceiptPhoto();
                    },
                  ),
                  _sourceOption(
                    Icons.picture_as_pdf_outlined,
                    'PDF Document',
                    DT.danger,
                    () {
                      Navigator.pop(ctx);
                      _pickPdfFile();
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _sourceOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DS.md),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: DT.text,
        ),
      ),
      onTap: onTap,
    );
  }

  String _formatAcct(String raw) {
    final clean = raw.replaceAll(RegExp(r'[\s-]'), '');
    final buf = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(clean[i]);
    }
    return buf.toString();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  // Returns true if the user has a confirmed or pending payment for (year, month)
  Set<(int, int)> _paidMonths(List<PaymentModel> payments) {
    final result = <(int, int)>{};
    for (final p in payments) {
      if (p.paymentStatus == 'confirmed' || p.paymentStatus == 'pending') {
        // Use the canonical month/year fields (the month the payment covers),
        // not paymentDate — that's what every payment query keys off.
        result.add((p.year, p.month));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));
    final group = groupAsync.valueOrNull;
    final autoApprove = group?.autoApprovePayments ?? false;
    final groupName = group?.name ?? 'Group';
    final hasBankInfo = group?.bankName != null && group?.accountNumber != null;

    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final paymentsAsync =
        userId != null
            ? ref.watch(
              userPaymentsInGroupStreamProvider((
                groupId: widget.groupId,
                userId: userId,
              )),
            )
            : null;
    final paidMonths = _paidMonths(paymentsAsync?.valueOrNull ?? []);

    return Scaffold(
      backgroundColor: DT.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, groupName, autoApprove),
          if (hasBankInfo)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DS.screenPad),
              child: Transform.translate(
                offset: const Offset(0, -6),
                child: _buildBankCard(group),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DS.screenPad,
                  DS.xl,
                  DS.screenPad,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Month section ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionLabel(
                          _selectedMonths.length > 1
                              ? 'PAY FOR ${_selectedMonths.length} MONTHS'
                              : 'PAY FOR WHICH MONTH',
                        ),
                        if (_selectedMonths.length > 1)
                          GestureDetector(
                            onTap:
                                () => setState(() {
                                  _selectedMonths
                                    ..clear()
                                    ..add((
                                      widget.selectedYear,
                                      widget.selectedMonth,
                                    ));
                                  if (_amountLocked) {
                                    _amountController.text = widget
                                        .monthlyAmount
                                        .toStringAsFixed(2);
                                  }
                                }),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.close,
                                  size: 11,
                                  color: DT.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Clear',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: DT.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: DS.sm),
                    _buildMonthPicker(paidMonths),
                    const SizedBox(height: DS.sm),
                    _buildQuickPresets(paidMonths),
                    const SizedBox(height: DS.lg),

                    // ── Breakdown (multi only) ─────────────────────
                    if (_selectedMonths.length > 1) ...[
                      _buildBreakdownCard(paidMonths),
                      const SizedBox(height: DS.lg),
                    ],

                    // ── Amount ─────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionLabel('AMOUNT'),
                        if (_selectedMonths.length > 1)
                          GestureDetector(
                            onTap:
                                () => setState(() {
                                  _amountLocked = !_amountLocked;
                                  if (_amountLocked) {
                                    _amountController.text = (widget
                                                .monthlyAmount *
                                            _selectedMonths.length)
                                        .toStringAsFixed(2);
                                  }
                                }),
                            child: Row(
                              children: [
                                Icon(
                                  _amountLocked
                                      ? Icons.lock_outline_rounded
                                      : Icons.edit_outlined,
                                  size: 11,
                                  color:
                                      _amountLocked
                                          ? DT.accentDeep
                                          : DT.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _amountLocked ? 'Auto-calculated' : 'Editing',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        _amountLocked
                                            ? DT.accentDeep
                                            : DT.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: DS.sm),
                    _buildAmountCard(),
                    const SizedBox(height: DS.lg),

                    // ── Date ───────────────────────────────────────
                    _sectionLabel('PAYMENT DATE'),
                    const SizedBox(height: DS.sm),
                    _buildDateCard(),
                    const SizedBox(height: DS.lg),

                    // ── Reference ──────────────────────────────────
                    FloatingField(
                      controller: _notesController,
                      label: 'Reference',
                      icon: Icons.receipt_long_outlined,
                      hint: 'Bank transaction ID, e.g. MB240518…',
                      optional: true,
                    ),
                    const SizedBox(height: DS.sm),

                    // ── Receipt ────────────────────────────────────
                    _sectionLabel('RECEIPT · OPTIONAL'),
                    const SizedBox(height: DS.sm),
                    _buildReceiptSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFooter(autoApprove),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.manrope(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: DT.textSecondary,
      letterSpacing: 0.5,
    ),
  );

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    String groupName,
    bool autoApprove,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DT.headerGradientStart, DT.headerGradientEnd],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DS.lg, DS.md, DS.lg, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Payment',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          '$groupName · monthly contribution',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (autoApprove) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: DT.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(DS.chipRadius),
                    border: Border.all(color: DT.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: DT.accent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Auto-approve enabled',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: DT.accent,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Bank card ──────────────────────────────────────────────────────────────

  Widget _buildBankCard(dynamic group) {
    final bt = bankBrandFor(group.bankName as String?);
    final formatted = _formatAcct(group.accountNumber as String? ?? '');
    final holder = (group.accountHolderName as String?) ?? '';

    return Container(
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: DT.border),
        boxShadow: [
          BoxShadow(
            color: DT.text.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(DS.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Bank tile
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bt.tile,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_balance, size: 18, color: bt.icon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAY TO',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: DT.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      group.bankName as String? ?? '',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: DT.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Copy button
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: group.accountNumber as String? ?? ''),
                  );
                  setState(() => _copied = true);
                  Future.delayed(const Duration(milliseconds: 1600), () {
                    if (mounted) setState(() => _copied = false);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _copied ? DT.successSoft : DT.surfaceAlt,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _copied ? DT.success : DT.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 12,
                        color: _copied ? DT.success : DT.text,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _copied ? 'Copied' : 'Copy',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _copied ? DT.success : DT.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Account number
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: DT.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              formatted,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DT.text,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACCOUNT HOLDER',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: DT.textTertiary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    holder.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DT.text,
                    ),
                  ),
                ],
              ),
              // QR button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: DT.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  size: 18,
                  color: DT.accentDeep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Month picker ───────────────────────────────────────────────────────────

  Widget _buildMonthPicker(Set<(int, int)> paidMonths) {
    final now = DateTime.now();
    final isCurrentYear = _pickerYear == now.year;

    return Container(
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: DT.border),
      ),
      padding: const EdgeInsets.all(DS.md),
      child: Column(
        children: [
          // Year stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _yearNavBtn(
                Icons.chevron_left,
                () => setState(() => _pickerYear--),
              ),
              Row(
                children: [
                  Text(
                    '$_pickerYear',
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: DT.text,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (isCurrentYear) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DT.accentSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'CURRENT',
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: DT.accentDeep,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              _yearNavBtn(
                Icons.chevron_right,
                () => setState(() => _pickerYear++),
              ),
            ],
          ),
          const SizedBox(height: DS.md),
          // Month grid
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 2.2,
            ),
            itemCount: 12,
            itemBuilder: (_, index) {
              final month = index + 1;
              final isPaid = paidMonths.contains((_pickerYear, month));
              final isSelected = _selectedMonths.contains((_pickerYear, month));
              final isFuture =
                  _pickerYear > now.year ||
                  (_pickerYear == now.year && month > now.month);
              final sorted = _sortedMonths;
              final selIdx = sorted.indexWhere(
                (s) => s.$1 == _pickerYear && s.$2 == month,
              );

              return GestureDetector(
                onTap:
                    isPaid
                        ? null
                        : () => _toggleMonth(_pickerYear, month, paidMonths),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color:
                        isPaid
                            ? DT.successSoft
                            : isSelected
                            ? DT.text
                            : DT.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          isPaid
                              ? DT.successSoft
                              : isSelected
                              ? DT.text
                              : DT.border,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPaid) ...[
                            const Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: DT.success,
                            ),
                            const SizedBox(width: 2),
                          ],
                          Text(
                            _monthShort[index],
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  isPaid
                                      ? DT.success
                                      : isSelected
                                      ? Colors.white
                                      : isFuture
                                      ? DT.textTertiary
                                      : DT.text,
                            ),
                          ),
                        ],
                      ),
                      // Selection order badge
                      if (isSelected && selIdx >= 0)
                        Positioned(
                          top: 3,
                          right: 5,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: DT.accent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${selIdx + 1}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF003830),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Legend
          const SizedBox(height: 12),
          const Divider(height: 1, color: DT.border),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendDot(fill: DT.text),
              const SizedBox(width: 4),
              Text(
                'Selected',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: DT.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              _legendDot(fill: DT.successSoft, border: DT.success),
              const SizedBox(width: 4),
              Text(
                'Paid',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: DT.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              _legendDot(border: DT.borderStrong),
              const SizedBox(width: 4),
              Text(
                'Open',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: DT.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _yearNavBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: DT.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DT.border),
      ),
      child: Icon(icon, size: 14, color: DT.text),
    ),
  );

  Widget _legendDot({Color? fill, Color? border}) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: fill ?? Colors.transparent,
      borderRadius: BorderRadius.circular(3),
      border: border != null ? Border.all(color: border) : null,
    ),
  );

  // ── Quick presets ──────────────────────────────────────────────────────────

  Widget _buildQuickPresets(Set<(int, int)> paidMonths) {
    const presets = [
      (1, 'This month'),
      (3, '3 months'),
      (6, '6 months'),
      (12, '12 months'),
    ];
    return Row(
      children:
          presets.indexed.map((entry) {
            final i = entry.$1;
            final p = entry.$2;
            final active = _selectedMonths.length == p.$1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
                child: GestureDetector(
                  onTap: () => _selectMonthsAhead(p.$1, paidMonths),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: active ? DT.accentSoft : DT.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: active ? DT.accent : DT.border),
                    ),
                    child: Text(
                      p.$2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active ? DT.accentDeep : DT.text,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  // ── Breakdown card ─────────────────────────────────────────────────────────

  Widget _buildBreakdownCard(Set<(int, int)> paidMonths) {
    final sorted = _sortedMonths;
    return Container(
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: DT.accent),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paying for ${_selectedMonths.length} months',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DT.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DT.accentSoft,
                  borderRadius: BorderRadius.circular(DS.chipRadius),
                ),
                child: Text(
                  '${_selectedMonths.length} × RM ${widget.monthlyAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DT.accentDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                sorted.indexed.map((entry) {
                  final i = entry.$1;
                  final s = entry.$2;
                  return Container(
                    padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
                    decoration: BoxDecoration(
                      color: DT.surfaceAlt,
                      borderRadius: BorderRadius.circular(DS.chipRadius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: DT.text,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_monthShort[s.$2 - 1]} ${s.$1.toString().substring(2)}',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: DT.text,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _toggleMonth(s.$1, s.$2, paidMonths),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: DT.borderStrong,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.close,
                              size: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Amount card ────────────────────────────────────────────────────────────

  Widget _buildAmountCard() {
    final parsed = double.tryParse(_amountController.text) ?? 0;
    final isMulti = _selectedMonths.length > 1;
    final isPartial = !isMulti && _amountValid && parsed < widget.monthlyAmount;
    final mismatch =
        isMulti &&
        !_amountLocked &&
        (parsed - widget.monthlyAmount * _selectedMonths.length).abs() > 0.01;

    return Container(
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: DT.border),
      ),
      padding: const EdgeInsets.all(DS.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'RM',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: DT.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: !isMulti || !_amountLocked,
                  style: GoogleFonts.manrope(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: DT.text,
                    letterSpacing: -1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: GoogleFonts.manrope(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: DT.border,
                      letterSpacing: -1.2,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() => _amountLocked = false),
                ),
              ),
            ],
          ),
          if (isMulti && _amountLocked) ...[
            const SizedBox(height: 6),
            Text(
              '${_selectedMonths.length} months × RM ${widget.monthlyAmount.toStringAsFixed(2)}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DT.textSecondary,
              ),
            ),
          ],
          if (!isMulti) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _amountChip(
                  label: 'Full · RM ${widget.monthlyAmount.toStringAsFixed(0)}',
                  active: parsed == widget.monthlyAmount,
                  onTap:
                      () => setState(() {
                        _amountLocked = true;
                        _amountController.text = widget.monthlyAmount
                            .toStringAsFixed(2);
                      }),
                ),
                const SizedBox(width: 6),
                _amountChip(
                  label:
                      'Half · RM ${(widget.monthlyAmount / 2).toStringAsFixed(0)}',
                  active: parsed == widget.monthlyAmount / 2,
                  onTap:
                      () => setState(() {
                        _amountLocked = false;
                        _amountController.text = (widget.monthlyAmount / 2)
                            .toStringAsFixed(2);
                      }),
                ),
                const SizedBox(width: 6),
                _amountChip(
                  label: 'Custom',
                  active:
                      _amountValid &&
                      parsed != widget.monthlyAmount &&
                      parsed != widget.monthlyAmount / 2,
                  onTap: null,
                ),
              ],
            ),
          ],
          if (isPartial) ...[
            const SizedBox(height: 12),
            _warningBanner(
              'Partial payment. RM ${(widget.monthlyAmount - parsed).toStringAsFixed(2)} will remain for $_selectionLabel.',
            ),
          ],
          if (mismatch) ...[
            const SizedBox(height: 12),
            _warningBanner(
              "Amount doesn't match ${_selectedMonths.length} × RM ${widget.monthlyAmount.toStringAsFixed(0)} = RM ${(widget.monthlyAmount * _selectedMonths.length).toStringAsFixed(2)}.",
            ),
          ],
        ],
      ),
    );
  }

  Widget _amountChip({
    required String label,
    required bool active,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? DT.accentSoft : DT.surfaceAlt,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? DT.accent : DT.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? DT.accentDeep : DT.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _warningBanner(String text) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: DT.warningSoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: DT.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: DT.text,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  // ── Date card ──────────────────────────────────────────────────────────────

  Widget _buildDateCard() {
    const options = [
      ('today', 'Today'),
      ('yesterday', 'Yesterday'),
      ('custom', 'Pick date'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: DT.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children:
                options.indexed.map((entry) {
                  final i = entry.$1;
                  final opt = entry.$2;
                  final active = _dateChoice == opt.$1;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      child: GestureDetector(
                        onTap: () async {
                          if (opt.$1 == 'custom') {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                _dateChoice = 'custom';
                                _selectedDate = picked;
                              });
                            }
                          } else {
                            setState(() => _dateChoice = opt.$1);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active ? DT.text : DT.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active ? DT.text : DT.border,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (active) ...[
                                const Icon(
                                  Icons.check_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                opt.$2,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active ? Colors.white : DT.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          if (_dateChoice == 'custom') ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: DT.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: DT.text,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_selectedDate.day} ${_monthShort[_selectedDate.month - 1]} ${_selectedDate.year}',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DT.text,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: DT.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Receipt section ────────────────────────────────────────────────────────

  Widget _buildReceiptSection() {
    if (_receiptFile == null) {
      return GestureDetector(
        onTap: _showFileSourceDialog,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: DT.surface,
            borderRadius: BorderRadius.circular(DS.cardRadius),
            border: Border.all(color: DT.border, width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DT.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: DT.text,
                  size: 28,
                ),
              ),
              const SizedBox(height: DS.md),
              Text(
                'Upload Receipt',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DT.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Photo or PDF (optional)',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: DT.textTertiary,
                ),
              ),
              const SizedBox(height: DS.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _uploadChip(Icons.photo_library_outlined, 'Gallery'),
                  const SizedBox(width: DS.sm),
                  _uploadChip(Icons.camera_alt_outlined, 'Camera'),
                  const SizedBox(width: DS.sm),
                  _uploadChip(Icons.picture_as_pdf_outlined, 'PDF'),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: DT.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          if (_isPdf)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DS.xl),
              decoration: BoxDecoration(
                color: DT.dangerSoft,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(DS.cardRadius),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DS.md),
                    decoration: BoxDecoration(
                      color: DT.danger.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf,
                      size: 32,
                      color: DT.danger,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _receiptFileName ?? 'PDF Document',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DT.text,
                    ),
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(DS.cardRadius),
                  ),
                  child: Image.file(
                    _receiptFile!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: DS.sm,
                  right: DS.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DT.success,
                      borderRadius: BorderRadius.circular(DS.chipRadius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Attached',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
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
                    label: Text(
                      'Change',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DT.text,
                      side: const BorderSide(color: DT.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DS.md),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _removeReceiptFile,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(
                      'Remove',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DT.danger,
                      side: BorderSide(
                        color: DT.danger.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DS.md),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.md, vertical: 6),
    decoration: BoxDecoration(
      color: DT.primarySoft,
      borderRadius: BorderRadius.circular(DS.chipRadius),
      border: Border.all(color: DT.borderStrong),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: DT.text),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: DT.text,
          ),
        ),
      ],
    ),
  );

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(bool autoApprove) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final isMulti = _selectedMonths.length > 1;

    return Container(
      decoration: const BoxDecoration(
        color: DT.surface,
        border: Border(top: BorderSide(color: DT.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DS.screenPad,
            12,
            DS.screenPad,
            14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary row
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_selectionLabel · $_dateLabel',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DT.textSecondary,
                      ),
                    ),
                    Text(
                      'RM ${_amountValid ? amount.toStringAsFixed(2) : '0.00'}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: DT.text,
                      ),
                    ),
                  ],
                ),
              ),
              // CTA
              GestureDetector(
                onTap:
                    (_amountValid && !_isLoading)
                        ? () => _addPayment(autoApprove: autoApprove)
                        : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _amountValid ? DT.accent : DT.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow:
                        _amountValid
                            ? [
                              BoxShadow(
                                color: DT.accent.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ]
                            : null,
                  ),
                  child:
                      _isLoading
                          ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                                color: _amountValid ? DT.text : DT.textTertiary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isMulti
                                    ? 'Submit payment · ${_selectedMonths.length} months'
                                    : 'Submit payment',
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color:
                                      _amountValid ? DT.text : DT.textTertiary,
                                ),
                              ),
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
}
