import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload receipt (image or PDF) and return download URL
  Future<String> uploadReceipt({
    required String groupId,
    required String userId,
    required File file,
    String? fileExtension,
  }) async {
    try {
      // Create unique filename using timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Get file extension from the file path if not provided
      final extension = fileExtension ?? file.path.split('.').last.toLowerCase();

      final filename = 'receipt_${userId}_$timestamp.$extension';

      // Create path: receipts/groupId/filename
      final path = 'receipts/$groupId/$filename';

      // Upload file
      final ref = _storage.ref().child(path);

      // Set metadata based on file type
      SettableMetadata? metadata;
      if (extension == 'pdf') {
        metadata = SettableMetadata(contentType: 'application/pdf');
      } else if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
        metadata = SettableMetadata(contentType: 'image/$extension');
      }

      final uploadTask = metadata != null
          ? await ref.putFile(file, metadata)
          : await ref.putFile(file);

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload receipt: $e');
    }
  }

  // Delete receipt from storage
  Future<void> deleteReceipt(String receiptUrl) async {
    try {
      final ref = _storage.refFromURL(receiptUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete receipt: $e');
    }
  }
}

// Provider for storage service
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});
