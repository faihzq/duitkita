import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/trips/attachment_cache.dart';
import 'package:duitkita/models/itinerary_stop.dart';

void main() {
  StopAttachment make(String url, {String name = 'ticket.pdf'}) =>
      StopAttachment(
        url: url,
        name: name,
        contentType: name.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg',
        sizeBytes: 1024,
        uploadedAt: DateTime(2026, 8, 1),
      );

  group('fileNameFor', () {
    const storageUrl =
        'https://firebasestorage.googleapis.com/v0/b/duitkita-8451b.appspot.com/o/'
        'trip_tickets%2Ftrip1%2Fstop1%2F123_cablecar.pdf?alt=media&token=abc-123';

    test('derives a safe name from the storage object path', () {
      final name = make(storageUrl).fileNameFor;
      expect(name, 'trip_tickets_trip1_stop1_123_cablecar.pdf');
    });

    test('is stable when the download token is reissued', () {
      // Storage rotates ?token= — the cached file must survive that, or every
      // rotation would silently re-download.
      final a = AttachmentCache.fileNameFor(make(storageUrl));
      final b = AttachmentCache.fileNameFor(
          make(storageUrl.replaceAll('abc-123', 'zzz-999')));
      expect(a, b);
    });

    test('separates different stops', () {
      final a = AttachmentCache.fileNameFor(make(storageUrl));
      final b = AttachmentCache.fileNameFor(
          make(storageUrl.replaceAll('stop1', 'stop2')));
      expect(a, isNot(b));
    });

    test('produces a path-safe name with no separators', () {
      final name = AttachmentCache.fileNameFor(make(storageUrl));
      expect(name.contains('/'), isFalse);
      expect(name.contains('%'), isFalse);
      expect(name.contains('?'), isFalse);
    });

    test('falls back to a hash plus the display name for a non-Storage url', () {
      final name = AttachmentCache.fileNameFor(
        make('https://example.com/x', name: 'my ticket.pdf'),
      );
      expect(name, endsWith('_my_ticket.pdf'));
      expect(name.contains(' '), isFalse);
      // A leading '-' from a signed hash would be a poor filename.
      expect(name.startsWith('-'), isFalse);
    });

    test('gives different names to different non-Storage urls', () {
      final a = AttachmentCache.fileNameFor(make('https://example.com/a.pdf'));
      final b = AttachmentCache.fileNameFor(make('https://example.com/b.pdf'));
      expect(a, isNot(b));
    });
  });

  group('StopAttachment', () {
    test('classifies pdfs and images', () {
      expect(make('u', name: 'ticket.pdf').isPdf, isTrue);
      expect(make('u', name: 'ticket.pdf').isImage, isFalse);
      expect(make('u', name: 'pass.jpg').isImage, isTrue);
    });

    test('formats size', () {
      StopAttachment sized(int bytes) => StopAttachment(
            url: 'u',
            name: 'n',
            contentType: 'application/pdf',
            sizeBytes: bytes,
            uploadedAt: DateTime(2026),
          );
      expect(sized(0).sizeLabel, '');
      expect(sized(840 * 1024).sizeLabel, '840 KB');
      expect(sized(1536 * 1024).sizeLabel, '1.5 MB');
    });

    test('round-trips through the stop', () {
      final stop = ItineraryStop(
        id: 's1',
        day: 1,
        time: '9:00 AM',
        title: 'Cable car',
        attachments: [make('https://x/o/a.pdf')],
      );
      final restored = ItineraryStop.fromMap(stop.toMap(), 's1');

      expect(restored.attachments, hasLength(1));
      expect(restored.attachments.first.name, 'ticket.pdf');
      expect(restored.hasTickets, isTrue);
    });

    test('stops saved before the feature have none', () {
      final restored = ItineraryStop.fromMap(
        {'day': 1, 'time': '9:00 AM', 'title': 'Old'},
        'legacy',
      );
      expect(restored.attachments, isEmpty);
      expect(restored.hasTickets, isFalse);
    });
  });
}

extension on StopAttachment {
  String get fileNameFor => AttachmentCache.fileNameFor(this);
}
