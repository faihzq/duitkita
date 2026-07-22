import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/expense_model.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/screens/add_expense_screen.dart';
import 'package:duitkita/screens/expense_detail_screen.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  const ExpenseListScreen({super.key, required this.groupId, required this.groupName});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  ExpenseStatus? _filter;
  int? _year;
  bool _selectionMode = false;
  final Set<String> _selected = {};
  bool _busy = false;

  Future<void> _delete(ExpenseModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: DT.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: DT.dangerSoft, shape: BoxShape.circle), child: const Icon(Icons.delete_outline_rounded, color: DT.danger, size: 26)),
            const SizedBox(height: 14),
            Text('Delete expense?', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.text)),
            const SizedBox(height: 8),
            Text('"${e.title}" (RM${e.amount.toStringAsFixed(2)}) will be permanently removed.',
              textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('Cancel', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.textSecondary)))),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: DT.danger, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('Delete', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
              )),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try { await ref.read(expenseServiceProvider).deleteExpense(e.id); } catch (_) {}
  }

  void _pick(String id) => setState(() {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    if (_selected.isEmpty) _selectionMode = false;
  });

  void _selectAll(List<ExpenseModel> all) {
    final pending = all.where((e) => e.status == ExpenseStatus.pending).map((e) => e.id).toSet();
    setState(() {
      if (_selected.length == pending.length && _selected.containsAll(pending)) {
        _selected.clear(); _selectionMode = false;
      } else {
        _selected..clear()..addAll(pending);
      }
    });
  }

  void _exitSelect() => setState(() { _selectionMode = false; _selected.clear(); });

  Future<void> _batchOp(bool approve) async {
    if (_selected.isEmpty) return;
    final uid = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final profile = await ref.read(profileServiceProvider).getUserProfile(uid);
      final svc = ref.read(expenseServiceProvider);
      final name = profile?.name ?? 'Admin';
      if (approve) {
        await svc.batchApproveExpenses(expenseIds: _selected.toList(), approvedBy: uid, approvedByName: name);
      } else {
        await svc.batchRejectExpenses(expenseIds: _selected.toList(), rejectedBy: uid, rejectedByName: name);
      }
      if (mounted) _exitSelect();
    } catch (_) {} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(groupExpensesStreamProvider(widget.groupId));
    final uid = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));
    final isAdmin = membersAsync.valueOrNull?.any((m) => m.userId == uid && m.isAdmin) ?? false;

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(children: [
                _IconBtn(icon: Icons.arrow_back_rounded, onTap: _selectionMode ? _exitSelect : () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  _selectionMode ? '${_selected.length} selected' : 'Group Expenses',
                  style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.4),
                )),
                if (!_selectionMode)
                  expensesAsync.maybeWhen(
                    data: (all) {
                      final years = all.map((e) => e.createdAt.year).toSet().toList()..sort((a, b) => b.compareTo(a));
                      if (years.isEmpty) return const SizedBox.shrink();
                      return PopupMenuButton<int?>(
                        onSelected: (y) => setState(() => _year = y),
                        itemBuilder: (_) => [
                          PopupMenuItem<int?>(value: null, child: Text('All years', style: GoogleFonts.manrope(fontWeight: _year == null ? FontWeight.w700 : FontWeight.w500, color: _year == null ? DT.primary : DT.text))),
                          ...years.map((y) => PopupMenuItem<int?>(value: y, child: Text('$y', style: GoogleFonts.manrope(fontWeight: _year == y ? FontWeight.w700 : FontWeight.w500, color: _year == y ? DT.primary : DT.text)))),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: DT.border)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(_year?.toString() ?? 'Year', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: DT.text)),
                            const Icon(Icons.arrow_drop_down, size: 18, color: DT.textSecondary),
                          ]),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Filter chips ────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(label: 'All', active: _filter == null, onTap: () => setState(() { _filter = null; _exitSelect(); })),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Pending', active: _filter == ExpenseStatus.pending, activeColor: DT.warning, onTap: () => setState(() { _filter = ExpenseStatus.pending; _exitSelect(); })),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Approved', active: _filter == ExpenseStatus.approved, activeColor: DT.success, onTap: () => setState(() { _filter = ExpenseStatus.approved; _exitSelect(); })),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Rejected', active: _filter == ExpenseStatus.rejected, activeColor: DT.danger, onTap: () => setState(() { _filter = ExpenseStatus.rejected; _exitSelect(); })),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Selection bar ───────────────────────────────────
            if (_selectionMode && _selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: DT.primarySoft,
                    borderRadius: BorderRadius.circular(DS.cardRadius),
                    border: Border.all(color: DT.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 16, color: DT.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${_selected.length} selected', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.primary))),
                    GestureDetector(
                      onTap: () { if (expensesAsync.hasValue) _selectAll(expensesAsync.value!); },
                      child: Text('Select all', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: DT.primary)),
                    ),
                  ]),
                ),
              ),

            // ── Main content ────────────────────────────────────
            Expanded(
              child: expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
                error: (e, _) => Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $e', style: GoogleFonts.manrope(color: DT.danger), textAlign: TextAlign.center),
                )),
                data: (all) {
                  var list = _filter == null ? all.toList() : all.where((e) => e.status == _filter).toList();
                  if (_year != null) list = list.where((e) => e.createdAt.year == _year).toList();
                  _selected.removeWhere((id) => !all.any((e) => e.id == id));

                  final approvedTotal = all.where((e) => e.status == ExpenseStatus.approved).fold(0.0, (s, e) => s + e.amount);
                  final pendingTotal  = all.where((e) => e.status == ExpenseStatus.pending).fold(0.0, (s, e) => s + e.amount);
                  final rejectedTotal = all.where((e) => e.status == ExpenseStatus.rejected).fold(0.0, (s, e) => s + e.amount);

                  if (list.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      children: [
                        _SummaryCard(approved: approvedTotal, pending: pendingTotal, rejected: rejectedTotal, total: all.length),
                        const SizedBox(height: 48),
                        _EmptyState(isFiltered: _filter != null),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: list.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _SummaryCard(approved: approvedTotal, pending: pendingTotal, rejected: rejectedTotal, total: all.length);
                      }
                      final e = list[i - 1];
                      final isPending = e.status == ExpenseStatus.pending;

                      if (_selectionMode && isPending) {
                        return _SelectableCard(
                          expense: e,
                          selected: _selected.contains(e.id),
                          onTap: () => _pick(e.id),
                        );
                      }

                      if (!isAdmin) {
                        return _ExpenseCard(expense: e, onTap: () => _openDetail(e));
                      }

                      return Dismissible(
                        key: ValueKey(e.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async { await _delete(e); return false; },
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: DT.danger, borderRadius: BorderRadius.circular(DS.cardRadius)),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        ),
                        child: _ExpenseCard(
                          expense: e,
                          onTap: () => _openDetail(e),
                          onLongPress: isPending ? () => setState(() { _selectionMode = true; _selected.add(e.id); }) : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectionMode ? null : FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(AppTheme.slideRoute(AddExpenseScreen(groupId: widget.groupId))),
        backgroundColor: DT.text,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('New expense', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: (_selectionMode && _selected.isNotEmpty) ? SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(color: DT.surface, border: Border(top: BorderSide(color: DT.border))),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: _busy ? null : () => _batchOp(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(border: Border.all(color: DT.danger.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('Reject (${_selected.length})', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.danger))),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: _busy ? null : () => _batchOp(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(color: DT.success, borderRadius: BorderRadius.circular(12)),
                child: Center(child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Approve (${_selected.length})', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            )),
          ]),
        ),
      ) : null,
    );
  }

  void _openDetail(ExpenseModel e) {
    Navigator.of(context).push(AppTheme.slideRoute(ExpenseDetailScreen(expense: e, groupId: widget.groupId)));
  }
}

