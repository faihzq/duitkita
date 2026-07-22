import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/models/payment_model.dart';
import 'package:duitkita/features/payments/add_payment_screen.dart';
import 'package:duitkita/features/payments/payment_history_screen.dart';
import 'package:duitkita/features/groups/manage_members_screen.dart';
import 'package:duitkita/features/groups/group_settings_screen.dart';
import 'package:duitkita/features/groups/group_analytics_screen.dart';
import 'package:duitkita/features/expenses/expense_list_screen.dart';
import 'package:duitkita/features/groups/bulk_import_screen.dart';
import 'package:duitkita/features/payments/pending_payments_review_screen.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  int _tab = 0; // 0=Members, 1=Activity, 2=Expenses
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  // ─── Payment status (per-member for selected month) ─────────────────────────
  Future<Map<String, _PayInfo>> _fetchPaymentStatus(List<GroupMember> members) async {
    final svc = ref.read(paymentServiceProvider);
    final result = <String, _PayInfo>{};
    for (final m in members) {
      final payments = await svc.getUserMonthPayments(
        groupId: widget.groupId,
        userId: m.userId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      if (payments.isEmpty) {
        result[m.userId] = _PayInfo(status: 'unpaid');
      } else {
        final p = payments.first;
        result[m.userId] = _PayInfo(status: p.paymentStatus, paymentId: p.id, amount: p.amount, payment: p);
      }
    }
    return result;
  }

  // ─── Verify payment ──────────────────────────────────────────────────────────
  Future<void> _verifyPayment(
    String paymentId,
    String status,
    String memberName, {
    BuildContext? sheetCtx,
    String? rejectionReason,
  }) async {
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profile = await ref.read(profileServiceProvider).getUserProfile(userId);
      await ref.read(paymentServiceProvider).verifyPayment(
        paymentId: paymentId,
        status: status,
        verifiedBy: userId,
        verifiedByName: profile?.name ?? 'Admin',
        rejectionReason: rejectionReason,
      );
      if (!mounted) return;
      if (sheetCtx != null && sheetCtx.mounted) Navigator.of(sheetCtx).pop();
      final msg = 'Payment by $memberName ${status == 'confirmed' ? 'confirmed' : 'rejected'}';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  // ─── Month navigation ────────────────────────────────────────────────────────
  void _prevMonth() => setState(() {
        if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
        else { _selectedMonth--; }
      });

  void _nextMonth() => setState(() {
        if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
        else { _selectedMonth++; }
      });

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthPickerSheet(
        currentMonth: _selectedMonth,
        currentYear: _selectedYear,
        onPicked: (m, y) => setState(() { _selectedMonth = m; _selectedYear = y; }),
      ),
    );
  }

  // ─── Share ───────────────────────────────────────────────────────────────────
  void _share(dynamic group, List<GroupMember> members) {
    final lines = StringBuffer()
      ..writeln('*${group.name} — Payment Status*')
      ..writeln('Month: ${_months[_selectedMonth - 1]} $_selectedYear')
      ..writeln('Amount: RM${group.monthlyAmount.toStringAsFixed(2)}/mo\n');
    for (final m in members) {
      lines.writeln('• ${m.userName}');
    }
    SharePlus.instance.share(ShareParams(text: lines.toString()));
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));
    final paidCount = ref.watch(groupMonthPaidCountProvider(widget.groupId)).valueOrNull ?? 0;

    return groupAsync.when(
      loading: () => Scaffold(
        backgroundColor: DT.bg,
        body: const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: DT.bg,
        body: Center(child: Text('Error: $e')),
      ),
      data: (group) {
        if (group == null) {
          return Scaffold(backgroundColor: DT.bg, body: const Center(child: Text('Group not found')));
        }
        final members = membersAsync.valueOrNull ?? [];
        final isAdmin = members.any((m) => m.userId == userId && m.isAdmin);
        final perMember = group.monthlyAmount;
        final paidPct = group.memberCount > 0 ? (paidCount / group.memberCount).clamp(0.0, 1.0) : 0.0;

        return Scaffold(
          backgroundColor: DT.bg,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header bar ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      _IconBtn(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      _IconBtn(
                        icon: Icons.ios_share_rounded,
                        onTap: () => _share(group, members),
                      ),
                      const SizedBox(width: 8),
                      _IconBtn(
                        icon: Icons.settings_outlined,
                        onTap: () => Navigator.of(context).push(
                          AppTheme.slideRoute(GroupSettingsScreen(groupId: widget.groupId, groupName: group.name)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable body ──────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Group hero ───────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: Row(
                            children: [
                              _GroupTile(name: group.name, size: 54),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.name,
                                      style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.5),
                                    ),
                                    if (group.description.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        group.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Stats card ───────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: DT.surface,
                              borderRadius: BorderRadius.circular(DS.cardRadius),
                              border: Border.all(color: DT.border),
                            ),
                            child: Column(
                              children: [
                                IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      _StatCell(label: 'Per member', value: group.monthlyAmount > 0 ? 'RM${perMember.toStringAsFixed(0)}' : '—'),
                                      const VerticalDivider(width: 1, color: DT.border),
                                      _StatCell(label: 'Members', value: '${group.memberCount}'),
                                      const VerticalDivider(width: 1, color: DT.border),
                                      _StatCell(label: 'This month', value: '$paidCount/${group.memberCount}'),
                                    ],
                                  ),
                                ),
                                if (group.monthlyAmount > 0)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Collection progress', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: DT.textSecondary)),
                                            Text('${(paidPct * 100).round()}%', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: DT.accentDeep)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: paidPct,
                                            minHeight: 5,
                                            backgroundColor: DT.surfaceAlt,
                                            valueColor: const AlwaysStoppedAnimation<Color>(DT.accent),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // ── Action buttons ───────────────────────
                        if (userId != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ActionBtn(
                                    label: 'Pay my share',
                                    icon: Icons.qr_code_2_rounded,
                                    primary: true,
                                    onTap: () => Navigator.of(context).push(
                                      AppTheme.slideRoute(AddPaymentScreen(
                                        groupId: widget.groupId,
                                        monthlyAmount: group.monthlyAmount,
                                        selectedMonth: _selectedMonth,
                                        selectedYear: _selectedYear,
                                      )),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ActionBtn(
                                    label: 'Add expense',
                                    icon: Icons.add_rounded,
                                    primary: false,
                                    onTap: () => Navigator.of(context).push(
                                      AppTheme.slideRoute(ExpenseListScreen(groupId: widget.groupId, groupName: group.name)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ── Tab bar ──────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: _TabBar(
                            tabs: const ['Members', 'Activity', 'Expenses'],
                            selectedIndex: _tab,
                            onTap: (i) => setState(() => _tab = i),
                          ),
                        ),

                        // ── Tab body ─────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                          child: IndexedStack(
                            index: _tab,
                            children: [
                              // Members tab
                              _MembersTab(
                                members: members,
                                selectedMonth: _selectedMonth,
                                selectedYear: _selectedYear,
                                userId: userId ?? '',
                                isAdmin: isAdmin,
                                group: group,
                                onPrevMonth: _prevMonth,
                                onNextMonth: _nextMonth,
                                onPickMonth: _showMonthPicker,
                                fetchStatus: _fetchPaymentStatus,
                                onVerify: _verifyPayment,
                                onShowReview: _showPaymentReviewSheet,
                                groupId: widget.groupId,
                                onShowReject: _showRejectDialog,
                                onNavigate: (screen) => Navigator.of(context).push(AppTheme.slideRoute(screen)),
                              ),
                              // Activity tab
                              _ActivityTab(
                                groupId: widget.groupId,
                                month: _selectedMonth,
                                year: _selectedYear,
                              ),
                              // Expenses tab
                              _ExpensesTab(
                                groupId: widget.groupId,
                                groupName: group.name,
                                isAdmin: isAdmin,
                                onNavigate: (screen) => Navigator.of(context).push(AppTheme.slideRoute(screen)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Payment review sheet ─────────────────────────────────────────────────

  void _showPaymentReviewSheet(BuildContext context, {required PaymentModel payment, required String memberName}) {
    final dateStr = '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}';
    final methodLabel = switch (payment.paymentMethod) {
      'duitnow' => 'DuitNow',
      'online_banking' => 'Online Banking',
      'cash' => 'Cash',
      _ => payment.paymentMethod,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: DT.borderStrong, borderRadius: BorderRadius.circular(2))),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: DT.warningSoft, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.rate_review_outlined, color: DT.warning, size: 22)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Review Payment', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.text)),
                      Text('By $memberName', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary)),
                    ],
                  )),
                  GestureDetector(onTap: () => Navigator.pop(sheetCtx),
                    child: Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: DT.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.close, size: 18, color: DT.textSecondary))),
                ],
              ),
            ),
            Divider(height: 20, color: DT.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Amount
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [DT.headerGradientStart, DT.headerGradientEnd]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      Text('Payment Amount', style: GoogleFonts.manrope(fontSize: 13, color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text('RM${payment.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _ReviewRow(icon: Icons.calendar_today_outlined, label: 'Payment Date', value: dateStr),
                  _ReviewRow(icon: Icons.payment_outlined, label: 'Method', value: methodLabel),
                  if (payment.transactionReference?.isNotEmpty == true)
                    _ReviewRow(icon: Icons.tag, label: 'Reference', value: payment.transactionReference!),
                  if (payment.notes?.isNotEmpty == true)
                    _ReviewRow(icon: Icons.notes_outlined, label: 'Notes', value: payment.notes!),
                  if (payment.receiptUrl?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text('Receipt', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(payment.receiptUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                        Container(height: 100, color: DT.surfaceAlt, child: const Icon(Icons.image_not_supported_outlined, color: DT.textTertiary))),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(children: [
                    Expanded(child: _OutlineBtn(
                      label: 'Reject',
                      color: DT.danger,
                      onTap: () => _showRejectDialog(sheetCtx, payment.id, memberName),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _FilledBtn(
                      label: 'Confirm',
                      color: DT.success,
                      onTap: () => _verifyPayment(payment.id, 'confirmed', memberName, sheetCtx: sheetCtx),
                    )),
                  ]),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext sheetCtx, String paymentId, String memberName) {
    final ctrl = TextEditingController();
    showDialog(
      context: sheetCtx,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: DT.surface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reject Payment', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.text)),
            const SizedBox(height: 6),
            Text('Reason for rejecting $memberName\'s payment:', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl, maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.manrope(fontSize: 14, color: DT.text),
              decoration: InputDecoration(
                hintText: 'e.g. Wrong amount, invalid receipt…',
                hintStyle: GoogleFonts.manrope(fontSize: 13, color: DT.textTertiary),
                filled: true, fillColor: DT.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.accent, width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _OutlineBtn(label: 'Cancel', color: DT.textSecondary, onTap: () => Navigator.pop(dialogCtx))),
              const SizedBox(width: 12),
              Expanded(child: _FilledBtn(label: 'Reject', color: DT.danger, onTap: () {
                Navigator.pop(dialogCtx);
                _verifyPayment(paymentId, 'rejected', memberName, sheetCtx: sheetCtx, rejectionReason: ctrl.text.trim());
              })),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── Members tab ──────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  final List<GroupMember> members;
  final int selectedMonth;
  final int selectedYear;
  final String userId;
  final bool isAdmin;
  final dynamic group;
  final String groupId;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickMonth;
  final Future<Map<String, _PayInfo>> Function(List<GroupMember>) fetchStatus;
  final Future<void> Function(String, String, String, {BuildContext? sheetCtx, String? rejectionReason}) onVerify;
  final void Function(BuildContext, {required PaymentModel payment, required String memberName}) onShowReview;
  final void Function(BuildContext, String, String) onShowReject;
  final void Function(Widget) onNavigate;

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  const _MembersTab({
    required this.members,
    required this.selectedMonth,
    required this.selectedYear,
    required this.userId,
    required this.isAdmin,
    required this.group,
    required this.groupId,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onPickMonth,
    required this.fetchStatus,
    required this.onVerify,
    required this.onShowReview,
    required this.onShowReject,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: DT.surface,
            borderRadius: BorderRadius.circular(DS.cardRadius),
            border: Border.all(color: DT.border),
          ),
          child: Row(
            children: [
              GestureDetector(onTap: onPrevMonth, child: const Icon(Icons.chevron_left_rounded, size: 22, color: DT.textSecondary)),
              Expanded(
                child: GestureDetector(
                  onTap: onPickMonth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_months[selectedMonth - 1]} $selectedYear',
                        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: DT.textTertiary),
                    ],
                  ),
                ),
              ),
              GestureDetector(onTap: onNextMonth, child: const Icon(Icons.chevron_right_rounded, size: 22, color: DT.textSecondary)),
            ],
          ),
        ),

        // Admin quick-access row
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickChip(label: 'Members', icon: Icons.people_outline, onTap: () => onNavigate(ManageMembersScreen(groupId: groupId, groupName: group.name as String))),
                  _QuickChip(label: 'History', icon: Icons.history_rounded, onTap: () => onNavigate(PaymentHistoryScreen(groupId: groupId))),
                  _QuickChip(label: 'Analytics', icon: Icons.bar_chart_rounded, onTap: () => onNavigate(GroupAnalyticsScreen(groupId: groupId, groupName: group.name as String))),
                  Consumer(builder: (context, ref, _) {
                    final count = ref.watch(pendingPaymentsStreamProvider(groupId)).valueOrNull?.length ?? 0;
                    return _QuickChip(label: 'Review${count > 0 ? ' ($count)' : ''}', icon: Icons.fact_check_outlined, onTap: () => onNavigate(PendingPaymentsReviewScreen(groupId: groupId, groupName: group.name as String)), highlight: count > 0);
                  }),
                  _QuickChip(label: 'Import', icon: Icons.upload_outlined, onTap: () => onNavigate(BulkImportScreen(groupId: groupId, groupName: group.name as String, monthlyAmount: group.monthlyAmount as double, groupCreatedAt: group.createdAt as DateTime))),
                ],
              ),
            ),
          ),

        const SizedBox(height: 14),

        // Member list
        if (members.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text('No members yet', style: GoogleFonts.manrope(fontSize: 14, color: DT.textTertiary)),
            ),
          )
        else
          FutureBuilder<Map<String, _PayInfo>>(
            future: fetchStatus(members),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2),
                ));
              }
              final statusMap = snapshot.data!;
              return Column(
                children: members.map((m) {
                  final info = statusMap[m.userId] ?? _PayInfo(status: 'unpaid');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MemberCard(
                      member: m,
                      info: info,
                      isCurrentUser: m.userId == userId,
                      isAdmin: isAdmin,
                      group: group,
                      groupId: groupId,
                      selectedMonth: selectedMonth,
                      selectedYear: selectedYear,
                      onVerify: onVerify,
                      onShowReview: (ctx) => onShowReview(ctx, payment: info.payment!, memberName: m.userName),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

// ─── Activity tab ─────────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerWidget {
  final String groupId;
  final int month;
  final int year;

  const _ActivityTab({required this.groupId, required this.month, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(monthPaymentsStreamProvider((
      groupId: groupId, month: month, year: year,
    )));

    return paymentsAsync.when(
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2),
      )),
      error: (e, _) => Center(child: Text('Error: $e', style: GoogleFonts.manrope(color: DT.textSecondary))),
      data: (payments) {
        if (payments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.timeline_outlined, size: 40, color: DT.textTertiary),
                  const SizedBox(height: 12),
                  Text('No activity this month', style: GoogleFonts.manrope(fontSize: 14, color: DT.textTertiary)),
                ],
              ),
            ),
          );
        }
        // Sort newest first
        final sorted = List.of(payments)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return Column(
          children: sorted.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActivityCard(payment: p),
          )).toList(),
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final PaymentModel payment;
  const _ActivityCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, action) = switch (payment.paymentStatus) {
      'confirmed' => (DT.successSoft, DT.success, Icons.check_circle_outline_rounded, 'confirmed payment'),
      'pending'   => (DT.warningSoft, DT.warning, Icons.hourglass_top_rounded, 'submitted payment'),
      'rejected'  => (DT.dangerSoft,  DT.danger,  Icons.cancel_outlined, 'payment was rejected'),
      _           => (DT.surfaceAlt,  DT.textTertiary, Icons.circle_outlined, 'submitted'),
    };

    final diff = DateTime.now().difference(payment.createdAt);
    final timeLabel = diff.inMinutes < 60 ? '${diff.inMinutes}m ago'
        : diff.inHours < 24 ? '${diff.inHours}h ago'
        : '${diff.inDays}d ago';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: DT.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: payment.userName, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.text)),
                      TextSpan(text: ' $action', style: GoogleFonts.manrope(fontSize: 13, color: DT.text, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Text(timeLabel, style: GoogleFonts.manrope(fontSize: 11, color: DT.textTertiary)),
              ],
            ),
          ),
          Text(
            'RM${payment.amount.toStringAsFixed(0)}',
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.text),
          ),
        ],
      ),
    );
  }
}

