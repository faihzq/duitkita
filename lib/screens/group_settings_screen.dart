import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/models/group_model.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/utils/utils.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const GroupSettingsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  bool _isLoading = false;

  // Helper to get ordinal suffix for day numbers
  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1: return '${day}st';
      case 2: return '${day}nd';
      case 3: return '${day}rd';
      default: return '${day}th';
    }
  }

  // ============================================================
  // Edit Group Info
  // ============================================================

  Future<void> _showEditGroupDialog() async {
    final group = await ref.read(groupStreamProvider(widget.groupId).future);
    if (group == null || !mounted) return;

    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description);
    final amountController = TextEditingController(text: group.monthlyAmount.toStringAsFixed(2));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Edit Group', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: AppTheme.styledInput(
                  label: 'Group Name',
                  prefixIcon: Icons.group,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: AppTheme.styledInput(
                  label: 'Description',
                  prefixIcon: Icons.description,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: AppTheme.styledInput(
                  label: 'Monthly Amount (RM)',
                  prefixIcon: Icons.payments,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final newName = nameController.text.trim();
    final newDesc = descController.text.trim();
    final newAmount = double.tryParse(amountController.text.trim());

    if (newName.isEmpty) {
      showSnackBar(context, 'Group name cannot be empty');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.updateGroup(
        groupId: widget.groupId,
        name: newName,
        description: newDesc,
        monthlyAmount: newAmount,
      );
      if (!mounted) return;
      showSnackBar(context, 'Group updated successfully');
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    nameController.dispose();
    descController.dispose();
    amountController.dispose();
  }

  // ============================================================
  // Set Reminder Day
  // ============================================================

  Future<void> _showReminderDayDialog() async {
    final group = await ref.read(groupStreamProvider(widget.groupId).future);
    if (group == null || !mounted) return;

    int selectedDay = group.reminderDay;

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Header icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Payment Reminder Day',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Members will be reminded on this day\neach month to make their payment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 28),

                // Day selector - scrollable grid
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Text('Select Day', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: 28,
                        itemBuilder: (context, index) {
                          final day = index + 1;
                          final isSelected = day == selectedDay;

                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedDay = day),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                gradient: isSelected ? AppTheme.cardGradient : null,
                                color: isSelected ? null : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : null,
                              ),
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Selected day display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_available, size: 20, color: AppTheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            children: [
                              const TextSpan(text: 'Reminders will be sent on the '),
                              TextSpan(
                                text: _getOrdinalSuffix(selectedDay),
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary),
                              ),
                              const TextSpan(text: ' of every month'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, selectedDay),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.updateGroup(
        groupId: widget.groupId,
        reminderDay: result,
      );
      if (!mounted) return;
      showSnackBar(context, 'Reminder day set to ${_getOrdinalSuffix(result)} of each month');
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Bank Account Settings
  // ============================================================

  Future<void> _showBankAccountDialog() async {
    final group = await ref.read(groupStreamProvider(widget.groupId).future);
    if (group == null || !mounted) return;

    final bankNameController = TextEditingController(text: group.bankName ?? '');
    final accountNumberController = TextEditingController(text: group.accountNumber ?? '');
    final accountHolderController = TextEditingController(text: group.accountHolderName ?? '');

    final malaysianBanks = [
      'Maybank',
      'CIMB Bank',
      'Public Bank',
      'RHB Bank',
      'Hong Leong Bank',
      'AmBank',
      'Bank Islam',
      'BSN',
      'Alliance Bank',
      'Affin Bank',
      'Bank Rakyat',
      'OCBC Bank',
      'UOB Bank',
      'Standard Chartered',
      'HSBC Bank',
      'Other',
    ];

    String? selectedBank = group.bankName != null && malaysianBanks.contains(group.bankName)
        ? group.bankName
        : (group.bankName != null ? 'Other' : null);

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.viewInsetsOf(ctx).bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.cardGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bank Account',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Members will transfer payments\nto this account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 28),

                  // Bank selector
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance, size: 18, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            const Text('Select Bank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 180,
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 2.4,
                            ),
                            itemCount: malaysianBanks.length,
                            itemBuilder: (context, index) {
                              final bank = malaysianBanks[index];
                              final isSelected = bank == selectedBank;

                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedBank = bank;
                                    if (bank != 'Other') {
                                      bankNameController.text = bank;
                                    } else {
                                      bankNameController.text = '';
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    gradient: isSelected ? AppTheme.cardGradient : null,
                                    color: isSelected ? null : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                                    boxShadow: isSelected ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ] : null,
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        bank,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Custom bank name field (when "Other" is selected)
                  if (selectedBank == 'Other') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: bankNameController,
                      decoration: AppTheme.styledInput(
                        label: 'Bank Name',
                        prefixIcon: Icons.account_balance,
                        hint: 'Enter your bank name',
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Account details
                  TextField(
                    controller: accountNumberController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: AppTheme.styledInput(
                      label: 'Account Number',
                      prefixIcon: Icons.numbers,
                      hint: 'e.g. 1234567890',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: accountHolderController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) =>
                        newValue.copyWith(text: newValue.text.toUpperCase())),
                    ],
                    decoration: AppTheme.styledInput(
                      label: 'Account Holder Name',
                      prefixIcon: Icons.person,
                      hint: 'Name as per bank account',
                    ),
                  ),

                  // Selected bank preview
                  if (selectedBank != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 20, color: AppTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                children: [
                                  const TextSpan(text: 'Bank: '),
                                  TextSpan(
                                    text: selectedBank == 'Other'
                                        ? (bankNameController.text.isNotEmpty ? bankNameController.text : 'Enter name above')
                                        : selectedBank!,
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              if (selectedBank != null && selectedBank != 'Other') {
                                bankNameController.text = selectedBank!;
                              }
                              Navigator.pop(ctx, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.updateGroup(
        groupId: widget.groupId,
        bankName: bankNameController.text.trim().isEmpty ? null : bankNameController.text.trim(),
        accountNumber: accountNumberController.text.trim().isEmpty ? null : accountNumberController.text.trim(),
        accountHolderName: accountHolderController.text.trim().isEmpty ? null : accountHolderController.text.trim(),
      );
      if (!mounted) return;
      showSnackBar(context, 'Bank account details updated');
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    bankNameController.dispose();
    accountNumberController.dispose();
    accountHolderController.dispose();
  }

  // ============================================================
  // Transfer Admin
  // ============================================================

  Future<void> _showTransferAdminDialog() async {
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    final members = await ref.read(
      groupMembersStreamProvider(widget.groupId).future,
    );

    final eligibleMembers =
        members.where((m) => m.userId != userId && !m.isAdmin).toList();

    if (eligibleMembers.isEmpty) {
      if (!mounted) return;
      showSnackBar(context, 'No other members available to transfer admin rights');
      return;
    }

    if (!mounted) return;

    final selectedMember = await showDialog<GroupMember>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Admin Rights'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select a member to become the new admin:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            ...eligibleMembers.map((member) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(member.userName),
              subtitle: Text(member.userEmail ?? 'No email'),
              onTap: () => Navigator.of(context).pop(member),
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ],
      ),
    );

    if (selectedMember == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Transfer'),
        content: Text(
          'Are you sure you want to transfer admin rights to ${selectedMember.userName}? You will no longer be the admin.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.transferAdmin(
        groupId: widget.groupId,
        currentAdminId: userId,
        newAdminId: selectedMember.userId,
      );
      if (!mounted) return;
      showSnackBar(context, 'Admin rights transferred successfully');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Delete Group
  // ============================================================

  Future<void> _showDeleteGroupDialog() async {
    final group = await ref.read(groupStreamProvider(widget.groupId).future);
    if (group == null || !mounted) return;

    final confirmController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final matchesName = confirmController.text.trim() == group.name;

          return Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.viewInsetsOf(ctx).bottom + 24),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Header icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delete Group',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.error),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This action is permanent and cannot be undone.\nAll members, payments, and data will be lost.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),

                // Confirmation input
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                          children: [
                            const TextSpan(text: 'Type '),
                            TextSpan(
                              text: group.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                            const TextSpan(text: ' to confirm deletion.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmController,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Enter group name',
                          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textHint),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 8),
                            child: Icon(Icons.warning_amber_rounded, size: 20, color: AppTheme.error),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.error.withValues(alpha: 0.3))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.error.withValues(alpha: 0.3))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.error, width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: matchesName ? () => Navigator.pop(ctx, true) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.error.withValues(alpha: 0.3),
                            disabledForegroundColor: Colors.white54,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    // Capture references before navigating away
    final groupService = ref.read(groupServiceProvider);
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final groupId = widget.groupId;

    // Navigate away FIRST to avoid stream errors from deleted data
    navigator.popUntil((route) => route.isFirst);

    // Then delete the group in the background
    try {
      await groupService.deleteGroup(groupId);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Group deleted successfully')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error deleting group: $e')),
      );
    }
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));
    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Group Settings'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: membersAsync.when(
        data: (members) {
          final isAdmin = members.any((m) => m.userId == userId && m.isAdmin);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Group Info Card
                  groupAsync.when(
                    data: (group) {
                      if (group == null) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.cardGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(group.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                      if (group.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(group.description, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            _infoRow(Icons.payments_outlined, 'Monthly Amount', 'RM${group.monthlyAmount.toStringAsFixed(2)}'),
                            const SizedBox(height: 10),
                            _infoRow(Icons.people_outline, 'Members', '${members.length}'),
                            const SizedBox(height: 10),
                            _infoRow(Icons.calendar_today, 'Created', '${group.createdAt.day}/${group.createdAt.month}/${group.createdAt.year}'),
                            const SizedBox(height: 10),
                            _infoRow(Icons.notifications_outlined, 'Reminder Day', '${_getOrdinalSuffix(group.reminderDay)} of each month'),
                            const SizedBox(height: 10),
                            _infoRow(Icons.verified_outlined, 'Payments', group.autoApprovePayments ? 'Auto-approved' : 'Admin review'),
                            const SizedBox(height: 10),
                            _infoRow(Icons.receipt_long_outlined, 'Expenses', group.autoApproveExpenses ? 'Auto-approved' : 'Admin review'),
                            if (group.bankName != null || group.accountNumber != null) ...[
                              const SizedBox(height: 10),
                              _infoRow(Icons.account_balance_outlined, 'Bank', group.bankName ?? 'Not set'),
                              if (group.accountNumber != null) ...[
                                const SizedBox(height: 10),
                                _infoRow(Icons.numbers_outlined, 'Account', group.accountNumber ?? '-'),
                              ],
                              if (group.accountHolderName != null) ...[
                                const SizedBox(height: 10),
                                _infoRow(Icons.person_outline, 'Holder', group.accountHolderName ?? '-'),
                              ],
                            ],
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  if (isAdmin) ...[
                    const SizedBox(height: 20),

                    // Admin Actions Section
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('Admin Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                    ),

                    _settingsTile(
                      icon: Icons.edit_outlined,
                      iconColor: AppTheme.primary,
                      title: 'Edit Group Info',
                      subtitle: 'Change name, description, or monthly amount',
                      onTap: _isLoading ? null : _showEditGroupDialog,
                    ),
                    const SizedBox(height: 10),
                    _settingsTile(
                      icon: Icons.notifications_active_outlined,
                      iconColor: AppTheme.accent,
                      title: 'Payment Reminder Day',
                      subtitle: 'Set when members get payment reminders',
                      onTap: _isLoading ? null : _showReminderDayDialog,
                    ),
                    const SizedBox(height: 10),
                    _settingsTile(
                      icon: Icons.account_balance_outlined,
                      iconColor: const Color(0xFF1976D2),
                      title: 'Bank Account Details',
                      subtitle: 'Set account for receiving payments',
                      onTap: _isLoading ? null : _showBankAccountDialog,
                    ),
                    const SizedBox(height: 10),
                    _buildAutoApproveToggle(groupAsync),
                    const SizedBox(height: 10),
                    _buildAutoApproveExpenseToggle(groupAsync),
                    const SizedBox(height: 10),
                    _settingsTile(
                      icon: Icons.admin_panel_settings_outlined,
                      iconColor: AppTheme.warning,
                      title: 'Transfer Admin Rights',
                      subtitle: 'Transfer admin role to another member',
                      onTap: _isLoading ? null : _showTransferAdminDialog,
                    ),

                    const SizedBox(height: 28),

                    // Danger Zone
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('Danger Zone', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.error)),
                    ),

                    _settingsTile(
                      icon: Icons.delete_forever_outlined,
                      iconColor: AppTheme.error,
                      title: 'Delete Group',
                      subtitle: 'Permanently delete this group and all data',
                      onTap: _isLoading ? null : _showDeleteGroupDialog,
                    ),
                  ],
                ],
              ),
              if (_isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildAutoApproveToggle(AsyncValue<GroupModel?> groupAsync) {
    final group = groupAsync.valueOrNull;
    final autoApprove = group?.autoApprovePayments ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF00897B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: const Icon(Icons.verified_outlined, color: Color(0xFF00897B), size: 22),
        ),
        title: const Text('Auto-Approve Payments', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          autoApprove ? 'Payments are confirmed automatically' : 'Payments require admin review',
          style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
        ),
        trailing: Switch.adaptive(
          value: autoApprove,
          activeTrackColor: const Color(0xFF00897B).withValues(alpha: 0.5),
          activeThumbColor: const Color(0xFF00897B),
          onChanged: _isLoading ? null : (value) async {
            // Show confirmation dialog when enabling
            if (value) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Enable Auto-Approve Payments?'),
                  content: const Text(
                    'All existing pending payments will be confirmed automatically. '
                    'New payments will also be approved without admin review.\n\n'
                    'Are you sure you want to continue?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Enable'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
            }

            setState(() => _isLoading = true);
            try {
              final groupService = ref.read(groupServiceProvider);
              await groupService.updateGroup(
                groupId: widget.groupId,
                autoApprovePayments: value,
              );

              // When enabling, confirm all pending payments
              if (value) {
                final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
                if (userId != null) {
                  final paymentService = ref.read(paymentServiceProvider);
                  final profileService = ref.read(profileServiceProvider);
                  final profile = await profileService.getUserProfile(userId);
                  final count = await paymentService.confirmAllPendingPayments(
                    groupId: widget.groupId,
                    verifiedBy: userId,
                    verifiedByName: profile?.name ?? 'Admin',
                  );
                  if (!mounted) return;
                  if (count > 0) {
                    showSnackBar(context, 'Payments auto-approved. $count pending payment${count > 1 ? 's' : ''} confirmed.');
                  } else {
                    showSnackBar(context, 'Payments will be auto-approved');
                  }
                }
              } else {
                if (!mounted) return;
                showSnackBar(context, 'Payments will require admin review');
              }
            } catch (e) {
              if (!mounted) return;
              showSnackBar(context, 'Error: $e');
            } finally {
              if (mounted) setState(() => _isLoading = false);
            }
          },
        ),
      ),
    );
  }

  Widget _buildAutoApproveExpenseToggle(AsyncValue<GroupModel?> groupAsync) {
    final group = groupAsync.valueOrNull;
    final autoApprove = group?.autoApproveExpenses ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0277BD).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF0277BD), size: 22),
        ),
        title: const Text('Auto-Approve Expenses', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          autoApprove ? 'Expenses are approved automatically' : 'Expenses require admin review',
          style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
        ),
        trailing: Switch.adaptive(
          value: autoApprove,
          activeTrackColor: const Color(0xFF0277BD).withValues(alpha: 0.5),
          activeThumbColor: const Color(0xFF0277BD),
          onChanged: _isLoading ? null : (value) async {
            // Show confirmation dialog when enabling
            if (value) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Enable Auto-Approve Expenses?'),
                  content: const Text(
                    'All existing pending expenses will be approved automatically. '
                    'New expenses will also be approved without admin review.\n\n'
                    'Are you sure you want to continue?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Enable'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
            }

            setState(() => _isLoading = true);
            try {
              final groupService = ref.read(groupServiceProvider);
              await groupService.updateGroup(
                groupId: widget.groupId,
                autoApproveExpenses: value,
              );

              // When enabling, approve all pending expenses
              if (value) {
                final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
                if (userId != null) {
                  final expenseService = ref.read(expenseServiceProvider);
                  final profileService = ref.read(profileServiceProvider);
                  final profile = await profileService.getUserProfile(userId);
                  final count = await expenseService.approveAllPendingExpenses(
                    groupId: widget.groupId,
                    approvedBy: userId,
                    approvedByName: profile?.name ?? 'Admin',
                  );
                  if (!mounted) return;
                  if (count > 0) {
                    showSnackBar(context, 'Expenses auto-approved. $count pending expense${count > 1 ? 's' : ''} approved.');
                  } else {
                    showSnackBar(context, 'Expenses will be auto-approved');
                  }
                }
              } else {
                if (!mounted) return;
                showSnackBar(context, 'Expenses will require admin review');
              }
            } catch (e) {
              if (!mounted) return;
              showSnackBar(context, 'Error: $e');
            } finally {
              if (mounted) setState(() => _isLoading = false);
            }
          },
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textHint),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textHint),
        onTap: onTap,
      ),
    );
  }
}
