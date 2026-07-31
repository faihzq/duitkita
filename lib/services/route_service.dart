import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/models/itinerary_stop.dart';

/// One leg's drive estimate, as returned by the `computeLeg` Cloud Function.
class LegEstimate {
  final int minutes;
  final double km;
  const LegEstimate({required this.minutes, required this.km});
}

/// Thrown with a message already fit to show the user.
class RouteFailure implements Exception {
  final String message;
  const RouteFailure(this.message);
  @override
  String toString() => message;
}

/// Drive estimates from the Google Routes API, proxied through Cloud Functions.
///
/// The call is server-side because Routes is a Web Service API: it only
/// supports IP restrictions, so a key shipped in the app could be lifted from
/// the APK and billed to us.
class RouteService {
  RouteService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  Future<LegEstimate> computeLeg({
    required String origin,
    required String destination,
    DateTime? departAt,
  }) async {
    try {
      final result = await _functions.httpsCallable('computeLeg').call({
        'origin': origin,
        'destination': destination,
        if (departAt != null) 'departureTime': departAt.toUtc().toIso8601String(),
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return LegEstimate(
        minutes: (data['minutes'] as num?)?.round() ?? 0,
        km: (data['km'] as num?)?.toDouble() ?? 0,
      );
    } on FirebaseFunctionsException catch (e) {
      throw RouteFailure(switch (e.code) {
        'not-found' =>
          'No driving route between those stops — ferry crossings and '
              'islands need entering by hand.',
        'unauthenticated' => 'Sign in again to estimate drive times.',
        'unavailable' => 'Could not reach Google Maps. Check your connection.',
        'invalid-argument' => 'Add a place to both stops first.',
        _ => e.message ?? 'Could not work out that drive.',
      });
    } catch (_) {
      throw const RouteFailure('Could not work out that drive.');
    }
  }

  /// When the traveller leaves the previous stop, for a traffic-aware estimate.
  ///
  /// Returns null when that moment has already passed — the Routes API rejects
  /// a past departure, and traffic data for it would be meaningless anyway, so
  /// the server falls back to a traffic-free estimate.
  static DateTime? departureAt(DateTime dayDate, String timeLabel) {
    final minutes = minutesFromTimeLabel(timeLabel);
    final at = DateTime(
      dayDate.year,
      dayDate.month,
      dayDate.day,
      minutes ~/ 60,
      minutes % 60,
    );
    return at.isAfter(DateTime.now()) ? at : null;
  }
}

final routeServiceProvider = Provider<RouteService>((ref) => RouteService());
