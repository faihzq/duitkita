// ═══════════════════════════════════════════════════════════════════════════
// HOME "FOCUS" REDESIGN — annotated Flutter snippets
//
// These are drop-in replacements / edits for the widgets that already live in
//   lib/features/home/home_screen.dart
//
// Only THREE widgets change: _HeroCard, _UpNextSection/_UpNextCard, and
// _BreakdownCard. Everything else (greeting, notifications, admin pending,
// insights sheet, bottom nav) stays exactly as it is today.
//
// Requires: lib/features/home/hero_ring.dart  (see hero_ring.dart in this folder)
//   import 'package:duitkita/features/home/hero_ring.dart';
// ═══════════════════════════════════════════════════════════════════════════


// ────────────────────────────────────────────────────────────────────────────
// CHANGE 1 — _HeroCard
//
// WHAT CHANGES
//   • Label  "MONTHLY COMMITMENTS · MAY"  →  "LEFT TO PAY · MAY"
//   • The big number is now `remaining`, not `totalMonthly`.
//   • Linear progress bar  →  circular HeroRing showing % cleared.
//   • Quick actions move INSIDE the hero as translucent chips (see CHANGE 1b).
//
// Replace the body of _HeroCard.build's inner Column (the part after the
// decorative glow Positioned) with this structure.
// ────────────────────────────────────────────────────────────────────────────

Widget buildHeroFocus({
  required double totalMonthly,
  required double paidThisMonth,
  required double remaining,
  required double progressPct,
  required String monthUpper,          // e.g. 'MAY'
  required Widget quickActionsOnDark,  // the chip row — CHANGE 1b
}) {
  final pct = (progressPct * 100).round();
  final onTrack = progressPct >= 0.4;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Label + status pill
      Row(
        children: [
          Expanded(
            child: Text(
              'LEFT TO PAY · $monthUpper',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (totalMonthly > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(onTrack ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 12, color: onTrack ? DT.accent : DT.warning),
                const SizedBox(width: 4),
                Text(onTrack ? 'On track' : 'Catch up',
                    style: GoogleFonts.manrope(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: onTrack ? DT.accent : DT.warning)),
              ]),
            ),
        ],
      ),

      if (totalMonthly > 0) ...[
        const SizedBox(height: 14),
        // Ring + amount
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 128,
              height: 128,
              child: AnimatedHeroRing(  // from hero_ring.dart
                pct: progressPct,
                center: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$pct%',
                      style: GoogleFonts.manrope(
                          fontSize: 27, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: -0.8, height: 1)),
                  const SizedBox(height: 3),
                  Text('CLEARED',
                      style: GoogleFonts.manrope(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 0.4)),
                ]),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RM ${_fmt(remaining, decimals: 0)}',
                      style: GoogleFonts.manrope(
                          fontSize: 37, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: -1.4, height: 1)),
                  const SizedBox(height: 9),
                  Text.rich(
                    TextSpan(
                      style: GoogleFonts.manrope(
                          fontSize: 12.5, height: 1.55,
                          color: Colors.white.withValues(alpha: 0.78)),
                      children: [
                        TextSpan(text: 'of RM ${_fmt(totalMonthly, decimals: 0)} due this month\n'),
                        TextSpan(
                          text: 'RM ${_fmt(paidThisMonth, decimals: 0)} paid',
                          style: GoogleFonts.manrope(
                              fontSize: 12.5, fontWeight: FontWeight.w700, color: DT.accent),
                        ),
                        const TextSpan(text: ' so far'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        quickActionsOnDark, // CHANGE 1b
      ],
    ],
  );
}


// ────────────────────────────────────────────────────────────────────────────
// CHANGE 1b — Quick actions move inside the hero as translucent chips.
//
// In HomeScreen.build, DELETE the standalone quick-actions Padding block, and
// pass this row into buildHeroFocus(quickActionsOnDark: ...).
//
// Give the existing _ActionTile an `onDark` flag OR use this dedicated chip.
// Your real 4 actions: Add expense, Trips, New group, Insights.
// ────────────────────────────────────────────────────────────────────────────

