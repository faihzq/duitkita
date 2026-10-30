import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/makan_spot.dart';
import 'package:duitkita/features/makan/makan_hours.dart';
import 'package:duitkita/features/makan/makan_widgets.dart';
import 'package:duitkita/features/trips/trip_time_picker.dart';

/// Edits a week of opening hours.
///
/// Most warung keep the same hours every day they open, so the default is one
/// set of slots plus the days it applies to ("closed Mondays" is just an
/// unticked day). "Varies by day" switches to a slot list per weekday.
class MakanHoursEditor extends StatefulWidget {
  final WeeklyHours initial;
  final ValueChanged<WeeklyHours> onChanged;

  const MakanHoursEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<MakanHoursEditor> createState() => _MakanHoursEditorState();
}

class _MakanHoursEditorState extends State<MakanHoursEditor> {
  late bool _uniform;
  late Set<int> _days;
  late List<OpenSlot> _shared;
  late Map<int, List<OpenSlot>> _perDay;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final hasAny = initial.values.any((s) => s.isNotEmpty);
    final shared = uniformSlots(initial);
    _uniform = !hasAny || shared != null;
    _shared = [...?shared];
    _days =
        hasAny
            ? {
              for (final e in initial.entries)
                if (e.value.isNotEmpty) e.key,
            }
            : {1, 2, 3, 4, 5, 6, 7};
    _perDay = {
      for (var d = 1; d <= 7; d++) d: [...?initial[d]],
    };
  }

  WeeklyHours get _value =>
      _uniform
          ? {
            if (_shared.isNotEmpty)
              for (final d in _days) d: [..._shared],
          }
          : {
            for (final e in _perDay.entries)
              if (e.value.isNotEmpty) e.key: [...e.value],
          };

  void _emit() => widget.onChanged(_value);

  void _setUniform(bool uniform) {
    if (uniform == _uniform) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (uniform) {
        final first = _perDay.values.firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => const [],
        );
        _shared = [...first];
        _days = {
          for (final e in _perDay.entries)
            if (e.value.isNotEmpty) e.key,
        };
        if (_days.isEmpty) _days = {1, 2, 3, 4, 5, 6, 7};
      } else {
        _perDay = {
          for (var d = 1; d <= 7; d++)
            d: _days.contains(d) ? [..._shared] : <OpenSlot>[],
        };
      }
      _uniform = uniform;
    });
    _emit();
  }

  /// A sensible next slot: the usual 7 AM–10 PM, or an evening session
  /// after the last one closes (the "bukak balik malam" case).
  OpenSlot _nextSlot(List<OpenSlot> slots) {
    if (slots.isEmpty) return const OpenSlot(7 * 60, 22 * 60);
    final after = slots.last.close;
    final open = after < 17 * 60 ? 17 * 60 : after;
    final close = (open + 5 * 60).clamp(0, 23 * 60 + 59);
    return OpenSlot(open % 1440, close % 1440);
  }

  Future<OpenSlot?> _editTime(OpenSlot slot, {required bool open}) async {
    final m = open ? slot.open : slot.close;
    final picked = await showTripTimePicker(
      context: context,
      initial: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked == null) return null;
    final v = picked.hour * 60 + picked.minute;
    return open ? OpenSlot(v, slot.close) : OpenSlot(slot.open, v);
  }

  Widget _slotList(List<OpenSlot> slots, void Function(List<OpenSlot>) set) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < slots.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SlotRow(
              slot: slots[i],
              onOpen: () async {
                final s = await _editTime(slots[i], open: true);
                if (s != null) set([...slots]..[i] = s);
              },
              onClose: () async {
                final s = await _editTime(slots[i], open: false);
                if (s != null) set([...slots]..[i] = s);
              },
              onRemove: () => set([...slots]..removeAt(i)),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            MakanChip(
              label: slots.isEmpty ? '+ Add hours' : '+ Another session',
              selected: false,
              onTap: () => set([...slots, _nextSlot(slots)]),
            ),
            if (!slots.any((s) => s.isAllDay))
              MakanChip(
                label: '24 hours',
                selected: false,
                onTap: () => set(const [OpenSlot.allDay]),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MakanChip(
              label: 'Same every day',
              selected: _uniform,
              onTap: () => _setUniform(true),
            ),
            const SizedBox(width: 8),
            MakanChip(
              label: 'Varies by day',
              selected: !_uniform,
              onTap: () => _setUniform(false),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_uniform) ...[
          Text(
            'Open on',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DT.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var d = 1; d <= 7; d++) ...[
                if (d > 1) const SizedBox(width: 6),
                Expanded(
                  child: _DayToggle(
                    label: weekdayShort[d - 1].substring(0, 2),
                    on: _days.contains(d),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (!_days.remove(d)) _days.add(d);
                      });
                      _emit();
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _slotList(_shared, (s) {
            setState(() => _shared = s);
            _emit();
          }),
        ] else
          for (var d = 1; d <= 7; d++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_perDay[d]?.isEmpty ?? true)
                        ? '${weekdayLong[d - 1]} · closed'
                        : weekdayLong[d - 1],
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: DT.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _slotList(_perDay[d] ?? const [], (s) {
                    setState(() => _perDay[d] = s);
                    _emit();
                  }),
                ],
              ),
            ),
      ],
    );
  }
}

class _DayToggle extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _DayToggle({
    required this.label,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        decoration: BoxDecoration(
          color: on ? DT.catMakan : DT.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: on ? DT.catMakan : DT.border),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : DT.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final OpenSlot slot;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onRemove;

  const _SlotRow({
    required this.slot,
    required this.onOpen,
    required this.onClose,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    Widget time(String label, int minutes, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: DT.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DT.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: DT.textTertiary,
                ),
              ),
              Text(
                formatMinutes(minutes),
                style: GoogleFonts.manrope(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: DT.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (slot.isAllDay) {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: DT.catMakanSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Open 24 hours',
                style: GoogleFonts.manrope(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: DT.catMakan,
                ),
              ),
            ),
          ),
          _RemoveButton(onTap: onRemove),
        ],
      );
    }

    return Row(
      children: [
        time('Opens', slot.open, onOpen),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: DT.textTertiary,
          ),
        ),
        time(
          slot.isOvernight ? 'Closes (next day)' : 'Closes',
          slot.close,
          onClose,
        ),
        _RemoveButton(onTap: onRemove),
      ],
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Remove',
      icon: const Icon(Icons.close_rounded, size: 20, color: DT.textTertiary),
    );
  }
}
