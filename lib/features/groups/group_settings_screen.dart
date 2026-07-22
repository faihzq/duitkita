import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/group_model.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/features/payments/pending_payments_review_screen.dart';
import 'package:duitkita/screens/pending_expenses_review_screen.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  const GroupSettingsScreen({super.key, required this.groupId, required this.groupName});

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  bool _busy = false;

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1: return '${day}st';
      case 2: return '${day}nd';
      case 3: return '${day}rd';
      default: return '${day}th';
    }
  }

  // ─── Edit group info ────────────────────────────────────────────────────────

  Future<void> _editGroup(GroupModel group) async {
    final nameCtrl = TextEditingController(text: group.name);
    final descCtrl = TextEditingController(text: group.description);
    final amtCtrl = TextEditingController(text: group.monthlyAmount.toStringAsFixed(2));
    final balCtrl = TextEditingController(text: group.initialBalance.toStringAsFixed(2));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _FormDialog(
        title: 'Edit Group',
        icon: Icons.edit_outlined,
        iconColor: DT.primary,
        fields: [
          _DialogField(controller: nameCtrl, label: 'Group name', icon: Icons.group_outlined, capitalization: TextCapitalization.words),
          _DialogField(controller: descCtrl, label: 'Description', icon: Icons.notes_outlined, maxLines: 2),
          _DialogField(controller: amtCtrl, label: 'Monthly amount (RM)', icon: Icons.payments_outlined, keyboardType: TextInputType.number),
          _DialogField(controller: balCtrl, label: 'Starting balance (RM)', icon: Icons.savings_outlined, keyboardType: TextInputType.number),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) { _snack('Group name cannot be empty'); return; }
    final amt = double.tryParse(amtCtrl.text.trim());
    final bal = double.tryParse(balCtrl.text.trim());

    setState(() => _busy = true);
    try {
      await ref.read(groupServiceProvider).updateGroup(groupId: widget.groupId, name: name, description: descCtrl.text.trim(), monthlyAmount: amt, initialBalance: bal);
      if (mounted) _snack('Group updated');
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    nameCtrl.dispose(); descCtrl.dispose(); amtCtrl.dispose(); balCtrl.dispose();
  }

  // ─── Reminder day ───────────────────────────────────────────────────────────

  Future<void> _setReminderDay(GroupModel group) async {
    int selected = group.reminderDay;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Container(
          decoration: const BoxDecoration(color: DT.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.borderStrong, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Payment Reminder Day', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text)),
            const SizedBox(height: 4),
            Text('Members will be reminded on this day each month.', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1),
              itemCount: 28,
              itemBuilder: (_, i) {
                final day = i + 1;
                final active = day == selected;
                return GestureDetector(
                  onTap: () => set(() => selected = day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: active ? DT.text : DT.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text('$day', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : DT.text))),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: DT.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.event_available_outlined, size: 18, color: DT.primary),
                const SizedBox(width: 10),
                Expanded(child: RichText(text: TextSpan(style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary), children: [
                  const TextSpan(text: 'Reminders on the '),
                  TextSpan(text: _ordinal(selected), style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: DT.primary)),
                  const TextSpan(text: ' of every month'),
                ]))),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _OutlineBtn(label: 'Cancel', color: DT.textSecondary, onTap: () => Navigator.pop(ctx))),
              const SizedBox(width: 12),
              Expanded(child: _FilledBtn(label: 'Save', color: DT.text, onTap: () => Navigator.pop(ctx, selected))),
            ]),
          ]),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(groupServiceProvider).updateGroup(groupId: widget.groupId, reminderDay: result);
      if (mounted) _snack('Reminder set to ${_ordinal(result)} of each month');
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Bank account ───────────────────────────────────────────────────────────

  Future<void> _bankAccount(GroupModel group) async {
    const banks = ['Maybank', 'CIMB Bank', 'Public Bank', 'RHB Bank', 'Hong Leong Bank', 'AmBank', 'Bank Islam', 'BSN', 'Alliance Bank', 'Affin Bank', 'Bank Rakyat', 'OCBC Bank', 'UOB Bank', 'Standard Chartered', 'HSBC Bank', 'Other'];
    final bankCtrl = TextEditingController(text: group.bankName ?? '');
    final accCtrl = TextEditingController(text: group.accountNumber ?? '');
    final holderCtrl = TextEditingController(text: group.accountHolderName ?? '');
    String? selectedBank = group.bankName != null && banks.contains(group.bankName) ? group.bankName : (group.bankName != null ? 'Other' : null);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          decoration: const BoxDecoration(color: DT.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.borderStrong, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: DT.primarySoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.account_balance_outlined, color: DT.primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bank Account', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.text)),
                  Text('Members will transfer payments to this account', style: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary)),
                ])),
              ]),
              const SizedBox(height: 20),
              // Bank grid
              Text('Select Bank', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.textSecondary)),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.4),
                itemCount: banks.length,
                itemBuilder: (_, i) {
                  final bank = banks[i];
                  final active = bank == selectedBank;
                  return GestureDetector(
                    onTap: () => set(() {
                      selectedBank = bank;
                      if (bank != 'Other') { bankCtrl.text = bank; }
                      else { bankCtrl.text = ''; }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: active ? DT.text : DT.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: active ? DT.text : DT.border),
                      ),
                      child: Center(child: Text(bank, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white : DT.text), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ),
                  );
                },
              ),
              if (selectedBank == 'Other') ...[
                const SizedBox(height: 12),
                _InputField(controller: bankCtrl, label: 'Bank name', icon: Icons.account_balance_outlined),
              ],
              const SizedBox(height: 12),
              _InputField(controller: accCtrl, label: 'Account number', icon: Icons.numbers_outlined, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 12),
              _InputField(controller: holderCtrl, label: 'Account holder name', icon: Icons.person_outline_rounded, capitalization: TextCapitalization.characters, inputFormatters: [TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase()))]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _OutlineBtn(label: 'Cancel', color: DT.textSecondary, onTap: () => Navigator.pop(ctx))),
                const SizedBox(width: 12),
                Expanded(child: _FilledBtn(label: 'Save', color: DT.text, onTap: () {
                  if (selectedBank != null && selectedBank != 'Other') bankCtrl.text = selectedBank!;
                  Navigator.pop(ctx, true);
                })),
              ]),
            ]),
          ),
        ),
      ),
    );

    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(groupServiceProvider).updateGroup(
        groupId: widget.groupId,
        bankName: bankCtrl.text.trim().isEmpty ? null : bankCtrl.text.trim(),
        accountNumber: accCtrl.text.trim().isEmpty ? null : accCtrl.text.trim(),
        accountHolderName: holderCtrl.text.trim().isEmpty ? null : holderCtrl.text.trim(),
      );
      if (mounted) _snack('Bank account updated');
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    bankCtrl.dispose(); accCtrl.dispose(); holderCtrl.dispose();
  }

  // ─── Auto-approve toggle ────────────────────────────────────────────────────

  Future<void> _toggleAutoApprove(GroupModel group) async {
    final val = !group.autoApprovePayments;
    if (val) {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: DT.surface,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: DT.successSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.verified_outlined, color: DT.success, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text('Enable Auto-Approve?', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: DT.text))),
              ]),
              const SizedBox(height: 12),
              Text('All existing pending payments will be confirmed automatically. You can also review them first.', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4)),
              const SizedBox(height: 20),
              Column(children: [
                GestureDetector(onTap: () => Navigator.pop(ctx, 'review'), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border.all(color: DT.accent.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Review first', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.accentDeep))))),
                const SizedBox(height: 8),
                GestureDetector(onTap: () => Navigator.pop(ctx, 'approve_all'), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: DT.success, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Approve all & enable', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))))),
                const SizedBox(height: 8),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: Center(child: Text('Cancel', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: DT.textSecondary)))),
              ]),
            ]),
          ),
        ),
      );

      if (result == null) return;
      if (result == 'review' && mounted) {
        await Navigator.of(context).push(AppTheme.slideRoute(PendingPaymentsReviewScreen(groupId: widget.groupId, groupName: widget.groupName)));
      }
    }

    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(groupServiceProvider).updateGroup(groupId: widget.groupId, autoApprovePayments: val);
      if (val) {
        final uid = ref.read(authControllerProvider.notifier).currentUser?.uid;
        if (uid != null) {
          final profile = await ref.read(profileServiceProvider).getUserProfile(uid);
          await ref.read(paymentServiceProvider).confirmAllPendingPayments(groupId: widget.groupId, verifiedBy: uid, verifiedByName: profile?.name ?? 'Admin');
        }
      }
      if (mounted) _snack(val ? 'Auto-approve enabled' : 'Payments require review');
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAutoApproveExpense(GroupModel group) async {
    final val = !group.autoApproveExpenses;
    if (val) {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: DT.surface,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: DT.accentSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long_outlined, color: DT.accentDeep, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text('Enable Auto-Approve Expenses?', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: DT.text))),
              ]),
              const SizedBox(height: 12),
              Text('All pending expenses will be approved automatically. You can also review them first.', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4)),
              const SizedBox(height: 20),
              Column(children: [
                GestureDetector(onTap: () => Navigator.pop(ctx, 'review'), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border.all(color: DT.accent.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Review first', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.accentDeep))))),
                const SizedBox(height: 8),
                GestureDetector(onTap: () => Navigator.pop(ctx, 'approve_all'), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: DT.accentDeep, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Approve all & enable', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))))),
                const SizedBox(height: 8),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: Center(child: Text('Cancel', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: DT.textSecondary)))),
              ]),
            ]),
          ),
        ),
      );
      if (result == null) return;
      if (result == 'review' && mounted) {
        await Navigator.of(context).push(AppTheme.slideRoute(PendingExpensesReviewScreen(groupId: widget.groupId, groupName: widget.groupName)));
      }
    }

    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(groupServiceProvider).updateGroup(groupId: widget.groupId, autoApproveExpenses: val);
      if (val) {
        final uid = ref.read(authControllerProvider.notifier).currentUser?.uid;
        if (uid != null) {
          final profile = await ref.read(profileServiceProvider).getUserProfile(uid);
          await ref.read(expenseServiceProvider).approveAllPendingExpenses(groupId: widget.groupId, approvedBy: uid, approvedByName: profile?.name ?? 'Admin');
        }
      }
      if (mounted) _snack(val ? 'Auto-approve expenses enabled' : 'Expenses require review');
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Manage admins ──────────────────────────────────────────────────────────

  Future<void> _manageAdmins() async {
    final uid = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (uid == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
        builder: (ctx, ctrl) => _ManageAdminsSheet(groupId: widget.groupId, currentUserId: uid, scrollController: ctrl),
      ),
    );
  }

  // ─── Delete group ───────────────────────────────────────────────────────────

  Future<void> _deleteGroup(GroupModel group) async {
    final ctrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final matches = ctrl.text.trim() == group.name;
          return Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
            decoration: const BoxDecoration(color: DT.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.borderStrong, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Container(width: 52, height: 52, decoration: BoxDecoration(color: DT.dangerSoft, shape: BoxShape.circle), child: const Icon(Icons.delete_forever_rounded, color: DT.danger, size: 26)),
                const SizedBox(height: 12),
                Text('Delete Group', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: DT.danger)),
                const SizedBox(height: 6),
                Text('This is permanent. All members, payments, and data will be lost.', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: DT.dangerSoft, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    RichText(text: TextSpan(style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4), children: [
                      const TextSpan(text: 'Type '),
                      TextSpan(text: group.name, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: DT.text)),
                      const TextSpan(text: ' to confirm:'),
                    ])),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrl,
                      onChanged: (_) => set(() {}),
                      style: GoogleFonts.manrope(fontSize: 14, color: DT.text),
                      decoration: InputDecoration(
                        hintText: 'Enter group name',
                        hintStyle: GoogleFonts.manrope(fontSize: 13, color: DT.textTertiary),
                        filled: true, fillColor: DT.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: DT.danger.withValues(alpha: 0.4))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: DT.danger.withValues(alpha: 0.3))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.danger, width: 1.5)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _OutlineBtn(label: 'Cancel', color: DT.textSecondary, onTap: () => Navigator.pop(ctx))),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: matches ? () => Navigator.pop(ctx, true) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: matches ? DT.danger : DT.dangerSoft, borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text('Delete', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: matches ? Colors.white : DT.danger.withValues(alpha: 0.5)))),
                    ),
                  )),
                ]),
              ]),
            ),
          );
        },
      ),
    );

    if (ok != true || !mounted) return;

    final groupSvc = ref.read(groupServiceProvider);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final groupId = widget.groupId;

    nav.popUntil((route) => route.isFirst);
    try {
      await groupSvc.deleteGroup(groupId);
      messenger.showSnackBar(const SnackBar(content: Text('Group deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));
    final isAdmin = membersAsync.valueOrNull?.any((m) => m.userId == uid && m.isAdmin) ?? false;

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              _IconBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Expanded(child: Text('Group Settings', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.4))),
            ]),
          ),

          // ── Body ────────────────────────────────────────────
          Expanded(
            child: groupAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (group) {
                if (group == null) return const Center(child: Text('Group not found'));
                final members = membersAsync.valueOrNull ?? [];
                final initials = group.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

                return Stack(children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [

                      // ── Hero group card ────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: DT.primary,
                          borderRadius: BorderRadius.circular(DS.heroRadius),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                              child: Center(child: Text(initials.isNotEmpty ? initials : '?', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(group.name, style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3), overflow: TextOverflow.ellipsis),
                              if (group.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(group.description, style: GoogleFonts.manrope(fontSize: 12, color: Colors.white.withValues(alpha: 0.65)), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ])),
                          ]),
                          const SizedBox(height: 20),
                          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                          const SizedBox(height: 16),
                          // Stat row
                          Row(children: [
                            _HeroStat(
                              icon: Icons.payments_outlined,
                              label: 'Monthly',
                              value: 'RM${group.monthlyAmount.toStringAsFixed(0)}',
                            ),
                            _VertDivider(),
                            _HeroStat(
                              icon: Icons.people_outline_rounded,
                              label: 'Members',
                              value: '${members.length}',
                            ),
                            _VertDivider(),
                            _HeroStat(
                              icon: Icons.notifications_outlined,
                              label: 'Reminder',
                              value: _ordinal(group.reminderDay),
                            ),
                          ]),
                        ]),
                      ),

                      // ── Bank info card ─────────────────────
                      if (group.bankName != null || group.accountNumber != null) ...[
                        const SizedBox(height: DS.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
                          child: Row(children: [
                            Container(width: 38, height: 38, decoration: BoxDecoration(color: DT.accentSoft, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.account_balance_outlined, size: 18, color: DT.accentDeep)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(group.bankName ?? '—', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)),
                              if (group.accountNumber != null)
                                Text(group.accountNumber!, style: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary, fontWeight: FontWeight.w500)),
                              if (group.accountHolderName != null)
                                Text(group.accountHolderName!, style: GoogleFonts.manrope(fontSize: 11, color: DT.textTertiary)),
                            ])),
                            if (isAdmin)
                              GestureDetector(
                                onTap: _busy ? null : () => _bankAccount(group),
                                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: DT.accentSoft, borderRadius: BorderRadius.circular(DS.chipRadius)), child: Text('Edit', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: DT.accentDeep))),
                              ),
                          ]),
                        ),
                      ],

                      if (isAdmin) ...[
                        const SizedBox(height: DS.xl),
                        _SectionLabel('Settings'),
                        const SizedBox(height: DS.sm),
                        _Card(children: [
                          _SettingRow(
                            icon: Icons.edit_outlined, iconBg: DT.primarySoft, iconColor: DT.primary,
                            label: 'Edit group info',
                            subtitle: 'Name, description, amounts',
                            onTap: _busy ? null : () => _editGroup(group),
                          ),
                          _Divider(),
                          _SettingRow(
                            icon: Icons.notifications_active_outlined, iconBg: DT.warningSoft, iconColor: DT.warning,
                            label: 'Payment reminder day',
                            subtitle: '${_ordinal(group.reminderDay)} of each month',
                            onTap: _busy ? null : () => _setReminderDay(group),
                          ),
                          _Divider(),
                          _SettingRow(
                            icon: Icons.account_balance_outlined, iconBg: DT.accentSoft, iconColor: DT.accentDeep,
                            label: 'Bank account details',
                            subtitle: group.bankName ?? 'Not set',
                            onTap: _busy ? null : () => _bankAccount(group),
                          ),
                        ]),

                        const SizedBox(height: DS.sm),
                        _Card(children: [
                          _ToggleRow(
                            icon: Icons.verified_outlined, iconBg: DT.successSoft, iconColor: DT.success,
                            label: 'Auto-approve payments',
                            subtitle: group.autoApprovePayments ? 'Payments confirmed instantly' : 'Requires admin review',
                            value: group.autoApprovePayments,
                            onChanged: _busy ? null : (_) => _toggleAutoApprove(group),
                          ),
                          _Divider(),
                          _ToggleRow(
                            icon: Icons.receipt_long_outlined, iconBg: DT.accentSoft, iconColor: DT.accentDeep,
                            label: 'Auto-approve expenses',
                            subtitle: group.autoApproveExpenses ? 'Expenses approved instantly' : 'Requires admin review',
                            value: group.autoApproveExpenses,
                            onChanged: _busy ? null : (_) => _toggleAutoApproveExpense(group),
                          ),
                        ]),

                        const SizedBox(height: DS.sm),
                        _Card(children: [
                          _SettingRow(
                            icon: Icons.admin_panel_settings_outlined, iconBg: DT.warningSoft, iconColor: DT.warning,
                            label: 'Manage admins',
                            subtitle: 'Promote or demote group admins',
                            onTap: _busy ? null : _manageAdmins,
                            last: true,
                          ),
                        ]),

                        const SizedBox(height: DS.xl),
                        _SectionLabel('Danger zone', danger: true),
                        const SizedBox(height: DS.sm),
                        _Card(children: [
                          _SettingRow(
                            icon: Icons.delete_forever_outlined, iconBg: DT.dangerSoft, iconColor: DT.danger,
                            label: 'Delete group',
                            subtitle: 'Permanently delete all data',
                            onTap: _busy ? null : () => _deleteGroup(group),
                            dangerous: true,
                            last: true,
                          ),
                        ]),
                      ],
                    ],
                  ),
                  if (_busy) Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2))),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Manage admins sheet ──────────────────────────────────────────────────────

