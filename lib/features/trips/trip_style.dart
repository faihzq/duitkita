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
  /// Outlined variants throughout: the handoff's `TIcon` set is entirely
  /// stroke-drawn, so Material's filled `_rounded` icons read far heavier than
  /// the frame. These are the closest line equivalents.
  static const _map = <String, IconData>{
    'car': Icons.directions_car_outlined,
    'ferry': Icons.directions_ferry_outlined,
    'boat': Icons.directions_boat_outlined,
    // Material has no cable-car glyph in this Flutter version (only `cable`,
    // an ethernet lead). A tram is the nearest hanging-cabin shape.
    'cablecar': Icons.tram_outlined,
    'plane': Icons.flight_outlined,
    'train': Icons.train_outlined,
    'food': Icons.restaurant_outlined,
    'cafe': Icons.local_cafe_outlined,
    'mosque': Icons.mosque_outlined,
    'mountain': Icons.landscape_outlined,
    'bag': Icons.shopping_bag_outlined,
    'camera': Icons.photo_camera_outlined,
    'wave': Icons.waves_outlined,
    'flag': Icons.flag_outlined,
    'pin': Icons.place_outlined,
    'home': Icons.home_outlined,
    'hotel': Icons.hotel_outlined,
    'clock': Icons.schedule_outlined,
    'beach': Icons.beach_access_outlined,
  };

  static IconData icon(String key) => _map[key] ?? Icons.place_outlined;

  /// Glyphs offered in the Add-a-stop picker, grouped by the type they suit.
  static List<String> forType(StopType t) => switch (t) {
    StopType.travel => [
      'car',
      'ferry',
      'boat',
      'plane',
      'train',
      'flag',
      'pin',
    ],
    StopType.food => ['food', 'cafe'],
    StopType.sight => [
      'camera',
      'mountain',
      'bag',
      'wave',
      'beach',
      'cablecar',
    ],
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

  /// Band assigned at creation time — there is no picker in the design, so it
  /// is derived from the trip name. Deterministic, so a given trip always keeps
  /// the same colour, and different trips in a list vary.
  static String autoKey(String seed) => keys[_hash(seed) % keys.length];

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

/// Emoji pool for the trip card tile. Like the colour band, it is assigned
/// automatically — the design has no picker for it.
const kTripEmojis = [
  '🦅',
  '🌿',
  '🏛️',
  '🏝️',
  '⛰️',
  '🕌',
  '🚗',
  '✈️',
  '🛳️',
  '🏕️',
  '🎡',
  '🍜',
  '📸',
  '🌊',
  '🎿',
  '🗺️',
];

String autoTripEmoji(String seed) =>
    kTripEmojis[_hash(seed) % kTripEmojis.length];

/// Stable non-negative hash — `String.hashCode` is not guaranteed stable across
/// runs, and these values are persisted on the trip document.
int _hash(String s) {
  var h = 0;
  for (final ch in s.codeUnits) {
    h = (h * 31 + ch) & 0x7FFFFFFF;
  }
  return h;
}
