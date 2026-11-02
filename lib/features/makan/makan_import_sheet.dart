import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/features/makan/makan_hours.dart';
import 'package:duitkita/features/makan/makan_places.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

/// Search Google for a place (by name or pasted Maps link) and return the one
/// picked, or null if dismissed.
Future<MakanPlace?> showMakanImportSheet(BuildContext context) {
  return showModalBottomSheet<MakanPlace>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ImportSheet(),
  );
}

class _ImportSheet extends StatefulWidget {
  const _ImportSheet();

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  final _query = TextEditingController();
  List<MakanPlace>? _results;
  String? _error;
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await searchPlaces(text);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = null;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final results = _results;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        decoration: const BoxDecoration(
          color: DT.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          DS.xl,
          18,
          DS.xl,
          12 + media.padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Fill from Google Maps',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DT.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Search the place name, or paste its Google Maps link.',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: DT.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TripInput(
                    icon: Icons.search_rounded,
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      cursorColor: DT.accent,
                      style: GoogleFonts.manrope(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: DT.text,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                        hintText: 'Roti canai Muar',
                        hintStyle: GoogleFonts.manrope(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: DT.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TripIconButton(
                  icon: Icons.arrow_forward_rounded,
                  onTap: _search,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_searching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: CircularProgressIndicator(
                    color: DT.accent,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_error != null)
              _Note(_error!, color: DT.danger)
            else if (results != null && results.isEmpty)
              const _Note('Nothing found. Try another name or add the area.')
            else if (results != null)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _Result(results[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final MakanPlace place;
  const _Result(this.place);

  @override
  Widget build(BuildContext context) {
    final hours = place.hours;
    final today = DateTime.now().weekday;
    final hoursLine =
        hours.isEmpty
            ? 'No opening hours on Google'
            : 'Today: ${formatSlots(hours[today] ?? const [])}';

    return GestureDetector(
      onTap: () => Navigator.pop(context, place),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DT.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.name,
              style: GoogleFonts.manrope(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: DT.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              place.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DT.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hoursLine,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DT.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  final Color color;
  const _Note(this.text, {this.color = DT.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
