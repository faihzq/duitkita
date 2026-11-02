// ============================================================================
// Group Detail redesign — drop-in Flutter widgets
// Paste these into lib/features/groups/group_detail_screen.dart
// Uses your existing DT / DS tokens and GoogleFonts.manrope.
// ============================================================================
//
// INTEGRATION (in _GroupDetailScreenState.build):
//
//   1. Replace the "Group hero" Row + the "Stats card" Container with a single:
//        _CollectionHero(
//          group: group,
//          paidCount: paidCount,
//          selectedMonth: _selectedMonth,
//          selectedYear: _selectedYear,
//          onPrevMonth: _prevMonth,
//          onNextMonth: _nextMonth,
//          onPickMonth: _showMonthPicker,
//        )
//      (Keep the header bar with back/share/settings above it as-is.)
//
//   2. Replace `_TabBar(...)` with `_SegmentedTabs(...)` (same props).
//
//   3. In _MembersTab, above the member list, drop in `_StatusStrip(members, statusMap)`.
//
//   4. In _MemberCard, wrap the avatar in `_AvatarWithDot(status: status, ...)`
//      (snippet at the bottom) to get the colored status dot.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';

const _kMonths = ['January','February','March','April','May','June',
  'July','August','September','October','November','December'];

// ─── 1. Collection hero (gradient card) ─────────────────────────────────────
class _CollectionHero extends StatelessWidget {
  final dynamic group;              // needs .name .description .monthlyAmount .memberCount
  final int paidCount;
  final int selectedMonth;          // 1-12
  final int selectedYear;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPickMonth;

  const _CollectionHero({
    required this.group,
    required this.paidCount,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onPickMonth,
  });

  @override
  Widget build(BuildContext context) {
    final double monthly = (group.monthlyAmount as num).toDouble();
    final int members = group.memberCount as int;
    final bool hasFund = monthly > 0;
    final double perMember = hasFund ? monthly / members : 0;
    final double collected = perMember * paidCount;
    final double pct = members > 0 ? (paidCount / members).clamp(0.0, 1.0) : 0.0;
    final int awaiting = members - paidCount;
    const white = Colors.white;
    final white70 = Colors.white.withValues(alpha: 0.70);
    final white55 = Colors.white.withValues(alpha: 0.55);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [DT.headerGradientStart, DT.headerGradientEnd],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: DT.text.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + month stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(hasFund ? 'COLLECTED THIS MONTH' : 'TRIP FUND',
                style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: white55, letterSpacing: 0.5)),
              Container(
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(onTap: onPrevMonth, child: Icon(Icons.chevron_left_rounded, size: 18, color: white70)),
                  GestureDetector(onTap: onPickMonth, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('${_kMonths[selectedMonth - 1].substring(0, 3)} $selectedYear',
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: white)),
                  )),
                  GestureDetector(onTap: onNextMonth, child: Icon(Icons.chevron_right_rounded, size: 18, color: white70)),
                ]),
              ),
            ],
          ),

          if (hasFund) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('RM${collected.toStringAsFixed(0)}',
                style: GoogleFonts.manrope(fontSize: 36, fontWeight: FontWeight.w800, color: white, letterSpacing: -1, height: 1)),
              const SizedBox(width: 8),
              Text('of RM${monthly.toStringAsFixed(0)}',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: white70)),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: pct, minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                valueColor: const AlwaysStoppedAnimation<Color>(DT.accent)),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              RichText(text: TextSpan(children: [
                TextSpan(text: '${(pct * 100).round()}% ', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: DT.accent)),
                TextSpan(text: 'collected', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: white70)),
              ])),
              Text('$paidCount of $members paid', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: white70)),
            ]),
          ] else ...[
            const SizedBox(height: 10),
            Text('No fixed amount — costs are split between $members members as they come up.',
              style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.82), height: 1.4)),
          ],

          const SizedBox(height: 16),
          Container(margin: const EdgeInsets.only(top: 0), padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12)))),
            child: Row(children: [
              _heroStat('PER MEMBER', hasFund ? 'RM${perMember.toStringAsFixed(0)}' : '—', CrossAxisAlignment.start),
              _heroDivider(),
              _heroStat('MEMBERS', '$members', CrossAxisAlignment.center),
              _heroDivider(),
              _heroStat('AWAITING', hasFund ? '$awaiting' : '—', CrossAxisAlignment.center),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() => Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.12));

  Widget _heroStat(String label, String value, CrossAxisAlignment align) => Expanded(
    child: Column(crossAxisAlignment: align, children: [
      Text(value, style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
      const SizedBox(height: 3),
      Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.55), letterSpacing: 0.4)),
    ]),
  );
}

// ─── 2. Segmented tab control ───────────────────────────────────────────────
class _SegmentedTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final void Function(int) onTap;
  const _SegmentedTabs({required this.tabs, required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: DT.surfaceAlt, borderRadius: BorderRadius.circular(13), border: Border.all(color: DT.border)),
    child: Row(children: tabs.asMap().entries.map((e) {
      final active = e.key == selectedIndex;
      return Expanded(child: GestureDetector(
        onTap: () => onTap(e.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? DT.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active ? [BoxShadow(color: DT.text.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Center(child: Text(e.value,
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: active ? DT.text : DT.textSecondary))),
        ),
      ));
    }).toList()),
  );
}

// ─── 3. Paid / Pending / Unpaid strip (goes atop the member list) ───────────
class _StatusStrip extends StatelessWidget {
  final int paid, pending, unpaid;
  const _StatusStrip({required this.paid, required this.pending, required this.unpaid});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      _tile('Paid', paid, DT.success, DT.successSoft),
      const SizedBox(width: 8),
      _tile('Pending', pending, DT.warning, DT.warningSoft),
      const SizedBox(width: 8),
      _tile('Unpaid', unpaid, DT.danger, DT.dangerSoft),
    ]),
  );

  Widget _tile(String label, int value, Color fg, Color bg) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text('$value', style: GoogleFonts.manrope(fontSize: 19, fontWeight: FontWeight.w800, color: fg, height: 1)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: DT.text.withValues(alpha: 0.7), letterSpacing: 0.4)),
      ]),
    ),
  );
}

// ─── 4. Status dot to overlay on the member avatar ─────────────────────────
// In _MemberCard, replace `_Avatar40(...)` with this Stack:
//
//   Stack(clipBehavior: Clip.none, children: [
//     _Avatar40(name: member.userName, userId: member.userId),
//     Positioned(right: -2, bottom: -2, child: _statusDot(status)),
//   ])
//
Widget _statusDot(String status) {
  final color = switch (status) {
    'confirmed' => DT.success,
    'pending'   => DT.warning,
    'rejected'  => DT.danger,
    _           => DT.danger, // unpaid
  };
  return Container(
    width: 13, height: 13,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: DT.surface, width: 2)),
  );
}
