import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Primary (deep navy) ────────────────────────────────────────────────────
  static const Color primaryDark  = Color(0xFF14304F);   // darkest navy
  static const Color primary      = Color(0xFF0B1F3A);   // deep navy
  static const Color primaryLight = Color(0xFF1C3F6E);   // mid navy

  // ── Accent (mint) ──────────────────────────────────────────────────────────
  static const Color accent      = Color(0xFF1ECDB0);   // mint CTA
  static const Color accentLight = Color(0xFF7BE5CE);   // light mint
  static const Color accentDeep  = Color(0xFF0B7B66);   // dark mint text
  static const Color accentSoft  = Color(0xFFD4F5EC);   // mint bg

  // ── Status ─────────────────────────────────────────────────────────────────
  static const Color success      = Color(0xFF1F8A5B);
  static const Color successSoft  = Color(0xFFDCF1E6);
  static const Color error        = Color(0xFFC9382A);   // danger
  static const Color errorSoft    = Color(0xFFFBE1DD);
  static const Color warning      = Color(0xFFC97A0A);
  static const Color warningSoft  = Color(0xFFFBEBD2);
  static const Color info         = Color(0xFF2A6FDB);
  static const Color infoSoft     = Color(0xFFDDE8F8);

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const Color surface    = Color(0xFFFFFFFF);   // cards, sheets
  static const Color surfaceAlt = Color(0xFFEFEDE6);   // subtle fills
  static const Color cardBg     = Color(0xFFFFFFFF);   // form fields
  static const Color surfaceBg  = Color(0xFFF2F4F7);   // scaffold background

  // ── Borders ────────────────────────────────────────────────────────────────
  static const Color border       = Color(0xFFE8E4DA);
  static const Color borderStrong = Color(0xFFCBC8BD);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF0B1F3A);
  static const Color textSecondary = Color(0xFF4B5C75);
  static const Color textTertiary  = Color(0xFF8A99AE);
  static const Color textHint      = Color(0xFF8A99AE);

  // ── Category: Groups (indigo) ──────────────────────────────────────────────
  static const Color groupColor      = Color(0xFF5B5BD6);
  static const Color groupColorDark  = Color(0xFF4444AA);
  static const Color groupColorLight = Color(0xFFE4E4F8);

  // ── Category: Debts / Loans (blue) ────────────────────────────────────────
  static const Color debtColor      = Color(0xFF3B82F6);
  static const Color debtColorDark  = Color(0xFF2563EB);
  static const Color debtColorLight = Color(0xFFDBEAFE);

  // ── Category: Bills (amber) ────────────────────────────────────────────────
  static const Color billColor      = Color(0xFFF59E0B);
  static const Color billColorDark  = Color(0xFF9A5D08);
  static const Color billColorLight = Color(0xFFFEF3C7);

  // ── JDT (unchanged) ────────────────────────────────────────────────────────
  static const Color jdtRed  = Color(0xFFD32F2F);
  static const Color jdtGold = Color(0xFFFFB300);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B1F3A), Color(0xFF14304F)],
  );

  static const LinearGradient jdtGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC62828), Color(0xFFD32F2F), Color(0xFFE53935)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B7B66), Color(0xFF1ECDB0)],
  );

  static const LinearGradient debtGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [debtColorDark, debtColor, Color(0xFF60A5FA)],
  );

  static const LinearGradient billGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [billColorDark, billColor, Color(0xFFFBBF24)],
  );

  // ── Shadows ────────────────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.15),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];

  // ── Border radius ──────────────────────────────────────────────────────────
  static const double radiusSmall  = 8;
  static const double radiusMedium = 16;
  static const double radiusLarge  = 24;
  static const double radiusXLarge = 32;

  // ── ThemeData ──────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    textTheme: GoogleFonts.manropeTextTheme(),
    scaffoldBackgroundColor: surfaceBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall + 4),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall + 4),
        ),
        side: BorderSide(color: primary.withValues(alpha: 0.3)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall + 4),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall + 4),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall + 4),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      hintStyle: const TextStyle(color: textHint, fontSize: 14),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: textPrimary,
      selectionColor: Color(0x330B1F3A),
      selectionHandleColor: textPrimary,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade100,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceBg,
      selectedColor: primary,
      labelStyle: const TextStyle(fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
      ),
      headerBackgroundColor: primary,
      headerForegroundColor: Colors.white,
      headerHeadlineStyle: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      headerHelpStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.8),
      ),
      dayStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      todayBorder: const BorderSide(color: accent, width: 1.5),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return accent;
      }),
      todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent;
        return Colors.transparent;
      }),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        if (states.contains(WidgetState.disabled)) return textHint;
        return textPrimary;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return Colors.transparent;
      }),
      dayOverlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.08)),
      yearStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return textPrimary;
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return Colors.transparent;
      }),
      weekdayStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: textSecondary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      dividerColor: Colors.transparent,
    ),
  );

  // ── Styled form field decoration ───────────────────────────────────────────
  static InputDecoration styledInput({
    required String label,
    required IconData prefixIcon,
    String? hint,
    String? prefixText,
    TextStyle? prefixStyle,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: prefixStyle ?? const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textHint),
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary),
      hintStyle: const TextStyle(fontSize: 13, color: textHint),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(prefixIcon, size: 20, color: primary),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
    );
  }

  // ── Page transitions ───────────────────────────────────────────────────────
  static Route<T> slideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static Route<T> fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}
