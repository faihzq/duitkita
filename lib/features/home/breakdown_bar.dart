import 'package:flutter/material.dart';
import 'package:duitkita/config/design_tokens.dart';

/// Thin segmented bar for the Home "Where your money goes" card — one segment
/// per category, widths weighted by monthly amount.
///
/// Renders nothing when no category has a monthly commitment.
class BreakdownSegmentBar extends StatelessWidget {
  final double groupMonthly;
  final double debtMonthly;
  final double billMonthly;
  final double height;

  const BreakdownSegmentBar({
    super.key,
    required this.groupMonthly,
    required this.debtMonthly,
    required this.billMonthly,
    this.height = 12,
  });

  /// Colour/amount pairs for the categories that carry a commitment.
  List<(Color, double)> get segments => [
    if (groupMonthly > 0) (DT.catGroups, groupMonthly),
    if (debtMonthly > 0) (DT.catDebts, debtMonthly),
    if (billMonthly > 0) (DT.catBills, billMonthly),
  ];

  @override
  Widget build(BuildContext context) {
    final segs = segments;
    if (segs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: height,
          child: Row(
            // Stretch, so each segment is given a tight height. A childless
            // ColoredBox takes constraints.smallest, and the default centre
            // alignment leaves the cross axis loose — which collapses every
            // segment to zero height and the bar disappears.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < segs.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  // Flex must be a positive int, so a tiny amount still rounds
                  // to 1 rather than collapsing the segment.
                  flex: (segs[i].$2 * 100).round().clamp(1, 1 << 30),
                  child: ColoredBox(color: segs[i].$1),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
