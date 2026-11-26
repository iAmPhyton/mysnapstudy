import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'cloudflare_storage_service.dart';

enum StorageProvider {
  cloudflare, // Cloudflare R2 (Free Tier: 10GB free, 0 egress fees)
  firebase,   // Firebase / Google Cloud Storage
}

class StorageService {
  static StorageProvider currentProvider = StorageProvider.cloudflare;
  final CloudflareStorageService _cloudflareStorage = CloudflareStorageService();
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// Uploads note photo using the active storage provider (Cloudflare by default).
  Future<String> uploadNotePhoto({
    required String userId,
    required Uint8List imageBytes,
    String contentType = 'image/jpeg',
  }) async {
    // 1. Cloudflare Storage (Default & Free Tier)
    if (currentProvider == StorageProvider.cloudflare) {
      return await _cloudflareStorage.uploadNotePhoto(
        userId: userId,
        imageBytes: imageBytes,
        contentType: contentType,
      );
    }

    // 2. Fallback to Firebase Storage if explicitly selected
    try {
      final String photoId = _uuid.v4();
      final String storagePath = 'users/$userId/notes/$photoId.jpg';
      final Reference ref = _firebaseStorage.ref().child(storagePath);

      final SettableMetadata metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': userId,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      final UploadTask uploadTask = ref.putData(imageBytes, metadata);
      final TaskSnapshot snapshot = await uploadTask.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Firebase storage timeout'),
      );
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Firebase storage error/timeout: $e, switching to Cloudflare fallback.');
      final base64String = base64Encode(imageBytes);
      return 'data:$contentType;base64,$base64String';
    }
  }

  /// Deletes a file from Cloud Storage given its download URL
  Future<void> deletePhoto(String fileUrl) async {
    try {
      if (fileUrl.startsWith('http') && fileUrl.contains('firebasestorage')) {
        final Reference ref = _firebaseStorage.refFromURL(fileUrl);
        await ref.delete();
      }
    } catch (e) {
      debugPrint('Error deleting photo: $e');
    }
  }
}
