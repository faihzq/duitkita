import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/screens/add_payment_screen.dart';
import 'package:duitkita/screens/payment_history_screen.dart';
import 'package:duitkita/screens/manage_members_screen.dart';
import 'package:duitkita/screens/group_settings_screen.dart';
import 'package:duitkita/screens/group_analytics_screen.dart';
import 'package:duitkita/screens/expense_list_screen.dart';
import 'package:duitkita/screens/bulk_import_screen.dart';
import 'package:duitkita/screens/pending_payments_review_screen.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/models/payment_model.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/utils/utils.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Returns: 'confirmed', 'pending', 'rejected', or 'unpaid'
  Future<Map<String, _MemberPaymentInfo>> _getMonthlyPaymentStatus(
    List<GroupMember> members,
  ) async {
    final paymentService = ref.read(paymentServiceProvider);
    final Map<String, _MemberPaymentInfo> result = {};

    for (var member in members) {
      final payments = await paymentService.getUserMonthPayments(
        groupId: widget.groupId,
        userId: member.userId,
        month: _selectedMonth,
        year: _selectedYear,
      );

      if (payments.isEmpty) {
        result[member.userId] = _MemberPaymentInfo(status: 'unpaid');
      } else {
        final payment = payments.first;
        result[member.userId] = _MemberPaymentInfo(
          status: payment.paymentStatus,
          paymentId: payment.id,
          amount: payment.amount,
          payment: payment,
        );
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }

          // Check if user is admin
          final isAdmin = membersAsync.valueOrNull
              ?.any((m) => m.userId == userId && m.isAdmin) ?? false;

          return CustomScrollView(
            slivers: [
              // Custom gradient header
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(AppTheme.radiusXLarge),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top bar: back + settings
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  AppTheme.slideRoute(GroupSettingsScreen(
                                    groupId: widget.groupId,
                                    groupName: group.name,
                                  )),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Group name & description
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (group.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              group.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Info chips
                          Row(
                            children: [
                              _buildHeaderChip(Icons.people_outline, '${group.memberCount} Members'),
                              const SizedBox(width: 10),
                              _buildHeaderChip(Icons.payments_outlined, 'RM${group.monthlyAmount.toStringAsFixed(2)}/mo'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Quick Actions',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildQuickAction(
                              icon: Icons.people_outline,
                              label: 'Members',
                              color: const Color(0xFF7B1FA2),
                              onTap: () => Navigator.of(context).push(
                                AppTheme.slideRoute(ManageMembersScreen(
                                  groupId: widget.groupId,
                                  groupName: group.name,
                                )),
                              ),
                            ),
                            _buildQuickAction(
                              icon: Icons.history_rounded,
                              label: 'History',
                              color: const Color(0xFF1565C0),
                              onTap: () => Navigator.of(context).push(
                                AppTheme.slideRoute(PaymentHistoryScreen(groupId: widget.groupId)),
                              ),
                            ),
                            _buildQuickAction(
                              icon: Icons.bar_chart_rounded,
                              label: 'Analytics',
                              color: const Color(0xFF00897B),
                              onTap: () => Navigator.of(context).push(
                                AppTheme.slideRoute(GroupAnalyticsScreen(
                                  groupId: widget.groupId,
                                  groupName: group.name,
                                )),
                              ),
                            ),
                            Consumer(
                              builder: (context, ref, child) {
                                final pendingAsync = ref.watch(pendingExpensesStreamProvider(widget.groupId));
                                final pendingCount = pendingAsync.valueOrNull?.length ?? 0;
                                return _buildQuickAction(
                                  icon: Icons.receipt_long_outlined,
                                  label: 'Expenses',
                                  color: const Color(0xFFE65100),
                                  badge: pendingCount,
                                  onTap: () => Navigator.of(context).push(
                                    AppTheme.slideRoute(ExpenseListScreen(
                                      groupId: widget.groupId,
                                      groupName: group.name,
                                    )),
                                  ),
                                );
                              },
                            ),
                            if (isAdmin)
                              Consumer(
                                builder: (context, ref, child) {
                                  final pendingPaymentsAsync = ref.watch(pendingPaymentsStreamProvider(widget.groupId));
                                  final pendingCount = pendingPaymentsAsync.valueOrNull?.length ?? 0;
                                  return _buildQuickAction(
                                    icon: Icons.fact_check_outlined,
                                    label: 'Review',
                                    color: const Color(0xFFE65100),
                                    badge: pendingCount,
                                    onTap: () => Navigator.of(context).push(
                                      AppTheme.slideRoute(PendingPaymentsReviewScreen(
                                        groupId: widget.groupId,
                                        groupName: group.name,
                                      )),
                                    ),
                                  );
                                },
                              ),
                            if (isAdmin)
                              _buildQuickAction(
                                icon: Icons.upload_outlined,
                                label: 'Import',
                                color: const Color(0xFF6A1B9A),
                                onTap: () => Navigator.of(context).push(
                                  AppTheme.slideRoute(BulkImportScreen(
                                    groupId: widget.groupId,
                                    groupName: group.name,
                                    monthlyAmount: group.monthlyAmount,
                                    groupCreatedAt: group.createdAt,
                                  )),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Month selector
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Payment Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedMonth == 1) {
                              _selectedMonth = 12;
                              _selectedYear--;
                            } else {
                              _selectedMonth--;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: const Icon(Icons.chevron_left, size: 20, color: AppTheme.textSecondary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showMonthYearPicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_getMonthName(_selectedMonth)} $_selectedYear',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.calendar_month_outlined, size: 16, color: AppTheme.primary),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedMonth == 12) {
                              _selectedMonth = 1;
                              _selectedYear++;
                            } else {
                              _selectedMonth++;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: const Icon(Icons.chevron_right, size: 20, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Members List with Payment Status
              membersAsync.when(
                data: (members) {
                  return SliverToBoxAdapter(
                    child: FutureBuilder<Map<String, _MemberPaymentInfo>>(
                      future: _getMonthlyPaymentStatus(members),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: CircularProgressIndicator(color: AppTheme.primary),
                            ),
                          );
                        }

                        final paymentStatus = snapshot.data!;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          child: Column(
                            children: members.map((member) {
                              final info = paymentStatus[member.userId] ?? _MemberPaymentInfo(status: 'unpaid');
                              return _buildMemberCard(
                                context,
                                member: member,
                                paymentInfo: info,
                                isCurrentUser: member.userId == userId,
                                isAdmin: isAdmin,
                                group: group,
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  ),
                ),
                error: (error, stack) => SliverToBoxAdapter(
                  child: Center(child: Text('Error loading members: $error')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (error, stack) => Center(child: Text('Error loading group: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final group = groupAsync.value;
          if (group != null) {
            Navigator.of(context).push(
              AppTheme.slideRoute(AddPaymentScreen(
                groupId: widget.groupId,
                monthlyAmount: group.monthlyAmount,
                selectedMonth: _selectedMonth,
                selectedYear: _selectedYear,
              )),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Payment', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              badge > 0
                  ? Badge(
                      label: Text(badge.toString(), style: const TextStyle(fontSize: 9)),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 22, color: color),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 22, color: color),
                    ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    BuildContext context, {
    required GroupMember member,
    required _MemberPaymentInfo paymentInfo,
    required bool isCurrentUser,
    required bool isAdmin,
    required dynamic group,
  }) {
    final status = paymentInfo.status;
    final isPaid = status == 'confirmed' || status == 'pending';
    final isPending = status == 'pending';
    final isConfirmed = status == 'confirmed';
    final isRejected = status == 'rejected';

    // Status colors and icons
    LinearGradient avatarGradient;
    IconData avatarIcon;
    String statusLabel;
    Color statusColor;

    if (isConfirmed) {
      avatarGradient = const LinearGradient(colors: [Color(0xFF00897B), Color(0xFF00BFA5)]);
      avatarIcon = Icons.check_rounded;
      statusLabel = 'Confirmed';
      statusColor = AppTheme.success;
    } else if (isPending) {
      avatarGradient = const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFFCC02)]);
      avatarIcon = Icons.hourglass_top_rounded;
      statusLabel = 'Pending Verification';
      statusColor = const Color(0xFFF57C00);
    } else if (isRejected) {
      avatarGradient = const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF5252)]);
      avatarIcon = Icons.close_rounded;
      statusLabel = 'Rejected';
      statusColor = AppTheme.error;
    } else {
      avatarGradient = const LinearGradient(colors: [Color(0xFF9E9E9E), Color(0xFFBDBDBD)]);
      avatarIcon = Icons.remove_rounded;
      statusLabel = 'Not paid';
      statusColor = AppTheme.textHint;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
        border: isCurrentUser
            ? Border.all(color: AppTheme.primary.withValues(alpha: 0.2), width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                // Status avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: avatarGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 4),
                  ),
                  child: Icon(avatarIcon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),

                // Member info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.userName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (member.isAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: AppTheme.cardGradient,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: const Text(
                                'Admin',
                                style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                          if (isCurrentUser) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w600),
                      ),
                      if (isRejected && paymentInfo.payment?.rejectionReason != null && paymentInfo.payment!.rejectionReason!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Reason: ${paymentInfo.payment!.rejectionReason}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.error),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        'Total: RM${member.totalPaid.toStringAsFixed(2)} (${member.paymentCount} payments)',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ),

                // Pay button for current user
                if (isCurrentUser && !isPaid && !isRejected)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        AppTheme.slideRoute(AddPaymentScreen(
                          groupId: widget.groupId,
                          monthlyAmount: group.monthlyAmount,
                          selectedMonth: _selectedMonth,
                          selectedYear: _selectedYear,
                        )),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
                      ),
                      child: const Text(
                        'Pay',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),

            // Admin review button for pending payments
            if (isAdmin && isPending && paymentInfo.paymentId != null && paymentInfo.payment != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showPaymentReviewModal(
                  context,
                  payment: paymentInfo.payment!,
                  memberName: member.userName,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility_outlined, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Review Payment',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _verifyPayment(String paymentId, String status, String memberName, {BuildContext? modalContext, String? rejectionReason}) async {
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    try {
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getUserProfile(userId);

      final paymentService = ref.read(paymentServiceProvider);
      await paymentService.verifyPayment(
        paymentId: paymentId,
        status: status,
        verifiedBy: userId,
        verifiedByName: profile?.name ?? 'Admin',
        rejectionReason: rejectionReason,
      );

      if (mounted) {
        if (modalContext != null) Navigator.of(modalContext).pop();
        final action = status == 'confirmed' ? 'confirmed' : 'rejected';
        showSnackBar(context, 'Payment by $memberName $action');
        setState(() {}); // Refresh the FutureBuilder
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to update payment: $e', isError: true);
      }
    }
  }

  void _showRejectDialog(BuildContext modalContext, String paymentId, String memberName) {
    final reasonController = TextEditingController();

    showDialog(
      context: modalContext,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded, color: AppTheme.error, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Reject Payment',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Please provide a reason for rejecting $memberName\'s payment.',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'e.g. Wrong amount, invalid receipt...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textHint),
                  filled: true,
                  fillColor: AppTheme.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _verifyPayment(
                          paymentId, 'rejected', memberName,
                          modalContext: modalContext,
                          rejectionReason: reasonController.text.trim(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentReviewModal(
    BuildContext context, {
    required PaymentModel payment,
    required String memberName,
  }) {
    final paymentDate = payment.paymentDate;
    final dateStr = '${paymentDate.day}/${paymentDate.month}/${paymentDate.year}';
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
      builder: (modalContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA726).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.rate_review_outlined, color: Color(0xFFFFA726), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review Payment',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'By $memberName',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(modalContext),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey.shade200),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Payment Amount',
                            style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'RM${payment.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Payment details
                    _buildReviewRow(Icons.calendar_today_outlined, 'Payment Date', dateStr),
                    _buildReviewRow(Icons.payment_outlined, 'Payment Method', methodLabel),
                    if (payment.transactionReference != null && payment.transactionReference!.isNotEmpty)
                      _buildReviewRow(Icons.tag, 'Reference', payment.transactionReference!),
                    if (payment.notes != null && payment.notes!.isNotEmpty)
                      _buildReviewRow(Icons.notes_outlined, 'Notes', payment.notes!),

                    // Receipt image
                    if (payment.receiptUrl != null && payment.receiptUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Receipt',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          payment.receiptUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined, color: AppTheme.textHint, size: 32),
                                  SizedBox(height: 4),
                                  Text('Failed to load receipt', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // No receipt notice
                    if (payment.receiptUrl == null || payment.receiptUrl!.isEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFE0B2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No receipt uploaded for this payment',
                                style: TextStyle(fontSize: 13, color: Color(0xFFF57C00), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showRejectDialog(modalContext, payment.id, memberName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.error, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close_rounded, color: AppTheme.error, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Reject',
                                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _verifyPayment(
                          payment.id, 'confirmed', memberName,
                          modalContext: modalContext,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF00897B), Color(0xFF00BFA5)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Confirm',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
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
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textHint, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthYearPicker(BuildContext context) {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => setDialogState(() => tempYear--),
                        icon: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.cardBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      Text(
                        '$tempYear',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        onPressed: () => setDialogState(() => tempYear++),
                        icon: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.cardBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Month grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (ctx, index) {
                      final month = index + 1;
                      final isSelected = month == tempMonth;
                      final isCurrentMonth = month == DateTime.now().month && tempYear == DateTime.now().year;

                      return GestureDetector(
                        onTap: () => setDialogState(() => tempMonth = month),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppTheme.primaryGradient : null,
                            color: isSelected ? null : (isCurrentMonth ? AppTheme.primary.withValues(alpha: 0.08) : Colors.transparent),
                            borderRadius: BorderRadius.circular(10),
                            border: isCurrentMonth && !isSelected
                                ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3))
                                : null,
                          ),
                          child: Text(
                            _getMonthShort(month),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedMonth = tempMonth;
                              _selectedYear = tempYear;
                            });
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Select', style: TextStyle(fontWeight: FontWeight.w700)),
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
  }

  String _getMonthShort(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }
}

class _MemberPaymentInfo {
  final String status; // 'confirmed', 'pending', 'rejected', 'unpaid'
  final String? paymentId;
  final double? amount;
  final PaymentModel? payment;

  _MemberPaymentInfo({required this.status, this.paymentId, this.amount, this.payment});
}