class _ManageAdminsSheet extends ConsumerStatefulWidget {
  final String groupId;
  final String currentUserId;
  final ScrollController scrollController;
  const _ManageAdminsSheet({required this.groupId, required this.currentUserId, required this.scrollController});

  @override
  ConsumerState<_ManageAdminsSheet> createState() => _ManageAdminsSheetState();
}

class _ManageAdminsSheetState extends ConsumerState<_ManageAdminsSheet> {
  bool _processing = false;

  Future<void> _promote(GroupMember m) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => _ConfirmDialog(
      title: 'Promote to admin?',
      body: '${m.userName} will be able to manage settings, approve payments, and manage members.',
    ));
    if (ok != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await ref.read(groupServiceProvider).promoteToAdmin(groupId: widget.groupId, requestingUserId: widget.currentUserId, targetUserId: m.userId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m.userName} is now an admin')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _demote(GroupMember m) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => _ConfirmDialog(
      title: 'Remove admin?',
      body: '${m.userName} will become a regular member.',
      destructive: true,
    ));
    if (ok != true || !mounted) return;
    setState(() => _processing = true);
    try {
      await ref.read(groupServiceProvider).demoteAdmin(groupId: widget.groupId, requestingUserId: widget.currentUserId, targetUserId: m.userId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m.userName} is no longer an admin')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));
    return Container(
      decoration: const BoxDecoration(color: DT.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.only(top: 12, bottom: 8), child: Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.borderStrong, borderRadius: BorderRadius.circular(2))))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: DT.warningSoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.admin_panel_settings_outlined, color: DT.warning, size: 18)),
            const SizedBox(width: 12),
            Text('Manage Admins', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text)),
          ]),
        ),
        if (_processing) LinearProgressIndicator(color: DT.accent, backgroundColor: DT.surfaceAlt, minHeight: 2),
        Expanded(
          child: membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (members) {
              final admins = members.where((m) => m.isAdmin).toList();
              final nonAdmins = members.where((m) => !m.isAdmin).toList();
              return ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (admins.isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 8), child: Text('ADMINS', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: DT.textTertiary, letterSpacing: 0.5))),
                    ...admins.map((m) => _MemberTile(member: m, isAdmin: true, isCurrentUser: m.userId == widget.currentUserId, adminCount: admins.length, processing: _processing, onPromote: () => _promote(m), onDemote: () => _demote(m))),
                  ],
                  if (nonAdmins.isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 8), child: Text('MEMBERS', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: DT.textTertiary, letterSpacing: 0.5))),
                    ...nonAdmins.map((m) => _MemberTile(member: m, isAdmin: false, isCurrentUser: m.userId == widget.currentUserId, adminCount: admins.length, processing: _processing, onPromote: () => _promote(m), onDemote: () => _demote(m))),
                  ],
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final GroupMember member;
  final bool isAdmin;
  final bool isCurrentUser;
  final int adminCount;
  final bool processing;
  final VoidCallback onPromote;
  final VoidCallback onDemote;
  const _MemberTile({required this.member, required this.isAdmin, required this.isCurrentUser, required this.adminCount, required this.processing, required this.onPromote, required this.onDemote});

  @override
  Widget build(BuildContext context) {
    final initials = member.userName.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: isAdmin ? DT.primary.withValues(alpha: 0.2) : DT.border),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: isAdmin ? DT.primarySoft : DT.surfaceAlt, shape: BoxShape.circle),
          child: Center(child: Text(initials, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: isAdmin ? DT.primary : DT.textSecondary))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(member.userName, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text), overflow: TextOverflow.ellipsis)),
            if (isAdmin) ...[const SizedBox(width: 6), _Pill('Admin', DT.primarySoft, DT.primary)],
            if (isCurrentUser) ...[const SizedBox(width: 6), _Pill('You', DT.accentSoft, DT.accentDeep)],
          ]),
          if (member.userEmail != null) Text(member.userEmail!, style: GoogleFonts.manrope(fontSize: 11, color: DT.textTertiary), overflow: TextOverflow.ellipsis),
        ])),
        if (!processing)
          isAdmin
            ? (adminCount > 1
                ? GestureDetector(onTap: onDemote, child: Container(width: 34, height: 34, decoration: BoxDecoration(color: DT.dangerSoft, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: DT.danger)))
                : Tooltip(message: 'Last admin', child: Container(width: 34, height: 34, decoration: BoxDecoration(color: DT.surfaceAlt, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.lock_outline_rounded, size: 16, color: DT.textTertiary))))
            : GestureDetector(onTap: onPromote, child: Container(width: 34, height: 34, decoration: BoxDecoration(color: DT.primarySoft, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.add_circle_outline_rounded, size: 18, color: DT.primary))),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Pill(this.label, this.bg, this.fg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
  );
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool danger;
  const _SectionLabel(this.label, {this.danger = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(label.toUpperCase(), style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: danger ? DT.danger : DT.textTertiary, letterSpacing: 0.5)),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(DS.cardRadius), border: Border.all(color: DT.border)),
    child: Column(children: children),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(height: 1, indent: 16, endIndent: 16, color: DT.border);
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool dangerous;
  final bool last;
  const _SettingRow({required this.icon, required this.iconBg, required this.iconColor, required this.label, required this.subtitle, this.onTap, this.dangerous = false, this.last = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, last ? 12 : 0),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: dangerous ? DT.danger : DT.text)),
          Text(subtitle, style: GoogleFonts.manrope(fontSize: 12, color: DT.textTertiary)),
        ])),
        Icon(Icons.chevron_right_rounded, size: 18, color: dangerous ? DT.danger.withValues(alpha: 0.5) : DT.textTertiary),
      ]),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final void Function(bool)? onChanged;
  const _ToggleRow({required this.icon, required this.iconBg, required this.iconColor, required this.label, required this.subtitle, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: iconColor)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)),
        Text(subtitle, style: GoogleFonts.manrope(fontSize: 12, color: DT.textTertiary)),
      ])),
      Transform.scale(scale: 0.85, child: Switch(value: value, onChanged: onChanged, activeThumbColor: DT.success, activeTrackColor: DT.successSoft, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
    ]),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 40, height: 40, decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: DT.border)), child: Icon(icon, size: 20, color: DT.text)),
  );
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _HeroStat({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.7)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.manrope(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
    ]),
  );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.15));
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _OutlineBtn({required this.label, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: color)))),
  );
}

