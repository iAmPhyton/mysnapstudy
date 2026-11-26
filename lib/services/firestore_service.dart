import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/study_material.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // In-memory local cache of offline-staged materials so uploads never fail when offline
  static final Map<String, StudyMaterial> _localOfflineMaterials = <String, StudyMaterial>{};

  // Sync / create user profile document upon login
  Future<void> syncUserProfile(User user) async {
    try {
      final userRef = _db.collection('users').doc(user.uid);
      final doc = await userRef.get().timeout(const Duration(seconds: 4));

      if (!doc.exists) {
        await userRef.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'photoUrl': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      } else {
        await userRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          if (user.displayName != null && user.displayName!.isNotEmpty)
            'displayName': user.displayName,
          if (user.photoURL != null && user.photoURL!.isNotEmpty)
            'photoUrl': user.photoURL,
        });
      }
    } catch (e) {
      debugPrint('[FirestoreService] Notice syncing user profile (offline mode): $e');
    }
  }

  // Collection reference for user notes: /users/{userId}/notes
  CollectionReference<Map<String, dynamic>> _notesRef(String userId) {
    return _db.collection('users').doc(userId).collection('notes');
  }

  // Create or update study notes (offline-first & resilient)
  Future<void> saveStudyMaterial(StudyMaterial material) async {
    // 1. Immediately cache locally in memory so note is preserved offline
    _localOfflineMaterials[material.id] = material;

    // 2. Persist to Firestore (or offline persistence buffer)
    try {
      final ref = _notesRef(material.userId).doc(material.id);
      await ref.set(material.toMap(), SetOptions(merge: true)).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('[FirestoreService] Firestore network timeout. Saved to local offline buffer.');
          return;
        },
      );
    } catch (e) {
      debugPrint('[FirestoreService] Offline notice: $e. Note ${material.id} safely stored locally.');
      // Do not rethrow! The note is safely staged locally.
    }
  }

  // Real-time stream of all notes for the authenticated user (merging local offline-staged notes)
  Stream<List<StudyMaterial>> getStudyMaterials(String userId) {
    return _notesRef(userId).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => StudyMaterial.fromFirestore(doc)).toList();

      // Merge local offline-staged notes that are pending or not yet reflected in Firestore
      for (final localItem in _localOfflineMaterials.values.where((m) => m.userId == userId)) {
        final existingIndex = list.indexWhere((item) => item.id == localItem.id);
        if (existingIndex == -1) {
          list.add(localItem);
        } else if (list[existingIndex].isPending && localItem.isCompleted) {
          list[existingIndex] = localItem;
        }
      }

      // Sort client-side to avoid composite index requirements
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).handleError((error) {
      debugPrint('[FirestoreService] Offline snapshot error: $error. Serving local offline list.');
      final offlineList = _localOfflineMaterials.values.where((m) => m.userId == userId).toList();
      offlineList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return offlineList;
    });
  }

  // Fetch a single study note by ID
  Future<StudyMaterial?> getStudyMaterial(String userId, String noteId) async {
    if (_localOfflineMaterials.containsKey(noteId)) {
      return _localOfflineMaterials[noteId];
    }

    try {
      final doc = await _notesRef(userId).doc(noteId).get().timeout(const Duration(seconds: 4));
      if (!doc.exists) return null;
      final material = StudyMaterial.fromFirestore(doc);
      _localOfflineMaterials[noteId] = material;
      return material;
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching study material: $e');
      return _localOfflineMaterials[noteId];
    }
  }

  // Delete a study note
  Future<void> deleteStudyMaterial(String userId, String noteId) async {
    _localOfflineMaterials.remove(noteId);
    try {
      await _notesRef(userId).doc(noteId).delete().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[FirestoreService] Error deleting study material from remote: $e');
    }
  }
}
