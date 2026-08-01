import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:duitkita/models/itinerary_stop.dart';

/// Keeps opened tickets on the device.
///
/// The point of carrying a ticket in the app is having it at the gate, which is
/// exactly where the signal tends to fail — a Storage download URL is useless
/// there. So the first open downloads and keeps the file, and every open after
/// that reads from disk and works offline.
class AttachmentCache {
  AttachmentCache({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// Stable local filename for an attachment.
  ///
  /// Derived from the Storage object path, which is already unique (it carries
  /// the trip, the stop and an upload timestamp) and survives the download
  /// URL's token being reissued. Falls back to a hash of the whole URL for
  /// anything that isn't a Firebase Storage link.
  static String fileNameFor(StopAttachment attachment) {
    final url = attachment.url;
    final marker = url.indexOf('/o/');
    if (marker != -1) {
      final encoded = url.substring(marker + 3).split('?').first;
      final path = Uri.decodeComponent(encoded);
      final safe = path.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      if (safe.isNotEmpty) return safe;
    }
    return '${_hash(url)}_${attachment.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}';
  }

  /// FNV-1a, so no dependency is needed for a filename. Masked to 63 bits:
  /// Dart ints are signed, so a full 64-bit mask leaves the sign bit set and
  /// the name would start with '-'.
  static String _hash(String value) {
    var h = 0xcbf29ce484222325;
    for (final c in value.codeUnits) {
      h ^= c;
      h = (h * 0x100000001b3) & 0x7FFFFFFFFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  Future<Directory> _directory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/trip_tickets');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// The local copy, or null when this attachment has never been opened.
  Future<File?> cached(StopAttachment attachment) async {
    try {
      final dir = await _directory();
      final file = File('${dir.path}/${fileNameFor(attachment)}');
      if (await file.exists() && await file.length() > 0) return file;
    } catch (_) {
      // No documents directory — fall through to a fresh download.
    }
    return null;
  }

  /// The file to open: the cached copy when present, otherwise downloaded and
  /// stored first. Throws when it isn't cached and can't be fetched.
  Future<File> resolve(StopAttachment attachment) async {
    final existing = await cached(attachment);
    if (existing != null) return existing;

    final owned = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client.get(Uri.parse(attachment.url));
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }
      final dir = await _directory();
      final file = File('${dir.path}/${fileNameFor(attachment)}');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } finally {
      if (owned) client.close();
    }
  }

  /// Drops the local copy — used when an attachment is removed from a stop.
  Future<void> evict(StopAttachment attachment) async {
    final file = await cached(attachment);
    if (file != null) {
      try {
        await file.delete();
      } catch (_) {
        // Best effort; a stale file is harmless.
      }
    }
  }
}

final attachmentCacheProvider = Provider<AttachmentCache>(
  (ref) => AttachmentCache(),
);
