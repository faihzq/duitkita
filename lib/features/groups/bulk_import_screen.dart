import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/group_member.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/profile_service.dart';

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
  int _step = 0;
  final _amtCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Set<String> _selectedMembers = {};
  final Set<String> _selectedMonths = {};
  bool _importing = false;
  List<GroupMember> _members = [];

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    _amtCtrl.text = widget.monthlyAmount.toStringAsFixed(2);
    _notesCtrl.text = 'Bulk import';
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _monthKey(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

  List<({int year, int month})> _allMonths() {
    final months = <({int year, int month})>[];
    final now = DateTime.now();
    final janLastYear = DateTime(now.year - 1, 1);
    final groupStart = DateTime(widget.groupCreatedAt.year, widget.groupCreatedAt.month);
    final start = janLastYear.isBefore(groupStart) ? janLastYear : groupStart;
    var cur = start;
    while (cur.year < now.year || (cur.year == now.year && cur.month <= now.month)) {
      months.add((year: cur.year, month: cur.month));
      cur = DateTime(cur.year, cur.month + 1);
    }
    return months;
  }

  bool get _canNext {
    if (_step == 0) return _selectedMembers.isNotEmpty;
    if (_step == 1) return _selectedMonths.isNotEmpty;
    return true;
  }

  bool get _canImport => _selectedMembers.isNotEmpty && _selectedMonths.isNotEmpty && (double.tryParse(_amtCtrl.text) ?? 0) > 0;

  Future<void> _doImport() async {
    final amount = double.tryParse(_amtCtrl.text);
    if (amount == null || amount <= 0) {
      _snack('Please enter a valid amount', isError: true);
      return;
    }
    final total = _selectedMembers.length * _selectedMonths.length;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: DT.surface,
        child: Padding(
          padding: const EdgeInsets.all(DS.xl),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 40, height: 40, decoration: const BoxDecoration(color: DT.accentSoft, shape: BoxShape.circle), child: const Icon(Icons.upload_rounded, color: DT.accentDeep, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text('Confirm Import', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: DT.text))),
            ]),
            const SizedBox(height: 12),
            Text('This will add $total payments totalling RM${(amount * total).toStringAsFixed(2)}.\nDuplicates are skipped automatically.', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4)),
            const SizedBox(height: DS.xl),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: DT.accent, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Import Payments', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
            ),
            const SizedBox(height: 8),
            GestureDetector(onTap: () => Navigator.pop(ctx, false), child: Center(child: Text('Cancel', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: DT.textSecondary)))),
          ]),
        ),
      ),
    );

    if (ok != true || !mounted) return;
    setState(() => _importing = true);

    try {
      final entries = <({String userId, String userName, int month, int year})>[];
      for (final uid in _selectedMembers) {
        final member = _members.firstWhere((m) => m.userId == uid);
        for (final key in _selectedMonths) {
          final parts = key.split('-');
          entries.add((userId: uid, userName: member.userName, month: int.parse(parts[1]), year: int.parse(parts[0])));
        }
      }
      final added = await ref.read(paymentServiceProvider).addBulkPayments(
        groupId: widget.groupId,
        entries: entries,
        amount: amount,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      );
      if (!mounted) return;
      setState(() => _importing = false);
      _snack('Imported $added payments successfully');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      _snack('Import failed: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600)),
      backgroundColor: isError ? DT.danger : DT.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(DS.lg, 10, DS.lg, 0),
            child: Row(children: [
              _IconBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bulk Import', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.4)),
                Text(widget.groupName, style: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),

          // ── Step indicator ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(DS.lg, DS.md, DS.lg, 0),
            child: Row(children: List.generate(3, (i) {
              final labels = ['Members', 'Months', 'Review'];
              final done = i < _step;
              final active = i == _step;
              return Expanded(child: Row(children: [
                if (i > 0) Expanded(child: Container(height: 2, color: done ? DT.accent : DT.border)),
                Column(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: done || active ? DT.accent : DT.surface,
                      border: Border.all(color: done || active ? DT.accent : DT.border, width: 1.5),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: done
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text('${i + 1}', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: active ? Colors.white : DT.textTertiary))),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i], style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: active ? DT.text : DT.textSecondary)),
                ]),
                if (i < 2) Expanded(child: Container(height: 2, color: i < _step ? DT.accent : DT.border)),
              ]));
            })),
          ),

          // ── Step content ─────────────────────────────────────────
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (members) {
                _members = members;
                if (_importing) return _buildImporting();
                return Column(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(DS.lg, DS.md, DS.lg, DS.lg),
                      child: _step == 0 ? _buildMemberStep(members)
                           : _step == 1 ? _buildMonthStep()
                           : _buildReviewStep(),
                    ),
                  ),
                  // ── Bottom actions ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(DS.lg, 0, DS.lg, DS.lg),
                    child: Row(children: [
                      if (_step > 0) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _step--),
                            child: Container(height: 50, decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(14)), child: Center(child: Text('Back', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)))),
                          ),
                        ),
                        const SizedBox(width: DS.sm),
                      ],
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _step < 2 ? (_canNext ? () => setState(() => _step++) : null)
                                           : (_canImport ? _doImport : null),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: (_step < 2 ? _canNext : _canImport) ? DT.accent : DT.border,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(child: Text(
                              _step < 2 ? 'Continue' : 'Import Payments',
                              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            )),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildImporting() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(color: DT.accent, strokeWidth: 2.5),
      const SizedBox(height: DS.xl),
      Text('Importing payments…', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: DT.text)),
      const SizedBox(height: DS.sm),
      Text('Please wait', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary)),
    ]),
  );

  // ── Step 1: Members ────────────────────────────────────────────────────────

  Widget _buildMemberStep(List<GroupMember> members) {
    final allSelected = _selectedMembers.length == members.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Select members to import payments for', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary)),
      const SizedBox(height: DS.md),

      // Select all
      GestureDetector(
        onTap: () => setState(() => allSelected ? _selectedMembers.clear() : _selectedMembers.addAll(members.map((m) => m.userId))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: DS.md, vertical: 10),
          decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
          child: Row(children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(color: allSelected ? DT.accent : DT.bg, border: Border.all(color: allSelected ? DT.accent : DT.border, width: 1.5), borderRadius: BorderRadius.circular(6)), child: allSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null),
            const SizedBox(width: 10),
            Text(allSelected ? 'Deselect All' : 'Select All', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.accent)),
            const Spacer(),
            Text('${_selectedMembers.length}/${members.length}', style: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary)),
          ]),
        ),
      ),
      const SizedBox(height: DS.sm),

      ...members.map((m) {
        final selected = _selectedMembers.contains(m.userId);
        final initials = m.userName.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
        return GestureDetector(
          onTap: () => setState(() => selected ? _selectedMembers.remove(m.userId) : _selectedMembers.add(m.userId)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: DS.md, vertical: 10),
            decoration: BoxDecoration(color: selected ? DT.accentSoft : DT.surface, border: Border.all(color: selected ? DT.accent : DT.border, width: selected ? 1.5 : 1), borderRadius: BorderRadius.circular(DS.cardRadius)),
            child: Row(children: [
              _MemberAvatar(userId: m.userId, initials: initials, selected: selected),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.userName, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.text)),
                if (m.userEmail != null) Text(m.userEmail!, style: GoogleFonts.manrope(fontSize: 10, color: DT.textSecondary)),
              ])),
              Container(width: 22, height: 22, decoration: BoxDecoration(color: selected ? DT.accent : DT.bg, border: Border.all(color: selected ? DT.accent : DT.border, width: 1.5), borderRadius: BorderRadius.circular(6)), child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null),
            ]),
          ),
        );
      }),
    ]);
  }

  // ── Step 2: Months ─────────────────────────────────────────────────────────

  Widget _buildMonthStep() {
    final allMonths = _allMonths();
    final allKeys = allMonths.map((m) => _monthKey(m.year, m.month)).toSet();
    final allSelected = _selectedMonths.length == allKeys.length;

    final byYear = <int, List<({int year, int month})>>{};
    for (final m in allMonths) {
      byYear.putIfAbsent(m.year, () => []).add(m);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Amount field
      Container(
        padding: const EdgeInsets.all(DS.md),
        decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: DT.accentSoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.payments_outlined, color: DT.accentDeep, size: 18)),
          const SizedBox(width: DS.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Amount per month', style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            TextField(
              controller: _amtCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.text),
              decoration: InputDecoration(
                prefixText: 'RM ',
                prefixStyle: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.textSecondary),
                isDense: true, contentPadding: EdgeInsets.zero, filled: false, border: InputBorder.none,
                enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
              ),
            ),
          ])),
        ]),
      ),
      const SizedBox(height: DS.md),

      Row(children: [
        Text('Select months to mark as paid', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => allSelected ? _selectedMonths.clear() : _selectedMonths.addAll(allKeys)),
          child: Text(allSelected ? 'Deselect All' : 'Select All', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: DT.accent)),
        ),
      ]),
      const SizedBox(height: DS.sm),

      ...byYear.entries.map((yr) => Container(
        margin: const EdgeInsets.only(bottom: DS.sm),
        padding: const EdgeInsets.all(DS.md),
        decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${yr.key}', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: DT.text)),
          const SizedBox(height: DS.sm),
          Wrap(spacing: 8, runSpacing: 8, children: yr.value.map((m) {
            final key = _monthKey(m.year, m.month);
            final selected = _selectedMonths.contains(key);
            return GestureDetector(
              onTap: () => setState(() => selected ? _selectedMonths.remove(key) : _selectedMonths.add(key)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 62, padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? DT.accent : DT.bg,
                  border: Border.all(color: selected ? DT.accent : DT.border, width: selected ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(_monthNames[m.month - 1], style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : DT.textSecondary))),
              ),
            );
          }).toList()),
        ]),
      )),
    ]);
  }

  // ── Step 3: Review ─────────────────────────────────────────────────────────

  Widget _buildReviewStep() {
    final amount = double.tryParse(_amtCtrl.text) ?? 0;
    final totalPmt = _selectedMembers.length * _selectedMonths.length;
    final totalAmt = amount * totalPmt;

    return Column(children: [
      // Summary card
      Container(
        padding: const EdgeInsets.all(DS.xl),
        decoration: BoxDecoration(color: DT.primary, borderRadius: BorderRadius.circular(DS.cardRadius)),
        child: Column(children: [
          _summaryRow(Icons.people_outline, 'Members', '${_selectedMembers.length}'),
          const SizedBox(height: DS.md),
          _summaryRow(Icons.calendar_month, 'Months', '${_selectedMonths.length}'),
          const SizedBox(height: DS.md),
          _summaryRow(Icons.receipt_long, 'Total Payments', '$totalPmt'),
          Padding(padding: const EdgeInsets.symmetric(vertical: DS.md), child: Divider(color: Colors.white.withValues(alpha: 0.15))),
          _summaryRow(Icons.payments, 'Per Payment', 'RM${amount.toStringAsFixed(2)}'),
          const SizedBox(height: DS.md),
          _summaryRow(Icons.account_balance_wallet, 'Total Amount', 'RM${totalAmt.toStringAsFixed(2)}', bold: true),
        ]),
      ),
      const SizedBox(height: DS.md),

      // Selected members
      _ReviewSection(title: 'Selected Members', children: _selectedMembers.map((id) {
        final member = _members.firstWhere((m) => m.userId == id, orElse: () => GroupMember(userId: id, userName: id, isAdmin: false, joinedAt: DateTime.now(), totalPaid: 0, paymentCount: 0));
        return _ReviewChip(label: member.userName, color: DT.primary);
      }).toList()),
      const SizedBox(height: DS.sm),

      // Selected months
      _ReviewSection(title: 'Selected Months', children: (_selectedMonths.toList()..sort()).map((key) {
        final parts = key.split('-');
        return _ReviewChip(label: '${_monthNames[int.parse(parts[1]) - 1]} ${parts[0]}', color: DT.accent);
      }).toList()),
      const SizedBox(height: DS.sm),

      // Notes
      Container(
        padding: const EdgeInsets.all(DS.md),
        decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Notes (optional)', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.text)),
          const SizedBox(height: DS.sm),
          TextField(
            controller: _notesCtrl,
            style: GoogleFonts.manrope(fontSize: 13, color: DT.text),
            decoration: InputDecoration(
              hintText: 'e.g. Historical backfill',
              hintStyle: GoogleFonts.manrope(fontSize: 13, color: DT.textTertiary),
              prefixIcon: const Icon(Icons.note_outlined, size: 18, color: DT.textSecondary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true, fillColor: DT.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: DT.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: DT.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: DT.accent, width: 1.5)),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _summaryRow(IconData icon, String label, String value, {bool bold = false}) => Row(children: [
    Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.6)),
    const SizedBox(width: DS.md),
    Expanded(child: Text(label, style: GoogleFonts.manrope(fontSize: 13, color: Colors.white.withValues(alpha: 0.75)))),
    Text(value, style: GoogleFonts.manrope(fontSize: bold ? 17 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: Colors.white)),
  ]);
}

class _ReviewSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _ReviewSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(DS.md),
    decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.text)),
      const SizedBox(height: DS.sm),
      Wrap(spacing: 6, runSpacing: 6, children: children),
    ]),
  );
}

class _ReviewChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ReviewChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(DS.chipRadius)),
    child: Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
  );
}

class _MemberAvatar extends ConsumerWidget {
  final String userId;
  final String initials;
  final bool selected;
  const _MemberAvatar({required this.userId, required this.initials, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoUrl = ref.watch(userProfileStreamProvider(userId)).valueOrNull?.profileImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        width: 36, height: 36,
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.network(photoUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initials())
            : _initials(),
      ),
    );
  }

  Widget _initials() => Container(
    color: selected ? DT.accent : DT.primarySoft,
    child: Center(child: Text(
      initials.isNotEmpty ? initials : '?',
      style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : DT.primary),
    )),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 20, color: DT.text),
    ),
  );
}
