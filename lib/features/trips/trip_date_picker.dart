import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';

/// The stock Material date picker, restyled in DuitKita colours.
///
/// Unlike the time picker this keeps Material's calendar wholesale — a date
/// grid is a solved problem, and rebuilding it would cost far more than it
/// returns. Only the palette and type are swapped so it stops reading as a
/// different product.
Future<DateTime?> showTripDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    builder:
        (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: DT.text,
              onPrimary: Colors.white,
              surface: DT.surface,
              onSurface: DT.text,
            ),
            datePickerTheme: _theme,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: DT.accentDeep,
                textStyle: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          child: child!,
        ),
  );
}

final _theme = DatePickerThemeData(
  backgroundColor: DT.surface,
  // M3 tints surfaces with the seed colour; that is what makes it look lavender.
  surfaceTintColor: Colors.transparent,
  elevation: 8,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  dividerColor: DT.border,

  // Navy header, matching the itinerary and stop-detail headers.
  headerBackgroundColor: DT.text,
  headerForegroundColor: Colors.white,
  headerHelpStyle: GoogleFonts.manrope(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Colors.white70,
    letterSpacing: 0.4,
  ),
  headerHeadlineStyle: GoogleFonts.manrope(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.6,
  ),

  weekdayStyle: GoogleFonts.manrope(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: DT.textSecondary,
  ),
  dayStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),

  dayForegroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) return Colors.white;
    if (states.contains(WidgetState.disabled)) return DT.textTertiary;
    return DT.text;
  }),
  dayBackgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected) ? DT.text : null,
  ),
  dayOverlayColor: WidgetStateProperty.all(DT.primarySoft),

  // Today reads in the accent so it stays distinct from the selection.
  todayForegroundColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.selected) ? Colors.white : DT.accentDeep,
  ),
  todayBackgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected) ? DT.text : null,
  ),
  todayBorder: const BorderSide(color: DT.accent, width: 1.5),

  yearStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
  yearForegroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected) ? Colors.white : DT.text,
  ),
  yearBackgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected) ? DT.text : null,
  ),

  cancelButtonStyle: TextButton.styleFrom(
    foregroundColor: DT.textSecondary,
    textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
  ),
  confirmButtonStyle: TextButton.styleFrom(
    foregroundColor: DT.accentDeep,
    textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
  ),
);
