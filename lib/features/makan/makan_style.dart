import 'package:duitkita/models/makan_spot.dart';

/// Kinds of place offered in the form. Stored by label, so a spot keeps its
/// category even if this list is reordered or an emoji changes.
const makanCategories = <(String, String)>[
  ('Mamak', '🫓'),
  ('Warung', '🍲'),
  ('Kopitiam', '☕'),
  ('Nasi Kandar', '🍛'),
  ('Nasi Campur', '🍱'),
  ('Gerai', '🛖'),
  ('Kafe', '🥐'),
  ('Western', '🍔'),
  ('Chinese', '🥢'),
  ('Thai', '🌶️'),
  ('Seafood', '🦐'),
  ('Bakeri', '🍞'),
  ('Fast food', '🍟'),
  ('Dessert', '🍧'),
];

String makanEmoji(MakanSpot spot) {
  for (final c in spot.categories) {
    for (final (label, emoji) in makanCategories) {
      if (label == c) return emoji;
    }
  }
  return '🍽️';
}

/// Directions deep links. Prefer coordinates, then [MakanSpot.mapQuery]; with only
/// an unresolved share link, open that link itself; with nothing, search by
/// name and area so the button still does something useful.
class MakanMaps {
  /// Coordinates beat a place name — a GPS pin or a resolved link is the
  /// exact spot, while a name still has to be geocoded by the maps app.
  static String _destination(MakanSpot s) {
    final c = s.coords;
    if (c != null) return '${c.lat},${c.lng}';
    final query = s.mapQuery?.trim() ?? '';
    if (query.isNotEmpty) return query;
    return '${s.name}, ${s.area}';
  }

  static Uri google(MakanSpot s) {
    final link = s.mapLink?.trim() ?? '';
    if ((s.mapQuery?.trim().isEmpty ?? true) &&
        s.coords == null &&
        link.startsWith('http')) {
      return Uri.parse(link);
    }
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&travelmode=driving'
      '&destination=${Uri.encodeComponent(_destination(s))}',
    );
  }

  static Uri waze(MakanSpot s) {
    final c = s.coords;
    if (c != null) {
      return Uri.parse('https://waze.com/ul?ll=${c.lat},${c.lng}&navigate=yes');
    }
    return Uri.parse(
      'https://waze.com/ul?q=${Uri.encodeComponent(_destination(s))}&navigate=yes',
    );
  }
}