Widget quickActionsOnDarkRow(List<_Action> actions) {
  return Row(
    children: [
      for (int i = 0; i < actions.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: _HeroChip(action: actions[i])),
      ],
    ],
  );
}

class _HeroChip extends StatelessWidget {
  final _Action action;
  const _HeroChip({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 11, 6, 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(action.icon, size: 19, color: Colors.white),
          const SizedBox(height: 6),
          Text(action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                  fontSize: 10.5, fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92),
                  letterSpacing: -0.1)),
        ]),
      ),
    );
  }
}


// ────────────────────────────────────────────────────────────────────────────
// CHANGE 2 — _UpNextSection / _UpNextCard
//
// WHAT CHANGES
//   • Section header gets a count pill:  "3 to pay"  (warningSoft/warning).
//   • The FIRST item gets emphasis: warning border, a "DUE SOON" chip, and a
//     warning-colored Pay button. All other cards are unchanged.
//
// 2a — header action pill. Pass to _SectionHeader(action: upNextCountPill(n)):
// ────────────────────────────────────────────────────────────────────────────

Widget upNextCountPill(int count) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: DT.warningSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.schedule_rounded, size: 13, color: DT.warning),
        const SizedBox(width: 5),
        Text('$count to pay',
            style: GoogleFonts.manrope(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: DT.warning)),
      ]),
    );

// 2b — in _UpNextItemData add `final bool soon;` (default false) and set
// soon: true on the FIRST item you build in _UpNextSection:
//
//   items.add(_UpNextItemData(..., soon: items.isEmpty));  // first one only
//
// 2c — in _UpNextCard.build, make the border, title chip, and Pay button
// react to item.soon:

BoxDecoration upNextCardDecoration(bool soon) => BoxDecoration(
      color: DT.surface,
      borderRadius: BorderRadius.circular(DS.cardRadius),
      border: Border.all(color: soon ? DT.warning.withValues(alpha: 0.33) : DT.border),
      boxShadow: soon
          ? [BoxShadow(color: DT.warning.withValues(alpha: 0.13),
              blurRadius: 26, offset: const Offset(0, 10))]
          : null,
    );

// Title row — add the chip when soon:
//   Row(children: [
//     Flexible(child: Text(item.title, overflow: TextOverflow.ellipsis, ...)),
//     if (item.soon) ...[
//       const SizedBox(width: 7),
//       Container(
//         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//         decoration: BoxDecoration(color: DT.warningSoft, borderRadius: BorderRadius.circular(5)),
//         child: Text('DUE SOON', style: GoogleFonts.manrope(
//           fontSize: 9, fontWeight: FontWeight.w800, color: DT.warning, letterSpacing: 0.3)),
//       ),
//     ],
//   ])
//
// Pay button color — swap the `DT.text` fill for DT.warning when item.soon:
//   color: item.soon ? DT.warning : DT.text,


// ────────────────────────────────────────────────────────────────────────────
// CHANGE 3 — _BreakdownCard
//
// WHAT CHANGES
//   • A thin segmented bar sits ABOVE the existing rows, one segment per
//     category weighted by its monthly amount. Rows below are unchanged.
//
// Insert this as the first child of the card's inner Column, before the
// _BreakdownRow list:
// ────────────────────────────────────────────────────────────────────────────

Widget breakdownSegmentBar({
  required double groupMonthly,
  required double debtMonthly,
  required double billMonthly,
}) {
  final segs = [
    if (groupMonthly > 0) (DT.catGroups, groupMonthly),
    if (debtMonthly > 0) (DT.catDebts, debtMonthly),
    if (billMonthly > 0) (DT.catBills, billMonthly),
  ];
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(children: [
          for (int i = 0; i < segs.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              flex: (segs[i].$2 * 100).round(),
              child: Container(color: segs[i].$1),
            ),
          ],
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared helpers referenced above (already exist in home_screen.dart):
//   _fmt(double, {int decimals})   — thousands-separated formatter
//   _Action                        — quick-action model (icon,label,bg,fg,onTap)
//   GoogleFonts.manrope, DT.*, DS.*
// ═══════════════════════════════════════════════════════════════════════════
