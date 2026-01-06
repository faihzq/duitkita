import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/models/group_member.dart';
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

  Future<void> _showTransferAdminDialog() async {
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    final members = await ref.read(
      groupMembersStreamProvider(widget.groupId).future,
    );

    // Filter out current user and get only non-admin members
    final eligibleMembers =
        members
            .where((member) => member.userId != userId && !member.isAdmin)
            .toList();

    if (eligibleMembers.isEmpty) {
      if (!mounted) return;
      showSnackBar(
        context,
        'No other members available to transfer admin rights',
      );
      return;
    }

    if (!mounted) return;

    final selectedMember = await showDialog<GroupMember>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Transfer Admin Rights'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a member to become the new admin:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                ...eligibleMembers.map((member) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(member.userName),
                    subtitle: Text(member.userEmail ?? 'No email'),
                    onTap: () => Navigator.of(context).pop(member),
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );

    if (selectedMember != null) {
      await _confirmAndTransferAdmin(selectedMember, userId);
    }
  }

  Future<void> _confirmAndTransferAdmin(
    GroupMember newAdmin,
    String currentAdminId,
  ) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Transfer'),
            content: Text(
              'Are you sure you want to transfer admin rights to ${newAdmin.userName}? You will no longer be the admin of this group.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Transfer'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _transferAdmin(currentAdminId, newAdmin.userId);
    }
  }

  Future<void> _transferAdmin(String currentAdminId, String newAdminId) async {
    setState(() => _isLoading = true);

    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.transferAdmin(
        groupId: widget.groupId,
        currentAdminId: currentAdminId,
        newAdminId: newAdminId,
      );

      if (!mounted) return;

      showSnackBar(context, 'Admin rights transferred successfully');
      Navigator.of(context).pop(); // Close settings screen
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Group Settings')),
      body: membersAsync.when(
        data: (members) {
          final currentUserMember = members.firstWhere(
            (m) => m.userId == userId,
            orElse:
                () => GroupMember(
                  userId: '',
                  userName: '',
                  isAdmin: false,
                  joinedAt: DateTime.now(),
                  totalPaid: 0.0,
                  paymentCount: 0,
                ),
          );

          final isCurrentUserAdmin = currentUserMember.isAdmin;

          return Stack(
            children: [
              ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.groupName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  if (isCurrentUserAdmin) ...[
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings),
                      title: const Text('Transfer Admin Rights'),
                      subtitle: const Text(
                        'Transfer admin rights to another member',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _isLoading ? null : _showTransferAdminDialog,
                    ),
                    const Divider(),
                  ],
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Group Info'),
                    subtitle: Text('${members.length} members'),
                  ),
                ],
              ),
              if (_isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) =>
                Center(child: Text('Error loading settings: $error')),
      ),
    );
  }
}
