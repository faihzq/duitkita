import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/utils/utils.dart';

class ManageMembersScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const ManageMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<ManageMembersScreen> createState() =>
      _ManageMembersScreenState();
}

class _ManageMembersScreenState extends ConsumerState<ManageMembersScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId != null) {
      final groupService = ref.read(groupServiceProvider);
      final isAdmin = await groupService.isUserAdmin(widget.groupId, userId);
      if (mounted) {
        setState(() => _isAdmin = isAdmin);
      }
    }
  }

  Future<void> _addMember() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      showSnackBar(context, 'Please enter an email', isError: true);
      return;
    }

    if (!isValidEmail(email)) {
      showSnackBar(context, 'Please enter a valid email', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileService = ref.read(profileServiceProvider);
      final userId = await profileService.getUserIdByEmail(email);

      if (userId == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        // User not found — offer to send invite
        _showInviteDialog(email);
        return;
      }

      final profile = await profileService.getUserProfile(userId);
      final groupService = ref.read(groupServiceProvider);
      await groupService.addMemberToGroup(
        groupId: widget.groupId,
        userId: userId,
        userName: profile?.name ?? 'Unknown',
        userEmail: email,
      );

      if (mounted) {
        showSnackBar(context, 'Member added successfully!');
        _emailController.clear();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInviteDialog(String email) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.person_off_outlined,
                    color: AppTheme.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'User Not Found',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'No account found for '),
                      TextSpan(
                        text: email,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const TextSpan(
                        text:
                            '.\n\nWould you like to send them an invitation to download DuitKita?',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _sendInvite(email);
                },
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Send Invite'),
              ),
            ],
          ),
    );
  }

  Future<void> _sendInvite(String email) async {
    final inviteMessage =
        'Hey! I\'m inviting you to join "${widget.groupName}" on DuitKita - '
        'our family app for tracking monthly payments and expenses.\n\n'
        'Download the app and sign up with your email ($email) so I can add you to the group.\n\n'
        'Download here: https://appdistribution.firebase.dev/i/24015162eba1d1f9\n\n'
        'After installing:\n'
        '1. Open DuitKita\n'
        '2. Sign up with $email\n'
        '3. Let me know and I\'ll add you to the group!';

    await SharePlus.instance.share(
      ShareParams(
        text: inviteMessage,
        subject: 'Join ${widget.groupName} on DuitKita',
      ),
    );
  }

  void _showShareInviteSheet() {
    final inviteMessage =
        'Join "${widget.groupName}" on DuitKita! '
        'Track monthly payments and expenses with family.\n\n'
        'Download: https://appdistribution.firebase.dev/i/24015162eba1d1f9\n\n'
        'Sign up and let me know your email so I can add you!';

    SharePlus.instance.share(
      ShareParams(
        text: inviteMessage,
        subject: 'Join ${widget.groupName} on DuitKita',
      ),
    );
  }

  Future<void> _removeMember(String userId, String userName) async {
    final currentUserId =
        ref.read(authControllerProvider.notifier).currentUser?.uid;

    if (userId == currentUserId) {
      showSnackBar(
        context,
        'You cannot remove yourself from the group',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Member'),
            content: Text('Are you sure you want to remove $userName?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.removeMemberFromGroup(
        groupId: widget.groupId,
        userId: userId,
      );
      if (mounted) showSnackBar(context, 'Member removed successfully');
    } catch (e) {
      if (mounted)
        showSnackBar(context, 'Failed to remove member: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Members'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.share, size: 22),
              tooltip: 'Invite People',
              onPressed: _showShareInviteSheet,
            ),
        ],
      ),
      body: Column(
        children: [
          // Add Member Section (admin only)
          if (_isAdmin)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Member',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter email or tap share to invite',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'member@email.com',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addMember,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.person_add, size: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Members List
          Expanded(
            child: membersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.people_outline,
                            size: 48,
                            color: AppTheme.textHint,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No members yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textHint,
                          ),
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showShareInviteSheet,
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Invite People'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isCurrentUser = member.userId == currentUserId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient:
                                member.isAdmin
                                    ? AppTheme.cardGradient
                                    : AppTheme.successGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              member.userName.isNotEmpty
                                  ? member.userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                member.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (member.isAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            if (member.userEmail != null)
                              Text(
                                member.userEmail!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textHint,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              'RM${member.totalPaid.toStringAsFixed(2)} paid - ${member.paymentCount} payments',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing:
                            _isAdmin && !isCurrentUser && !member.isAdmin
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: AppTheme.error,
                                    size: 22,
                                  ),
                                  onPressed:
                                      () => _removeMember(
                                        member.userId,
                                        member.userName,
                                      ),
                                  tooltip: 'Remove member',
                                )
                                : null,
                      ),
                    );
                  },
                );
              },
              loading:
                  () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