class _FilledBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _FilledBtn({required this.label, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
  );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? inputFormatters;
  const _InputField({required this.controller, required this.label, required this.icon, this.keyboardType, this.capitalization = TextCapitalization.none, this.inputFormatters});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: capitalization,
    inputFormatters: inputFormatters,
    style: GoogleFonts.manrope(fontSize: 14, color: DT.text),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary),
      prefixIcon: Icon(icon, size: 18, color: DT.textSecondary),
      filled: true, fillColor: DT.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.accent, width: 1.5)),
    ),
  );
}

class _FormDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> fields;
  const _FormDialog({required this.title, required this.icon, required this.iconColor, required this.fields});

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: DT.surface,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: iconColor)),
          const SizedBox(width: 10),
          Text(title, style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.text)),
        ]),
        const SizedBox(height: 16),
        ...fields.expand((f) => [f, const SizedBox(height: 12)]).take(fields.length * 2 - 1),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: GestureDetector(onTap: () => Navigator.pop(context, false), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Cancel', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.textSecondary)))))),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(onTap: () => Navigator.pop(context, true), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: DT.text, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Save', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))))),
        ]),
      ]),
    ),
  );
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int? maxLines;
  final TextCapitalization capitalization;
  const _DialogField({required this.controller, required this.label, required this.icon, this.keyboardType, this.maxLines, this.capitalization = TextCapitalization.none});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines ?? 1,
    textCapitalization: capitalization,
    style: GoogleFonts.manrope(fontSize: 14, color: DT.text),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary),
      prefixIcon: Icon(icon, size: 18, color: DT.textSecondary),
      filled: true, fillColor: DT.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DT.accent, width: 1.5)),
    ),
  );
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final bool destructive;
  const _ConfirmDialog({required this.title, required this.body, this.destructive = false});

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: DT.surface,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: destructive ? DT.danger : DT.text)),
        const SizedBox(height: 10),
        Text(body, style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: GestureDetector(onTap: () => Navigator.pop(context, false), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Cancel', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.textSecondary)))))),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(onTap: () => Navigator.pop(context, true), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: destructive ? DT.danger : DT.text, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Confirm', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))))),
        ]),
      ]),
    ),
  );
}
