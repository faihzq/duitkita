import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/services/route_service.dart';

void main() {
  group('departureAt', () {
    test('combines the day and the stop time', () {
      final future = DateTime.now().add(const Duration(days: 30));
      final day = DateTime(future.year, future.month, future.day);

      expect(RouteService.departureAt(day, '2:30 PM'),
          DateTime(day.year, day.month, day.day, 14, 30));
    });

    // The Routes API rejects a departure in the past, and traffic data for a
    // moment that has already passed would be meaningless anyway.
    test('is null once the moment has passed', () {
      expect(
        RouteService.departureAt(DateTime(2020, 1, 1), '9:00 AM'),
        isNull,
      );
    });

    test('is null for earlier today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(RouteService.departureAt(today, '12:01 AM'), isNull);
    });

    test('handles midnight without drifting to noon', () {
      final future = DateTime.now().add(const Duration(days: 30));
      final day = DateTime(future.year, future.month, future.day);

      final at = RouteService.departureAt(day, '12:00 AM');
      expect(at?.hour, 0);
      expect(at?.minute, 0);
    });
  });
}