// ─── Expenses tab ─────────────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerWidget {
  final String groupId;
  final String groupName;
  final bool isAdmin;
  final void Function(Widget) onNavigate;

  const _ExpensesTab({required this.groupId, required this.groupName, required this.isAdmin, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(pendingExpensesStreamProvider(groupId));
    final pendingCount = expensesAsync.valueOrNull?.length ?? 0;

    return Column(
      children: [
        if (isAdmin && pendingCount > 0)
          GestureDetector(
            onTap: () => onNavigate(ExpenseListScreen(groupId: groupId, groupName: groupName)),
            child: Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: DT.warningSoft,
                borderRadius: BorderRadius.circular(DS.cardRadius),
                border: Border.all(color: DT.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions_rounded, color: DT.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('$pendingCount expense${pendingCount > 1 ? 's' : ''} pending review', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.warning))),
                  const Icon(Icons.chevron_right_rounded, color: DT.warning, size: 16),
                ],
              ),
            ),
          ),
        // Empty / view all card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: DT.border)),
                    child: const Icon(Icons.receipt_outlined, size: 32, color: DT.textTertiary),
                  ),
                  Positioned(
                    right: -6, top: -6,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: DT.accent, borderRadius: BorderRadius.circular(7)),
                      child: const Icon(Icons.add_rounded, size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Group expenses', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.3)),
              const SizedBox(height: 8),
              Text(
                'Track shared costs — groceries, meals, outings — and see who paid what.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 14, color: DT.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => onNavigate(ExpenseListScreen(groupId: groupId, groupName: groupName)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: DT.text, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('View expenses', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Member card ──────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final GroupMember member;
  final _PayInfo info;
  final bool isCurrentUser;
  final bool isAdmin;
  final dynamic group;
  final String groupId;
  final int selectedMonth;
  final int selectedYear;
  final Future<void> Function(String, String, String, {BuildContext? sheetCtx, String? rejectionReason}) onVerify;
  final void Function(BuildContext) onShowReview;

  const _MemberCard({
    required this.member,
    required this.info,
    required this.isCurrentUser,
    required this.isAdmin,
    required this.group,
    required this.groupId,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onVerify,
    required this.onShowReview,
  });

  @override
  Widget build(BuildContext context) {
    final status = info.status;
    final (bg, fg, label) = switch (status) {
      'confirmed' => (DT.successSoft, DT.success, 'Paid'),
      'pending'   => (DT.warningSoft, DT.warning, 'Pending'),
      'rejected'  => (DT.dangerSoft,  DT.danger,  'Rejected'),
      _           => (DT.surfaceAlt,  DT.textTertiary, 'Unpaid'),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(
          color: isCurrentUser ? DT.catGroups.withValues(alpha: 0.3) : DT.border,
          width: isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              _Avatar40(name: member.userName, userId: member.userId),
              const SizedBox(width: 12),
              // Name + role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(member.userName, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text), overflow: TextOverflow.ellipsis),
                        ),
                        if (member.isAdmin) ...[
                          const SizedBox(width: 6),
                          _Pill(label: 'Admin', bg: DT.catGroupsSoft, fg: DT.catGroups),
                        ],
                        if (isCurrentUser) ...[
                          const SizedBox(width: 6),
                          _Pill(label: 'You', bg: DT.accentSoft, fg: DT.accentDeep),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.amount != null ? 'RM${info.amount!.toStringAsFixed(2)}' : 'RM${(group.monthlyAmount as double).toStringAsFixed(2)} due',
                      style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                child: Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
              ),
            ],
          ),

          // Pay button for current user (unpaid / rejected)
          if (isCurrentUser && status != 'confirmed' && status != 'pending') ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                AppTheme.slideRoute(AddPaymentScreen(
                  groupId: groupId,
                  monthlyAmount: group.monthlyAmount as double,
                  selectedMonth: selectedMonth,
                  selectedYear: selectedYear,
                )),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: DT.text, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Pay my share', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],

          // Review button for admin + pending payment
          if (isAdmin && status == 'pending' && info.payment != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => onShowReview(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: DT.warningSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DT.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility_outlined, size: 16, color: DT.warning),
                    const SizedBox(width: 8),
                    Text('Review payment', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.warning)),
                  ],
                ),
              ),
            ),
          ],

          // Rejection reason
          if (status == 'rejected' && info.payment?.rejectionReason?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: DT.dangerSoft, borderRadius: BorderRadius.circular(8)),
              child: Text('Reason: ${info.payment!.rejectionReason}', style: GoogleFonts.manrope(fontSize: 11, color: DT.danger)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Month picker sheet ───────────────────────────────────────────────────────

class _MonthPickerSheet extends StatefulWidget {
  final int currentMonth;
  final int currentYear;
  final void Function(int month, int year) onPicked;

  const _MonthPickerSheet({required this.currentMonth, required this.currentYear, required this.onPicked});

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  late int _year;

  @override
  void initState() { super.initState(); _year = widget.currentYear; }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: DT.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.borderStrong, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(onTap: () => setState(() => _year--), child: const Icon(Icons.chevron_left_rounded, color: DT.textSecondary)),
            Text('$_year', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: DT.text)),
            GestureDetector(onTap: () => setState(() => _year++), child: const Icon(Icons.chevron_right_rounded, color: DT.textSecondary)),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2),
          itemCount: 12,
          itemBuilder: (_, i) {
            final active = i + 1 == widget.currentMonth && _year == widget.currentYear;
            return GestureDetector(
              onTap: () { widget.onPicked(i + 1, _year); Navigator.pop(context); },
              child: Container(
                decoration: BoxDecoration(
                  color: active ? DT.text : DT.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(_months[i], style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : DT.text))),
              ),
            );
          },
        ),
      ]),
    );
  }
}

