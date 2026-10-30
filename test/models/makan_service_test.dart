import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/models/makan_spot.dart';
import 'package:duitkita/services/makan_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MakanService service;

  final original = MakanSpot(
    id: 'p1',
    name: 'Warung Mak Teh',
    area: 'Bangi',
    menu: const ['Nasi Lemak'],
    hours: const {
      1: [OpenSlot(7 * 60, 11 * 60)],
    },
    mapQuery: '2.9,101.7',
    addedBy: 'uid-1',
    addedByName: 'Ali',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    service = MakanService(firestore: db);
  });

  test('personal and group spots land in separate collections', () async {
    await service.addSpot(original);
    await service.addSpot(original, groupId: 'g1');

    expect((await db.collection('makan_spots').get()).docs, hasLength(1));
    final group =
        await db.collection('groups').doc('g1').collection('makan_spots').get();
    expect(group.docs, hasLength(1));
  });

  test('group stream tags spots with their group id', () async {
    await service.addSpot(original, groupId: 'g1');
    final spots = await service.streamGroup('g1').first;
    expect(spots.single.groupId, 'g1');
    expect(spots.single.hours[1], const [OpenSlot(7 * 60, 11 * 60)]);
  });

  test('personal stream only returns the user\'s own spots', () async {
    await service.addSpot(original);
    await db.collection('makan_spots').add({
      ...original.toMap(),
      'addedBy': 'someone-else',
    });
    final spots = await service.streamPersonal('uid-1').first;
    expect(spots, hasLength(1));
    expect(spots.single.groupId, isNull);
  });

  test('copySpot copies content but takes the copier as owner', () async {
    await service.copySpot(
      original,
      toGroupId: 'g1',
      byUserId: 'uid-2',
      byName: 'Abu',
    );
    final copy = (await service.streamGroup('g1').first).single;
    expect(copy.name, original.name);
    expect(copy.menu, original.menu);
    expect(copy.hours, original.hours);
    expect(copy.mapQuery, original.mapQuery);
    expect(copy.addedBy, 'uid-2');
    expect(copy.addedByName, 'Abu');
  });

  test('hasSpotNamed checks the right list', () async {
    await service.addSpot(original, groupId: 'g1');

    expect(
      await service.hasSpotNamed('Warung Mak Teh', groupId: 'g1', userId: 'x'),
      isTrue,
    );
    expect(
      await service.hasSpotNamed('Warung Mak Teh', groupId: 'g2', userId: 'x'),
      isFalse,
    );
    expect(
      await service.hasSpotNamed('Warung Mak Teh', userId: 'uid-1'),
      isFalse,
    );
  });

  test('rejects a spot without a name or area', () async {
    expect(
      () => service.addSpot(original.copyWith(name: '  ')),
      throwsException,
    );
  });
}
