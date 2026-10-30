import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/models/trip_model.dart';

void main() {
  TripModel makeTrip({
    DateTime? start,
    DateTime? end,
    TripStatus status = TripStatus.tentative,
    List<String> destinations = const ['Perlis', 'Kedah', 'Penang'],
  }) =>
      TripModel(
        id: 'trip-1',
        name: 'Langkawi Road Trip',
        destinations: destinations,
        startDate: start ?? DateTime(2026, 8, 8),
        endDate: end ?? DateTime(2026, 8, 14),
        status: status,
        emoji: '🦅',
        bandGradient: 'navy',
        createdBy: 'uid-001',
        travellerIds: const ['uid-001', 'uid-002'],
        travellers: const [
          TripTraveller(userId: 'uid-001', name: 'Ibu'),
          TripTraveller(userId: 'uid-002', name: 'Along'),
        ],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  group('dayCount', () {
    test('counts both endpoints', () {
      expect(makeTrip().dayCount, 7);
    });

    test('is 1 for a single-day trip', () {
      final d = DateTime(2026, 3, 21);
      expect(makeTrip(start: d, end: d).dayCount, 1);
    });

    test('ignores the time component', () {
      expect(
        makeTrip(
          start: DateTime(2026, 8, 8, 23, 30),
          end: DateTime(2026, 8, 9, 1, 0),
        ).dayCount,
        2,
      );
    });

    test('spans month boundaries', () {
      expect(
        makeTrip(start: DateTime(2026, 1, 30), end: DateTime(2026, 2, 2))
            .dayCount,
        4,
      );
    });
  });

  group('dateForDay', () {
    test('day 1 is the start date', () {
      expect(makeTrip().dateForDay(1), DateTime(2026, 8, 8));
    });

    test('rolls over into the next month', () {
      final trip =
          makeTrip(start: DateTime(2026, 1, 30), end: DateTime(2026, 2, 2));
      expect(trip.dateForDay(3), DateTime(2026, 2, 1));
    });
  });

  test('where joins destinations', () {
    expect(makeTrip().where, 'Perlis · Kedah · Penang');
    expect(makeTrip(destinations: const []).where, '');
  });

  group('isPast', () {
    test('is true for a trip that ended long ago', () {
      expect(
        makeTrip(start: DateTime(2020, 1, 1), end: DateTime(2020, 1, 5)).isPast,
        isTrue,
      );
    });

    test('is false for a trip ending in the future', () {
      final soon = DateTime.now().add(const Duration(days: 10));
      expect(makeTrip(start: DateTime.now(), end: soon).isPast, isFalse);
    });
  });

  group('serialisation', () {
    test('round-trips through toMap/fromMap', () {
      final restored = TripModel.fromMap(makeTrip().toMap(), 'trip-1');

      expect(restored.name, 'Langkawi Road Trip');
      expect(restored.destinations, ['Perlis', 'Kedah', 'Penang']);
      expect(restored.startDate, DateTime(2026, 8, 8));
      expect(restored.status, TripStatus.tentative);
      expect(restored.emoji, '🦅');
      expect(restored.travellerIds, ['uid-001', 'uid-002']);
      expect(restored.travellers.map((t) => t.name), ['Ibu', 'Along']);
    });

    test('toMap omits stopCount so increments are never clobbered', () {
      expect(makeTrip().toMap().containsKey('stopCount'), isFalse);
    });

    test('fromMap reads stopCount and defaults it to 0', () {
      final base = makeTrip().toMap();
      expect(TripModel.fromMap(base, 'trip-1').stopCount, 0);
      expect(
        TripModel.fromMap({...base, 'stopCount': 43}, 'trip-1').stopCount,
        43,
      );
    });

    test('fromMap tolerates a missing/unknown status and empty doc fields', () {
      final restored = TripModel.fromMap(
        {'name': 'Trip', 'status': 'cancelled'},
        'trip-2',
      );
      expect(restored.status, TripStatus.tentative);
      expect(restored.destinations, isEmpty);
      expect(restored.travellers, isEmpty);
    });

    test('fromMap reads Firestore Timestamps', () {
      final restored = TripModel.fromMap(
        {
          'name': 'Trip',
          'startDate': Timestamp.fromDate(DateTime(2026, 8, 8)),
          'endDate': Timestamp.fromDate(DateTime(2026, 8, 14)),
        },
        'trip-3',
      );
      expect(restored.dayCount, 7);
    });
  });

  test('copyWith preserves identity fields and bumps updatedAt', () {
    final trip = makeTrip();
    final updated = trip.copyWith(status: TripStatus.confirmed);

    expect(updated.id, trip.id);
    expect(updated.createdBy, trip.createdBy);
    expect(updated.createdAt, trip.createdAt);
    expect(updated.status, TripStatus.confirmed);
    expect(updated.updatedAt.isAfter(trip.updatedAt), isTrue);
  });

  group('isOrganiser', () {
    test('is true only for the creator', () {
      final trip = makeTrip();
      expect(trip.isOrganiser('uid-001'), isTrue);
      // A fellow traveller is not the organiser.
      expect(trip.isOrganiser('uid-002'), isFalse);
      expect(trip.isOrganiser('someone-else'), isFalse);
    });

    test('is false for a signed-out or empty user', () {
      final trip = makeTrip();
      expect(trip.isOrganiser(null), isFalse);
      expect(trip.isOrganiser(''), isFalse);
    });

    test('is false when the trip has no creator recorded', () {
      final orphan = TripModel.fromMap({'name': 'Trip'}, 'trip-x');
      // createdBy defaults to '', which must not match an empty uid.
      expect(orphan.isOrganiser(''), isFalse);
      expect(orphan.isOrganiser('uid-001'), isFalse);
    });
  });

  test('tripStatusLabel covers every status', () {
    expect(tripStatusLabel(TripStatus.tentative), 'Tentative');
    expect(tripStatusLabel(TripStatus.confirmed), 'Confirmed');
    expect(tripStatusLabel(TripStatus.settled), 'Settled');
  });
}
