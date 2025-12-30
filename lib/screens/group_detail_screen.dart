import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/screens/add_payment_screen.dart';
import 'package:duitkita/screens/payment_history_screen.dart';
import 'package:duitkita/screens/manage_members_screen.dart';
import 'package:duitkita/utils/utils.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  Future<Map<String, bool>> _getMonthlyPaymentStatus(
    List<GroupMember> members,
  ) async {
    final paymentService = ref.read(paymentServiceProvider);
    final Map<String, bool> paymentStatus = {};

    for (var member in members) {
      final hasPaid = await paymentService.hasUserPaidForMonth(
        groupId: widget.groupId,
        userId: member.userId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      paymentStatus[member.userId] = hasPaid;
    }

    return paymentStatus;
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              final group = groupAsync.value;
              if (group != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => ManageMembersScreen(
                          groupId: widget.groupId,
                          groupName: group.name,
                        ),
                  ),
                );
              }
            },
            tooltip: 'Manage Members',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) =>
                          PaymentHistoryScreen(groupId: widget.groupId),
                ),
              );
            },
            tooltip: 'Payment History',
          ),
        ],
      ),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        group.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.people,
                            '${group.memberCount} Members',
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            Icons.attach_money,
                            'RM${group.monthlyAmount.toStringAsFixed(2)}/month',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Month Selector
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Payment Status',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            if (_selectedMonth == 1) {
                              _selectedMonth = 12;
                              _selectedYear--;
                            } else {
                              _selectedMonth--;
                            }
                          });
                        },
                      ),
                      Text(
                        '${_getMonthName(_selectedMonth)} $_selectedYear',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            if (_selectedMonth == 12) {
                              _selectedMonth = 1;
                              _selectedYear++;
                            } else {
                              _selectedMonth++;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Members List with Payment Status
                membersAsync.when(
                  data: (members) {
                    return FutureBuilder<Map<String, bool>>(
                      future: _getMonthlyPaymentStatus(members),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final paymentStatus = snapshot.data!;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final hasPaid =
                                paymentStatus[member.userId] ?? false;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      hasPaid
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                  child: Icon(
                                    hasPaid ? Icons.check_circle : Icons.cancel,
                                    color:
                                        hasPaid
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(member.userName),
                                    if (member.isAdmin) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      hasPaid ? 'Paid' : 'Not paid',
                                      style: TextStyle(
                                        color:
                                            hasPaid
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: RM${member.totalPaid.toStringAsFixed(2)} (${member.paymentCount} payments)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing:
                                    member.userId == userId && !hasPaid
                                        ? IconButton(
                                          icon: const Icon(Icons.add_circle),
                                          color: Colors.blue,
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder:
                                                    (
                                                      context,
                                                    ) => AddPaymentScreen(
                                                      groupId: widget.groupId,
                                                      monthlyAmount:
                                                          group.monthlyAmount,
                                                      selectedMonth:
                                                          _selectedMonth,
                                                      selectedYear:
                                                          _selectedYear,
                                                    ),
                                              ),
                                            );
                                          },
                                        )
                                        : null,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (error, stack) =>
                          Center(child: Text('Error loading members: $error')),
                ),

                const SizedBox(height: 80),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) =>
                Center(child: Text('Error loading group: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final group = groupAsync.value;
          if (group != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (context) => AddPaymentScreen(
                      groupId: widget.groupId,
                      monthlyAmount: group.monthlyAmount,
                      selectedMonth: _selectedMonth,
                      selectedYear: _selectedYear,
                    ),
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Payment'),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
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
    return months[month - 1];
  }
}
