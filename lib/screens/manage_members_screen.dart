import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/widgets/custom_text_field.dart';
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
        setState(() {
          _isAdmin = isAdmin;
        });
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

    setState(() {
      _isLoading = true;
    });

    try {
      // Search for user by email in users collection
      final profileService = ref.read(profileServiceProvider);
      final userId = await profileService.getUserIdByEmail(email);

      if (userId == null) {
        if (mounted) {
          showSnackBar(
            context,
            'No user found with email: $email',
            isError: true,
          );
        }
        return;
      }

      // Get user profile
      final profile = await profileService.getUserProfile(userId);

      // Add member to group
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeMember(String userId, String userName) async {
    final currentUserId =
        ref.read(authControllerProvider.notifier).currentUser?.uid;

    // Prevent removing yourself
    if (userId == currentUserId) {
      showSnackBar(
        context,
        'You cannot remove yourself from the group',
        isError: true,
      );
      return;
    }

    // Confirm removal
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
                style: TextButton.styleFrom(foregroundColor: Colors.red),
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

      if (mounted) {
        showSnackBar(context, 'Member removed successfully');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Failed to remove member: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Members')),
      body: Column(
        children: [
          // Add Member Section (only for admins)
          if (_isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Member',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the email of the user you want to add',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: _emailController,
                          labelText: 'Email Address',
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _addMember,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Members List
          Expanded(
            child: membersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No members yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
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

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            member.userName[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
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
                                ),
                              ),
                            ),
                            if (member.isAdmin) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (isCurrentUser) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              'Joined ${_formatDate(member.joinedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total: RM${member.totalPaid.toStringAsFixed(2)} (${member.paymentCount} payments)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing:
                            _isAdmin && !isCurrentUser
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error loading members: $error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(
                              groupMembersStreamProvider(widget.groupId),
                            );
                          },
                          child: const Text('Retry'),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