// ─── Shared small widgets ──────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: DT.border)),
      child: Icon(icon, size: 20, color: DT.text),
    ),
  );
}

class _GroupTile extends StatelessWidget {
  final String name;
  final double size;
  const _GroupTile({required this.name, required this.size});

  String _initials() {
    final w = name.trim().split(RegExp(r'\s+'));
    if (w.length >= 2) return '${w[0][0]}${w[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: DT.catGroupsSoft, borderRadius: BorderRadius.circular(16)),
    child: Center(child: Text(_initials(), style: GoogleFonts.manrope(fontSize: size * 0.3, fontWeight: FontWeight.w800, color: DT.catGroups))),
  );
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(children: [
        Text(value, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.4)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w700, color: DT.textSecondary, letterSpacing: 0.4)),
      ]),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: primary ? DT.text : DT.surface,
        borderRadius: BorderRadius.circular(12),
        border: primary ? null : Border.all(color: DT.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: primary ? Colors.white : DT.text),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: primary ? Colors.white : DT.text)),
        ],
      ),
    ),
  );
}

class _TabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final void Function(int) onTap;
  const _TabBar({required this.tabs, required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) => Row(
    children: tabs.asMap().entries.map((e) {
      final active = e.key == selectedIndex;
      return GestureDetector(
        onTap: () => onTap(e.key),
        child: Padding(
          padding: EdgeInsets.only(right: e.key < tabs.length - 1 ? 4 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(e.value, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: active ? DT.text : DT.textTertiary)),
              ),
              Container(height: 2, width: e.value.length * 8.0, color: active ? DT.text : Colors.transparent),
            ],
          ),
        ),
      );
    }).toList(),
  );
}

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;
  const _QuickChip({required this.label, required this.icon, required this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: highlight ? DT.warningSoft : DT.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: highlight ? DT.warning.withValues(alpha: 0.4) : DT.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: highlight ? DT.warning : DT.text),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: highlight ? DT.warning : DT.text)),
      ]),
    ),
  );
}

class _Avatar40 extends ConsumerWidget {
  final String name;
  final String userId;
  const _Avatar40({required this.name, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileStreamProvider(userId));
    final photoUrl = profileAsync.valueOrNull?.profileImageUrl;
    final initials = name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

    return ClipOval(
      child: SizedBox(
        width: 40, height: 40,
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _InitialsAvatar(initials: initials),
              )
            : _InitialsAvatar(initials: initials),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) => Container(
    color: DT.catGroupsSoft,
    child: Center(child: Text(initials, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: DT.catGroups))),
  );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Pill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
  );
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ReviewRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, size: 16, color: DT.textSecondary),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary))),
      Text(value, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.text)),
    ]),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: color))),
    ),
  );
}

class _FilledBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FilledBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
    ),
  );
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _PayInfo {
  final String status;
  final String? paymentId;
  final double? amount;
  final PaymentModel? payment;
  const _PayInfo({required this.status, this.paymentId, this.amount, this.payment});
}
