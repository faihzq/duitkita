import 'package:geolocator/geolocator.dart';
import 'package:duitkita/features/makan/makan_geo.dart';

/// Why a position could not be had, so the UI can say what to do about it.
enum LocationProblem { serviceOff, denied, deniedForever, unavailable }

typedef LocationResult = ({LatLng? position, LocationProblem? problem});

/// Asks for permission if needed, then reads the current position.
///
/// Foreground only. A recent last-known fix is accepted when a fresh one is
/// slow, since ranking warung does not need metre accuracy.
Future<LocationResult> currentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (position: null, problem: LocationProblem.serviceOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return (position: null, problem: LocationProblem.deniedForever);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      return (position: null, problem: LocationProblem.denied);
    }

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }
    if (pos == null) {
      return (position: null, problem: LocationProblem.unavailable);
    }
    return (position: (lat: pos.latitude, lng: pos.longitude), problem: null);
  } catch (_) {
    return (position: null, problem: LocationProblem.unavailable);
  }
}

String locationProblemMessage(LocationProblem p) => switch (p) {
  LocationProblem.serviceOff => 'Turn on location to see what\'s near you',
  LocationProblem.denied => 'Location permission is needed for this',
  LocationProblem.deniedForever =>
    'Location is blocked for DuitKita. Allow it in Settings',
  LocationProblem.unavailable => 'Could not get your location. Try again',
};

/// Opens the screen that fixes [p], when there is one.
Future<void> openFixFor(LocationProblem p) async {
  switch (p) {
    case LocationProblem.serviceOff:
      await Geolocator.openLocationSettings();
    case LocationProblem.deniedForever:
      await Geolocator.openAppSettings();
    case LocationProblem.denied || LocationProblem.unavailable:
      break;
  }
}