// ─── Summary card (navy hero) ─────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double approved;
  final double pending;
  final double rejected;
  final int total;
  const _SummaryCard({required this.approved, required this.pending, required this.rejected, required this.total});

  @override
  Widget build(BuildContext context) {
    final grand = approved + pending + rejected;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(DS.xl),
      decoration: BoxDecoration(
        color: DT.primary,
        borderRadius: BorderRadius.circular(DS.heroRadius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TOTAL EXPENSES', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: DT.accent, letterSpacing: 1.0)),
            const SizedBox(height: 4),
            Text('RM${grand.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('$total items', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7))),
          ),
        ]),
        const SizedBox(height: 16),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(children: [
            _HeroStatCell(label: 'Approved', value: 'RM${approved.toStringAsFixed(0)}', color: DT.accent),
            Container(width: 1, color: Colors.white.withValues(alpha: 0.15)),
            _HeroStatCell(label: 'Pending', value: 'RM${pending.toStringAsFixed(0)}', color: DT.warning),
            Container(width: 1, color: Colors.white.withValues(alpha: 0.15)),
            _HeroStatCell(label: 'Rejected', value: 'RM${rejected.toStringAsFixed(0)}', color: DT.danger),
          ]),
        ),
      ]),
    );
  }
}

class _HeroStatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _HeroStatCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(children: [
        Text(value, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.55))),
      ]),
    ),
  );
}

