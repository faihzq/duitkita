import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/payment_service.dart';

class BulkImportScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final double monthlyAmount;
  final DateTime groupCreatedAt;

  const BulkImportScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.monthlyAmount,
    required this.groupCreatedAt,
  });

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  int _currentStep = 0;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  // Step 1: Selected members
  final Set<String> _selectedMemberIds = {};

  // Step 2: Selected months (year-month key)
  final Set<String> _selectedMonths = {};

  // Loading state
  bool _isImporting = false;

  // Cache members for use across steps
  List<GroupMember> _members = [];

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.monthlyAmount.toStringAsFixed(2);
    _notesController.text = 'Bulk import';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Generate all months from Jan of previous year (or group creation, whichever is earlier) to now
  List<({int year, int month})> _getAllMonths() {
    final months = <({int year, int month})>[];
    final now = DateTime.now();
    final janLastYear = DateTime(now.year - 1, 1);
    final groupStart = DateTime(widget.groupCreatedAt.year, widget.groupCreatedAt.month);
    final start = janLastYear.isBefore(groupStart) ? janLastYear : groupStart;
    var current = start;

    while (current.year < now.year || (current.year == now.year && current.month <= now.month)) {
      months.add((year: current.year, month: current.month));
      current = DateTime(current.year, current.month + 1);
    }

    return months;
  }

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _monthKey(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

  Future<void> _doImport() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Import'),
        content: Text(
          'This will add ${_selectedMemberIds.length * _selectedMonths.length} payments '
          'totalling RM${(amount * _selectedMemberIds.length * _selectedMonths.length).toStringAsFixed(2)}.\n\n'
          'Duplicates will be skipped automatically.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isImporting = true);

    try {
      // Build entries list
      final entries = <({String userId, String userName, int month, int year})>[];
      for (final memberId in _selectedMemberIds) {
        final member = _members.firstWhere((m) => m.userId == memberId);
        for (final monthKey in _selectedMonths) {
          final parts = monthKey.split('-');
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          entries.add((userId: member.userId, userName: member.userName, month: month, year: year));
        }
      }

      final paymentService = ref.read(paymentServiceProvider);
      final added = await paymentService.addBulkPayments(
        groupId: widget.groupId,
        entries: entries,
        amount: amount,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (!mounted) return;
      setState(() => _isImporting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported $added payments!'),
          backgroundColor: AppTheme.success,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Bulk Import'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: membersAsync.when(
        data: (members) {
          _members = members;
          return _isImporting ? _buildImportingView() : _buildStepper(members);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildImportingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 24),
          const Text('Importing payments...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Please wait, this may take a moment', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  Widget _buildStepper(List<GroupMember> members) {
    return Stepper(
      currentStep: _currentStep,
      type: StepperType.horizontal,
      controlsBuilder: (context, details) {
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            children: [
              if (_currentStep < 2)
                ElevatedButton(
                  onPressed: _canContinue() ? details.onStepContinue : null,
                  child: const Text('Continue'),
                ),
              if (_currentStep == 2)
                ElevatedButton(
                  onPressed: _canImport() ? _doImport : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                  child: const Text('Import Payments'),
                ),
              if (_currentStep > 0) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
              ],
            ],
          ),
        );
      },
      onStepContinue: () {
        if (_currentStep < 2) setState(() => _currentStep++);
      },
      onStepCancel: () {
        if (_currentStep > 0) setState(() => _currentStep--);
      },
      steps: [
        Step(
          title: const Text('Members'),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          content: _buildMemberSelection(members),
        ),
        Step(
          title: const Text('Months'),
          isActive: _currentStep >= 1,
          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          content: _buildMonthSelection(),
        ),
        Step(
          title: const Text('Review'),
          isActive: _currentStep >= 2,
          state: StepState.indexed,
          content: _buildReview(),
        ),
      ],
    );
  }

  bool _canContinue() {
    if (_currentStep == 0) return _selectedMemberIds.isNotEmpty;
    if (_currentStep == 1) return _selectedMonths.isNotEmpty;
    return true;
  }

  bool _canImport() {
    return _selectedMemberIds.isNotEmpty &&
        _selectedMonths.isNotEmpty &&
        (double.tryParse(_amountController.text) ?? 0) > 0;
  }

  // ============================================================
  // STEP 1: Member Selection
  // ============================================================

  Widget _buildMemberSelection(List<GroupMember> members) {
    final allSelected = _selectedMemberIds.length == members.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select members to import payments for:',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),

        // Select All
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              CheckboxListTile(
                title: Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
                value: allSelected,
                activeColor: AppTheme.primary,
                onChanged: (_) {
                  setState(() {
                    if (allSelected) {
                      _selectedMemberIds.clear();
                    } else {
                      _selectedMemberIds.addAll(members.map((m) => m.userId));
                    }
                  });
                },
              ),
              const Divider(height: 1),
              ...members.map((member) => CheckboxListTile(
                title: Text(member.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: member.userEmail != null
                    ? Text(member.userEmail!, style: const TextStyle(fontSize: 12, color: AppTheme.textHint))
                    : null,
                secondary: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      member.userName.isNotEmpty ? member.userName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
                value: _selectedMemberIds.contains(member.userId),
                activeColor: AppTheme.primary,
                onChanged: (_) {
                  setState(() {
                    if (_selectedMemberIds.contains(member.userId)) {
                      _selectedMemberIds.remove(member.userId);
                    } else {
                      _selectedMemberIds.add(member.userId);
                    }
                  });
                },
              )),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Text(
          '${_selectedMemberIds.length} of ${members.length} selected',
          style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
        ),
      ],
    );
  }

  // ============================================================
  // STEP 2: Month Selection
  // ============================================================

  Widget _buildMonthSelection() {
    final allMonths = _getAllMonths();
    final allKeys = allMonths.map((m) => _monthKey(m.year, m.month)).toSet();
    final allSelected = _selectedMonths.length == allKeys.length;

    // Group by year
    final byYear = <int, List<({int year, int month})>>{};
    for (final m in allMonths) {
      byYear.putIfAbsent(m.year, () => []).add(m);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select months to mark as paid:',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),

        // Amount field
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.successGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(Icons.payments_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Amount per month', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        prefixText: 'RM ',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Select All / Deselect All
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() {
                if (allSelected) {
                  _selectedMonths.clear();
                } else {
                  _selectedMonths.addAll(allKeys);
                }
              }),
              icon: Icon(allSelected ? Icons.deselect : Icons.select_all, size: 18),
              label: Text(allSelected ? 'Deselect All' : 'Select All'),
            ),
            const Spacer(),
            Text(
              '${_selectedMonths.length} months',
              style: const TextStyle(fontSize: 12, color: AppTheme.textHint, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Month grid by year
        ...byYear.entries.map((yearEntry) {
          final year = yearEntry.key;
          final months = yearEntry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$year', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: months.map((m) {
                    final key = _monthKey(m.year, m.month);
                    final isSelected = _selectedMonths.contains(key);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedMonths.remove(key);
                          } else {
                            _selectedMonths.add(key);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 72,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppTheme.cardGradient : null,
                          color: isSelected ? null : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _monthNames[m.month - 1],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ============================================================
  // STEP 3: Review
  // ============================================================

  Widget _buildReview() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final totalPayments = _selectedMemberIds.length * _selectedMonths.length;
    final totalAmount = amount * totalPayments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Column(
            children: [
              _summaryRow(Icons.people_outline, 'Members', '${_selectedMemberIds.length}'),
              const SizedBox(height: 14),
              _summaryRow(Icons.calendar_month, 'Months', '${_selectedMonths.length}'),
              const SizedBox(height: 14),
              _summaryRow(Icons.receipt_long, 'Total Payments', '$totalPayments'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: Colors.white24),
              ),
              _summaryRow(Icons.payments, 'Amount per Payment', 'RM${amount.toStringAsFixed(2)}'),
              const SizedBox(height: 14),
              _summaryRow(Icons.account_balance_wallet, 'Total Amount', 'RM${totalAmount.toStringAsFixed(2)}',
                  bold: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Members list
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selected Members', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedMemberIds.map((id) {
                  final member = _members.firstWhere((m) => m.userId == id);
                  return Chip(
                    label: Text(member.userName, style: const TextStyle(fontSize: 12, color: Colors.white)),
                    backgroundColor: AppTheme.primary,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Months list
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selected Months', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (_selectedMonths.toList()..sort()).map((key) {
                  final parts = key.split('-');
                  final month = int.parse(parts[1]);
                  final year = parts[0];
                  return Chip(
                    label: Text('${_monthNames[month - 1]} $year',
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                    backgroundColor: AppTheme.primary,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Notes
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notes (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                decoration: AppTheme.styledInput(
                  label: 'Notes',
                  prefixIcon: Icons.note_outlined,
                  hint: 'e.g. Historical backfill',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
        ),
        Text(value, style: TextStyle(
          fontSize: bold ? 18 : 15,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          color: Colors.white,
        )),
      ],
    );
  }
}
