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

  test('spots land in the shared top-level list', () async {
    await service.addSpot(original);
    final docs = (await db.collection('makan_spots').get()).docs;
    expect(docs, hasLength(1));
    expect(docs.single['addedBy'], 'uid-1');
  });

  test('every spot comes back, whoever added it', () async {
    await service.addSpot(original);
    await service.addSpot(
      MakanSpot.fromMap({
        ...original.toMap(),
        'name': 'Mamak Abu',
        'addedBy': 'uid-2',
      }, ''),
    );
    final spots = await service.streamAll().first;
    expect(spots.map((s) => s.addedBy), unorderedEquals(['uid-1', 'uid-2']));
    final mine = spots.firstWhere((s) => s.addedBy == 'uid-1');
    expect(mine.hours[1], const [OpenSlot(7 * 60, 11 * 60)]);
  });

  test('update keeps who added it; delete removes it', () async {
    final id = await service.addSpot(original);
    final saved = await service.streamSpot(id).first;
    await service.updateSpot(saved!.copyWith(name: 'Warung Mak Teh 2'));
    final edited = await service.streamSpot(id).first;
    expect(edited!.name, 'Warung Mak Teh 2');
    expect(edited.addedBy, 'uid-1');

    await service.deleteSpot(edited);
    expect(await service.streamSpot(id).first, isNull);
  });

  test('rejects a spot without a name or area', () async {
    expect(
      () => service.addSpot(original.copyWith(name: '  ')),
      throwsException,
    );
  });
}