// ─── Expense card (Revolut-style left-border strip) ───────────────────────────

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ExpenseCard({required this.expense, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (expense.status) {
      ExpenseStatus.approved => DT.success,
      ExpenseStatus.pending  => DT.warning,
      ExpenseStatus.rejected => DT.danger,
    };
    final statusLabel = expense.status.name[0].toUpperCase() + expense.status.name.substring(1);
    final dateStr = '${expense.createdAt.day}/${expense.createdAt.month}/${expense.createdAt.year}';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(DS.cardRadius),
          border: Border.all(color: DT.border),
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            // Status accent strip
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(DS.cardRadius), bottomLeft: Radius.circular(DS.cardRadius)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: DT.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.receipt_long_outlined, size: 17, color: DT.textSecondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(expense.title, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text(expense.requestedByName, style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary, fontWeight: FontWeight.w500)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Container(width: 3, height: 3, decoration: const BoxDecoration(color: DT.textTertiary, shape: BoxShape.circle)),
                      ),
                      Text(dateStr, style: GoogleFonts.manrope(fontSize: 11, color: DT.textTertiary)),
                    ]),
                  ])),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('RM${expense.amount.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.3)),
                    const SizedBox(height: 5),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(statusLabel, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                    ]),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Selectable card (selection mode) ────────────────────────────────────────

class _SelectableCard extends StatelessWidget {
  final ExpenseModel expense;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableCard({required this.expense, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? DT.primarySoft : DT.surface,
        borderRadius: BorderRadius.circular(DS.cardRadius),
        border: Border.all(color: selected ? DT.primary.withValues(alpha: 0.35) : DT.border, width: selected ? 1.5 : 1),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: selected ? DT.accent : DT.warning,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(DS.cardRadius), bottomLeft: Radius.circular(DS.cardRadius)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: selected ? DT.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: selected ? DT.primary : DT.borderStrong, width: 2),
                  ),
                  child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                ),
                const SizedBox(width: 10),
                Container(width: 36, height: 36, decoration: BoxDecoration(color: DT.warningSoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.hourglass_top_rounded, size: 17, color: DT.warning)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(expense.title, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(expense.requestedByName, style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary)),
                ])),
                Text('RM${expense.amount.toStringAsFixed(2)}', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: DT.text)),
              ]),
            ),
          ),
        ]),
      ),
    ),
  );
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  const _EmptyState({required this.isFiltered});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 72, height: 72,
      decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: DT.border)),
      child: const Icon(Icons.receipt_long_outlined, size: 32, color: DT.textTertiary),
    ),
    const SizedBox(height: 16),
    Text(
      isFiltered ? 'No expenses match this filter' : 'No expenses yet',
      style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: DT.text),
    ),
    const SizedBox(height: 6),
    Text(
      isFiltered ? 'Try a different filter above' : 'Submit an expense request to get started',
      style: GoogleFonts.manrope(fontSize: 13, color: DT.textTertiary),
      textAlign: TextAlign.center,
    ),
  ]);
}

// ─── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? DT.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : DT.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? color.withValues(alpha: 0.4) : DT.border),
        ),
        child: Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: active ? color : DT.textSecondary)),
      ),
    );
  }
}

// ─── Icon button ─────────────────────────────────────────────────────────────

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
