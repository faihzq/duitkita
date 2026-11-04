import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/models/user_profile.dart';
import 'package:duitkita/services/profile_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ProfileService service;

  UserProfile profile({String? username}) => UserProfile(
    uid: 'u1',
    name: 'Fairul Haziq',
    email: 'f@example.com',
    username: username,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<Map<String, dynamic>> doc() async =>
      (await db.collection('users').doc('u1').get()).data()!;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = ProfileService(firestore: db);
  });

  test('automatic assignment never replaces an existing handle', () async {
    await db.collection('users').doc('u1').set({
      'name': 'Fairul Haziq',
      'username': 'fairul',
    });
    await db.collection('usernames').doc('fairul').set({'uid': 'u1'});

    // What ensureUsername does when its earlier read was stale.
    final result = await service.setUsername(
      uid: 'u1',
      username: 'fairulhaziq',
      onlyIfUnset: true,
    );

    expect(result, 'fairul');
    expect((await doc())['username'], 'fairul');
    expect(
      (await db.collection('usernames').doc('fairul').get()).exists,
      isTrue,
    );
    expect(
      (await db.collection('usernames').doc('fairulhaziq').get()).exists,
      isFalse,
    );
  });

  test('ensureUsername assigns one once and then leaves it alone', () async {
    await db.collection('users').doc('u1').set({'name': 'Fairul Haziq'});

    expect(await service.ensureUsername('u1'), 'fairulhaziq');
    await db.collection('users').doc('u1').update({'name': 'Someone Else'});
    expect(await service.ensureUsername('u1'), 'fairulhaziq');
    expect((await doc())['username'], 'fairulhaziq');
  });

  test('ensureUsername claims nothing without a profile', () async {
    expect(await service.ensureUsername('u1'), isNull);
    expect((await db.collection('usernames').get()).docs, isEmpty);
  });

  test('a user picking a new handle still replaces the old one', () async {
    await db.collection('users').doc('u1').set({'username': 'fairul'});
    await db.collection('usernames').doc('fairul').set({'uid': 'u1'});

    await service.setUsername(uid: 'u1', username: 'haziq');

    expect((await doc())['username'], 'haziq');
    expect(
      (await db.collection('usernames').doc('fairul').get()).exists,
      isFalse,
    );
  });

  test('updating a stale profile does not touch the username', () async {
    await db.collection('users').doc('u1').set({'username': 'fairul'});

    await service.updateUserProfile(profile(username: null));
    expect((await doc())['username'], 'fairul');

    await service.updateUserProfile(profile(username: 'old_handle'));
    expect((await doc())['username'], 'fairul');
    expect((await doc())['name'], 'Fairul Haziq');
  });

  test('creating a profile keeps fields written first', () async {
    await db.collection('users').doc('u1').set({
      'username': 'fairul',
      'fcmTokens': ['t1'],
      'fcmToken': 't1',
    });

    await service.createUserProfile(profile());

    final data = await doc();
    expect(data['username'], 'fairul');
    expect(data['fcmTokens'], ['t1']);
    expect(data['fcmToken'], 't1');
    expect(data['name'], 'Fairul Haziq');
  });
}
