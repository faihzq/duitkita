import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

/// Bottom-sheet time picker in the app's own language — the Material dial
/// arrives with its own palette and reads as a different product.
///
/// Returns null when dismissed or cancelled.
Future<TimeOfDay?> showTripTimePicker({
  required BuildContext context,
  required TimeOfDay initial,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _TripTimePickerSheet(initial: initial),
  );
}

class _TripTimePickerSheet extends StatefulWidget {
  final TimeOfDay initial;
  const _TripTimePickerSheet({required this.initial});

  @override
  State<_TripTimePickerSheet> createState() => _TripTimePickerSheetState();
}

class _TripTimePickerSheetState extends State<_TripTimePickerSheet> {
  static const _itemExtent = 46.0;

  late int _hour; // 1..12
  late int _minute; // 0..59
  late bool _isAm;

  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hourOfPeriod == 0 ? 12 : widget.initial.hourOfPeriod;
    _minute = widget.initial.minute;
    _isAm = widget.initial.period == DayPeriod.am;

    _hourCtrl = FixedExtentScrollController(initialItem: _hour - 1);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  TimeOfDay get _value {
    // 12 AM is midnight (0), 12 PM is noon (12).
    final h = _hour == 12 ? 0 : _hour;
    return TimeOfDay(hour: _isAm ? h : h + 12, minute: _minute);
  }

  void _setPeriod(bool am) {
    if (am == _isAm) return;
    HapticFeedback.selectionClick();
    setState(() => _isAm = am);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DT.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: DT.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: DT.text,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'When does this stop start?',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: DT.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Live preview of the selection.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: DT.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    formatTimeOfDay(_value),
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: DT.accentDeep,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Wheels ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: SizedBox(
              height: _itemExtent * 5,
              child: Row(
                children: [
                  // The selection band is scoped to the wheels, so it stops
                  // short of the AM/PM toggle instead of running underneath it.
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: Container(
                            height: _itemExtent,
                            decoration: BoxDecoration(
                              color: DT.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: DT.border),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _Wheel(
                                controller: _hourCtrl,
                                count: 12,
                                itemExtent: _itemExtent,
                                label: (i) => '${i + 1}',
                                selected: _hour - 1,
                                onChanged: (i) => setState(() => _hour = i + 1),
                              ),
                            ),
                            Text(
                              ':',
                              style: GoogleFonts.manrope(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: DT.textTertiary,
                              ),
                            ),
                            Expanded(
                              child: _Wheel(
                                controller: _minuteCtrl,
                                count: 60,
                                itemExtent: _itemExtent,
                                label: (i) => i.toString().padLeft(2, '0'),
                                selected: _minute,
                                onChanged: (i) => setState(() => _minute = i),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // AM/PM reads better as a toggle than a two-item wheel.
                  SizedBox(
                    width: 68,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PeriodButton(
                          label: 'AM',
                          active: _isAm,
                          onTap: () => _setPeriod(true),
                        ),
                        const SizedBox(height: 8),
                        _PeriodButton(
                          label: 'PM',
                          active: !_isAm,
                          onTap: () => _setPeriod(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: DT.surface,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: DT.border),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: DT.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TripPrimaryButton(
                    label: 'Set time',
                    icon: Icons.check_rounded,
                    onTap: () => Navigator.of(context).pop(_value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wheel ────────────────────────────────────────────────────────────────────

class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int count;
  final double itemExtent;
  final String Function(int) label;
  final int selected;
  final ValueChanged<int> onChanged;

  const _Wheel({
    required this.controller,
    required this.count,
    required this.itemExtent,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemExtent,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.6,
      perspective: 0.003,
      overAndUnderCenterOpacity: 0.35,
      onSelectedItemChanged: (i) {
        HapticFeedback.selectionClick();
        onChanged(i);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder:
            (_, i) => Center(
              child: Text(
                label(i),
                style: GoogleFonts.manrope(
                  fontSize: i == selected ? 24 : 20,
                  fontWeight: i == selected ? FontWeight.w800 : FontWeight.w600,
                  color: i == selected ? DT.text : DT.textSecondary,
                  letterSpacing: -0.4,
                ),
              ),
            ),
      ),
    );
  }
}

// ─── AM/PM ────────────────────────────────────────────────────────────────────

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        width: double.infinity,
        decoration: BoxDecoration(
          color: active ? DT.text : DT.surface,
          borderRadius: BorderRadius.circular(12),
          border: active ? null : Border.all(color: DT.border),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : DT.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
