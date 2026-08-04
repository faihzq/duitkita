import 'package:flutter/material.dart';
import 'package:duitkita/widgets/floating_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/group_model.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/screens/add_debt_screen.dart';
import 'package:duitkita/utils/utils.dart';

enum _EntryType { group, bill, loan, personal }

class AddEntrySheet extends ConsumerStatefulWidget {
  const AddEntrySheet({super.key});

  @override
  ConsumerState<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<AddEntrySheet> {
  int _step = 1;
  _EntryType _type = _EntryType.group;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  GroupModel? _selectedGroup;
  DateTime _paymentMonth = DateTime.now();
  String _paymentTiming =
      'current'; // 'previous' | 'current' | 'advance' | 'custom'
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _stepTitle => switch (_step) {
    1 => 'New entry',
    2 => 'Details',
    _ => 'Review & confirm',
  };

  bool get _isGroupAutoApprove =>
      _type == _EntryType.group &&
      (_selectedGroup?.autoApprovePayments ?? false);

  String get _ctaLabel {
    if (_step == 1) return 'Continue';
    if (_step == 2 && _isGroupAutoApprove) return 'Submit payment';
    if (_step == 2) return 'Continue';
    return 'Confirm & submit';
  }

  IconData get _ctaIcon {
    if (_step == 3 || (_step == 2 && _isGroupAutoApprove)) {
      return Icons.check_rounded;
    }
    return Icons.arrow_forward_rounded;
  }

  void _onTimingChanged(String timing) {
    final now = DateTime.now();
    setState(() {
      _paymentTiming = timing;
      _paymentMonth = switch (timing) {
        'previous' => DateTime(now.year, now.month - 1),
        'advance' => DateTime(now.year, now.month + 1),
        _ => DateTime(now.year, now.month),
      };
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MonthPickerSheet(initial: _paymentMonth),
    );
    if (picked != null) {
      setState(() {
        _paymentMonth = picked;
        _paymentTiming = 'custom';
      });
    }
  }

  Future<void> _handleCta(String userId) async {
    if (_step == 1) {
      setState(() => _step = 2);
      return;
    }

    if (_step == 2) {
      if (_type == _EntryType.group) {
        if (_selectedGroup == null) {
          showSnackBar(context, 'Please select a group');
          return;
        }
        final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
        if (amount == null || amount <= 0) {
          showSnackBar(context, 'Enter a valid amount');
          return;
        }
        if (_isGroupAutoApprove) {
          await _submit(userId);
        } else {
          setState(() => _step = 3);
        }
      } else {
        await _submit(userId);
      }
      return;
    }

    await _submit(userId);
  }

  Future<void> _submit(String userId) async {
    final nav = Navigator.of(context);

    if (_type == _EntryType.bill || _type == _EntryType.loan) {
      nav.pop();
      nav.push(AppTheme.slideRoute(const AddDebtScreen()));
      return;
    }
    if (_type == _EntryType.personal) {
      nav.pop();
      showSnackBar(context, 'Personal tracking coming soon');
      return;
    }

    final group = _selectedGroup;
    if (group == null) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) return;

    setState(() => _submitting = true);
    try {
      final profile = await ref
          .read(profileServiceProvider)
          .getUserProfile(userId);
      await ref
          .read(paymentServiceProvider)
          .addPayment(
            groupId: group.id,
            userId: userId,
            userName: profile?.name ?? 'Me',
            amount: amount,
            paymentDate: _paymentMonth,
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            autoApprove: group.autoApprovePayments,
          );
      await ref
          .read(groupServiceProvider)
          .updateMemberStats(groupId: group.id, userId: userId, amount: amount);
      if (!mounted) return;
      nav.pop();
      final label = _monthLabel(_paymentMonth);
      showSnackBar(
        context,
        group.autoApprovePayments
            ? 'Payment confirmed for $label!'
            : 'Payment submitted — awaiting approval',
      );
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String _monthLabel(DateTime d) {
    const m = [
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
    return '${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: DT.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: DT.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // ── Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _stepTitle,
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: DT.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: DT.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: DT.border),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: DT.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Step progress ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: List.generate(3, (i) {
                final done = i + 1 <= _step;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: done ? DT.accent : DT.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── Step body ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: switch (_step) {
                1 => _Step1(
                  selected: _type,
                  onSelect: (t) => setState(() => _type = t),
                ),
                2 => _Step2(
                  type: _type,
                  amountCtrl: _amountCtrl,
                  notesCtrl: _notesCtrl,
                  userId: userId,
                  selectedGroup: _selectedGroup,
                  paymentMonth: _paymentMonth,
                  paymentTiming: _paymentTiming,
                  onGroupSelected:
                      (g) => setState(() {
                        _selectedGroup = g;
                        if (g.monthlyAmount > 0) {
                          _amountCtrl.text = g.monthlyAmount.toStringAsFixed(2);
                        }
                      }),
                  onTimingChanged: _onTimingChanged,
                  onMonthTap: _pickMonth,
                ),
                _ => _Step3(
                  group: _selectedGroup,
                  amount: _amountCtrl.text,
                  paymentMonth: _paymentMonth,
                  notes: _notesCtrl.text,
                ),
              },
            ),
          ),

          // ── Footer ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: DT.surface,
              border: Border(top: BorderSide(color: DT.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (_step > 1) ...[
                    GestureDetector(
                      onTap: () => setState(() => _step--),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: DT.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DT.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chevron_left_rounded,
                              size: 16,
                              color: DT.text,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Back',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: DT.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          _submitting
                              ? null
                              : () {
                                if (userId != null) _handleCta(userId);
                              },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: DT.text,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child:
                              _submitting
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _ctaLabel,
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        _ctaIcon,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                        ),
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

// ─── Step 1 — Type ────────────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final _EntryType selected;
  final void Function(_EntryType) onSelect;
  const _Step1({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final types = [
      (
        type: _EntryType.group,
        icon: Icons.receipt_outlined,
        label: 'Group payment',
        sub: 'Monthly contribution',
        bg: DT.catGroupsSoft,
        fg: DT.catGroups,
      ),
      (
        type: _EntryType.bill,
        icon: Icons.receipt_long_outlined,
        label: 'Bill / subscription',
        sub: 'Recurring payment',
        bg: DT.catBillsSoft,
        fg: DT.catBills,
      ),
      (
        type: _EntryType.loan,
        icon: Icons.account_balance_outlined,
        label: 'Loan payment',
        sub: 'Pay down a debt',
        bg: DT.catDebtsSoft,
        fg: DT.catDebts,
      ),
      (
        type: _EntryType.personal,
        icon: Icons.person_outline_rounded,
        label: 'Personal',
        sub: 'Just for you',
        bg: DT.surfaceAlt,
        fg: DT.textSecondary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT KIND OF ENTRY?',
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: DT.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.4,
          children:
              types.map((t) {
                final active = selected == t.type;
                return GestureDetector(
                  onTap: () => onSelect(t.type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: active ? DT.accentSoft : DT.surface,
                      borderRadius: BorderRadius.circular(DS.cardRadius),
                      border: Border.all(
                        color: active ? DT.accent : DT.border,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          t.icon,
                          size: 22,
                          color: active ? DT.accentDeep : t.fg,
                        ),
                        const Spacer(),
                        Text(
                          t.label,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: DT.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.sub,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: DT.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }
}

// ─── Step 2 — Details ─────────────────────────────────────────────────────────

class _Step2 extends ConsumerWidget {
  final _EntryType type;
  final TextEditingController amountCtrl;
  final TextEditingController notesCtrl;
  final String? userId;
  final GroupModel? selectedGroup;
  final DateTime paymentMonth;
  final String paymentTiming;
  final void Function(GroupModel) onGroupSelected;
  final void Function(String) onTimingChanged;
  final VoidCallback onMonthTap;

  const _Step2({
    required this.type,
    required this.amountCtrl,
    required this.notesCtrl,
    required this.userId,
    required this.selectedGroup,
    required this.paymentMonth,
    required this.paymentTiming,
    required this.onGroupSelected,
    required this.onTimingChanged,
    required this.onMonthTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (type != _EntryType.group) {
      return _NonGroupPlaceholder(type: type);
    }

    final groupsAsync =
        userId != null ? ref.watch(userGroupsStreamProvider(userId!)) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Group picker
        _Label(text: 'SELECT GROUP'),
        const SizedBox(height: 8),
        if (groupsAsync == null)
          const SizedBox.shrink()
        else
          groupsAsync.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DT.accent,
                      ),
                    ),
                  ),
                ),
            error: (_, __) => const SizedBox.shrink(),
            data: (groups) {
              if (groups.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: DT.surface,
                    borderRadius: BorderRadius.circular(DS.cardRadius),
                    border: Border.all(color: DT.border),
                  ),
                  child: Text(
                    'No groups yet — create one first',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: DT.textTertiary,
                    ),
                  ),
                );
              }
              return Column(
                children:
                    groups.map((g) {
                      final isSelected = selectedGroup?.id == g.id;
                      return GestureDetector(
                        onTap: () => onGroupSelected(g),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? DT.accentSoft : DT.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? DT.accent : DT.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: DT.catGroupsSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    _initials(g.name),
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: DT.catGroups,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.name,
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: DT.text,
                                      ),
                                    ),
                                    Text(
                                      g.monthlyAmount > 0
                                          ? 'RM${g.monthlyAmount.toStringAsFixed(2)}/month · ${g.memberCount} members'
                                          : '${g.memberCount} members',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        color: DT.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: DT.accentDeep,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              );
            },
          ),

        // 2. Amount — appears after group selected
        if (selectedGroup != null) ...[
          const SizedBox(height: 20),
          _Label(text: 'AMOUNT'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.circular(DS.cardRadius),
              border: Border.all(color: DT.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'RM',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: DT.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    style: GoogleFonts.manrope(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: DT.text,
                      letterSpacing: -0.8,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: GoogleFonts.manrope(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: DT.border,
                        letterSpacing: -0.8,
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
          ),
        ],

        // 3. Payment timing — appears after group selected
        if (selectedGroup != null) ...[
          const SizedBox(height: 20),
          _Label(text: 'PAYMENT FOR'),
          const SizedBox(height: 8),
          _TimingPills(timing: paymentTiming, onChanged: onTimingChanged),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onMonthTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: DT.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DT.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: DT.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _monthLabel(paymentMonth),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DT.text,
                      ),
                    ),
                  ),
                  Text(
                    'Change',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DT.accent,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: DT.accent,
                  ),
                ],
              ),
            ),
          ),
        ],

        // 4. Notes — appears after group selected
        if (selectedGroup != null) ...[
          const SizedBox(height: 20),
          FloatingField(
            controller: notesCtrl,
            label: 'Notes',
            icon: Icons.notes_rounded,
            hint: 'e.g. Raya contribution, late payment…',
            optional: true,
            maxLines: 2,
            capitalization: TextCapitalization.sentences,
          ),
        ],
      ],
    );
  }

  static String _initials(String name) {
    final w = name.trim().split(RegExp(r'\s+'));
    if (w.length >= 2) return '${w[0][0]}${w[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  static String _monthLabel(DateTime d) {
    const m = [
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
    return '${m[d.month - 1]} ${d.year}';
  }
}

// ─── Step 3 — Review ──────────────────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final GroupModel? group;
  final String amount;
  final DateTime paymentMonth;
  final String notes;
  const _Step3({
    required this.group,
    required this.amount,
    required this.paymentMonth,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = _ml(paymentMonth);
    final needsApproval = group?.autoApprovePayments == false;

    return Column(
      children: [
        // Navy hero card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DT.primary,
            borderRadius: BorderRadius.circular(DS.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment for',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                monthLabel,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DT.accent,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'RM ${amount.isEmpty ? '0.00' : amount}',
                style: GoogleFonts.manrope(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              if (group != null) ...[
                const SizedBox(height: 6),
                Text(
                  group!.name,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Review rows
        Container(
          decoration: BoxDecoration(
            color: DT.surface,
            borderRadius: BorderRadius.circular(DS.cardRadius),
            border: Border.all(color: DT.border),
          ),
          child: Column(
            children: [
              _ReviewRow(label: 'Group', value: group?.name ?? '—'),
              _ReviewRow(label: 'Month', value: monthLabel),
              if (notes.isNotEmpty) _ReviewRow(label: 'Notes', value: notes),
              _ReviewRow(
                label: 'Approval',
                value: needsApproval ? 'Pending review' : 'Auto-approved',
                valueColor: needsApproval ? DT.warning : DT.success,
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: needsApproval ? DT.infoSoft : DT.accentSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                needsApproval
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: needsApproval ? DT.info : DT.accentDeep,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  needsApproval
                      ? 'Group admins will be notified to review and approve your payment.'
                      : 'Auto-approve is on. Your payment will be confirmed immediately.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: DT.text,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _ml(DateTime d) {
    const m = [
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
    return '${m[d.month - 1]} ${d.year}';
  }
}

// ─── Non-group placeholder for Step 2 ────────────────────────────────────────

class _NonGroupPlaceholder extends StatelessWidget {
  final _EntryType type;
  const _NonGroupPlaceholder({required this.type});

  @override
  Widget build(BuildContext context) {
    final isSoon = type == _EntryType.personal;
    final label = switch (type) {
      _EntryType.bill => 'bills',
      _EntryType.loan => 'loans',
      _ => 'personal',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSoon ? DT.warningSoft : DT.infoSoft,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(
          color:
              isSoon
                  ? DT.warning.withValues(alpha: 0.3)
                  : DT.info.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSoon ? Icons.hourglass_top_rounded : Icons.arrow_forward_rounded,
            size: 16,
            color: isSoon ? DT.warning : DT.info,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSoon
                  ? 'Personal tracking is coming soon.'
                  : 'Tap confirm to proceed to the $label details form.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: DT.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timing pills ─────────────────────────────────────────────────────────────

class _TimingPills extends StatelessWidget {
  final String timing;
  final void Function(String) onChanged;
  const _TimingPills({required this.timing, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [
      ('previous', 'Previous'),
      ('current', 'This Month'),
      ('advance', 'Advance'),
    ];
    return Row(
      children:
          options.indexed.map((entry) {
            final i = entry.$1;
            final o = entry.$2;
            final isSelected = timing == o.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? DT.accent : DT.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? DT.accent : DT.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      o.$2,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : DT.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

// ─── Month picker sheet ───────────────────────────────────────────────────────

class _MonthPickerSheet extends StatefulWidget {
  final DateTime initial;
  const _MonthPickerSheet({required this.initial});

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
  }

  @override
  Widget build(BuildContext context) {
    const months = [
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

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: DT.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: DT.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Month',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: DT.text,
            ),
          ),
          const SizedBox(height: 20),

          // Year navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _year--),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DT.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: DT.border),
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: DT.text,
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Text(
                '$_year',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DT.text,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 28),
              GestureDetector(
                onTap: () => setState(() => _year++),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DT.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: DT.border),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: DT.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Month grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            childAspectRatio: 1.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(12, (i) {
              final isSelected =
                  _year == widget.initial.year && i + 1 == widget.initial.month;
              return GestureDetector(
                onTap: () => Navigator.pop(context, DateTime(_year, i + 1)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: isSelected ? DT.accent : DT.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? DT.accent : DT.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      months[i],
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : DT.text,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;
  final Color? valueColor;
  const _ReviewRow({
    required this.label,
    required this.value,
    this.last = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: DT.border)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? DT.text,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.manrope(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: DT.textSecondary,
      letterSpacing: 0.8,
    ),
  );
}
