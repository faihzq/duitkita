import 'package:flutter/material.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/itinerary_stop.dart';

/// Stop type → colour pair. Mirrors the handoff's `TYPE` map.
class StopTypeStyle {
  final Color color;
  final Color soft;
  const StopTypeStyle(this.color, this.soft);
}

StopTypeStyle stopTypeStyle(StopType t) => switch (t) {
      StopType.travel => const StopTypeStyle(DT.info, DT.infoSoft),
      StopType.food => const StopTypeStyle(DT.warning, DT.warningSoft),
      StopType.sight => const StopTypeStyle(DT.catGroups, DT.catGroupsSoft),
      StopType.stay => const StopTypeStyle(DT.accentDeep, DT.accentSoft),
      StopType.prayer => const StopTypeStyle(DT.textSecondary, DT.surfaceAlt),
    };

/// Glyph keys stored on a stop → Material icons. The handoff draws these as
/// inline SVG line-icons; the closest rounded Material equivalent is used here.
class TripGlyphs {
  static const _map = <String, IconData>{
    'car': Icons.directions_car_rounded,
    'ferry': Icons.directions_ferry_rounded,
    'boat': Icons.sailing_rounded,
    'cablecar': Icons.tram_rounded,
    'plane': Icons.flight_rounded,
    'train': Icons.train_rounded,
    'food': Icons.restaurant_rounded,
    'cafe': Icons.local_cafe_rounded,
    'mosque': Icons.mosque_rounded,
    'mountain': Icons.landscape_rounded,
    'bag': Icons.shopping_bag_rounded,
    'camera': Icons.photo_camera_rounded,
    'wave': Icons.waves_rounded,
    'flag': Icons.flag_rounded,
    'pin': Icons.place_rounded,
    'home': Icons.home_rounded,
    'hotel': Icons.hotel_rounded,
    'clock': Icons.schedule_rounded,
    'beach': Icons.beach_access_rounded,
  };

  static IconData icon(String key) => _map[key] ?? Icons.place_rounded;

  /// Glyphs offered in the Add-a-stop picker, grouped by the type they suit.
  static List<String> forType(StopType t) => switch (t) {
        StopType.travel => ['car', 'ferry', 'boat', 'plane', 'train', 'flag', 'pin'],
        StopType.food => ['food', 'cafe'],
        StopType.sight => ['camera', 'mountain', 'bag', 'wave', 'beach', 'cablecar'],
        StopType.stay => ['home', 'hotel'],
        StopType.prayer => ['mosque', 'clock'],
      };
}

/// Preset colour bands for a trip card. Stored on the trip as `bandGradient`.
class TripBands {
  static const _presets = <String, List<Color>>{
    'navy': [Color(0xFF0B1F3A), Color(0xFF1E5A78)],
    'teal': [Color(0xFF0B3A2E), Color(0xFF00897B)],
    'gold': [Color(0xFF3A2E0B), Color(0xFF7A6410)],
    'plum': [Color(0xFF2E0B3A), Color(0xFF7A3E9B)],
    'sunset': [Color(0xFF3A0B14), Color(0xFFC2410C)],
    'sky': [Color(0xFF0B2A3A), Color(0xFF0284C7)],
  };

  static const keys = ['navy', 'teal', 'gold', 'plum', 'sunset', 'sky'];

  static LinearGradient gradient(String? key) {
    final colors = _presets[key] ?? _presets['navy']!;
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

/// The navy header gradient used by Itinerary and Stop detail.
const tripHeaderGradient = LinearGradient(
  colors: [DT.headerGradientStart, DT.headerGradientEnd],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Emoji offered when creating a trip.
const kTripEmojis = [
  '🦅', '🌿', '🏛️', '🏝️', '⛰️', '🕌', '🚗', '✈️',
  '🛳️', '🏕️', '🎡', '🍜', '📸', '🌊', '🎿', '🗺️',
];
