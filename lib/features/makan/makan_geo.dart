/// Distance maths for "Near me". Pure — the position is passed in.
library;

import 'dart:math' as math;

import 'package:duitkita/models/makan_spot.dart';

typedef LatLng = ({double lat, double lng});

/// Great-circle distance in kilometres (haversine). Straight-line, not road
/// distance — good enough to rank warung around you.
double distanceKm(LatLng a, LatLng b) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h.toDouble()));
}

/// "350 m", "1.2 km", "14 km".
String formatDistance(double km) {
  if (km < 1) return '${(km * 1000 / 10).round() * 10} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

/// Spot id → distance, for spots whose location is known.
Map<String, double> distancesFrom(LatLng here, List<MakanSpot> spots) => {
  for (final s in spots)
    if (s.coords != null) s.id: distanceKm(here, s.coords!),
};

/// Nearest first; spots without a location keep their order at the end.
List<MakanSpot> sortByDistance(
  List<MakanSpot> spots,
  Map<String, double> distances,
) {
  final known =
      spots.where((s) => distances.containsKey(s.id)).toList()
        ..sort((a, b) => distances[a.id]!.compareTo(distances[b.id]!));
  return [...known, ...spots.where((s) => !distances.containsKey(s.id))];
}
