import 'package:flutter/material.dart';

abstract class DT {
  // Surfaces
  static const bg = Color(0xFFF2F4F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF7F9FB);
  static const border = Color(0xFFE6EAF0);
  static const borderStrong = Color(0xFFD1D7E0);

  // Text
  static const text = Color(0xFF0B1F3A);
  static const textSecondary = Color(0xFF5B6B82);
  static const textTertiary = Color(0xFF8B97AA);

  // Brand
  static const primary = Color(0xFF0B1F3A);
  static const primarySoft = Color(0xFFE8ECF3);
  static const accent = Color(0xFF00C2A8);
  static const accentSoft = Color(0xFFE0F7F2);
  static const accentDeep = Color(0xFF008C7A);

  // Status
  static const success = Color(0xFF10B981);
  static const successSoft = Color(0xFFE5F7EF);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFEF3DC);
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0xFFFDECEC);
  static const info = Color(0xFF2A6FDB);
  static const infoSoft = Color(0xFFDDE8F8);

  // Categories
  static const catGroups = Color(0xFF5B6FFF);
  static const catGroupsSoft = Color(0xFFECEFFF);
  static const catDebts = Color(0xFF3B82F6);
  static const catDebtsSoft = Color(0xFFE8F0FE);
  static const catBills = Color(0xFFF59E0B);
  static const catBillsSoft = Color(0xFFFEF3DC);

  // Header gradient stops
  static const headerGradientStart = Color(0xFF0B1F3A);
  static const headerGradientEnd = Color(0xFF11264A);
}

// Spacing scale
abstract class DS {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  // Card
  static const double cardPad = 16;
  static const double cardRadius = 16;
  static const double heroRadius = 22;
  static const double chipRadius = 999;
  static const double screenPad = 20;
  static const double sectionGap = 24;
}
