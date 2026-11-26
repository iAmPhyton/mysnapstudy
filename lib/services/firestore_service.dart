import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/study_material.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Sync / create user profile document upon login
  Future<void> syncUserProfile(User user) async {
    try {
      final userRef = _db.collection('users').doc(user.uid);
      final doc = await userRef.get();

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
      debugPrint('Error syncing user profile: $e');
    }
  }

  // Collection reference for user notes: /users/{userId}/notes
  CollectionReference<Map<String, dynamic>> _notesRef(String userId) {
    return _db.collection('users').doc(userId).collection('notes');
  }

  // Create or update study notes
  Future<void> saveStudyMaterial(StudyMaterial material) async {
    try {
      final ref = _notesRef(material.userId).doc(material.id);
      await ref.set(material.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving study material: $e');
      rethrow;
    }
  }

  // Real-time stream of all notes for the authenticated user
  Stream<List<StudyMaterial>> getStudyMaterials(String userId) {
    return _notesRef(userId).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => StudyMaterial.fromFirestore(doc)).toList();
      // Sort client-side to avoid composite index requirements
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Fetch a single study note by ID
  Future<StudyMaterial?> getStudyMaterial(String userId, String noteId) async {
    try {
      final doc = await _notesRef(userId).doc(noteId).get();
      if (!doc.exists) return null;
      return StudyMaterial.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error fetching study material: $e');
      return null;
    }
  }

  // Delete a study note
  Future<void> deleteStudyMaterial(String userId, String noteId) async {
    try {
      await _notesRef(userId).doc(noteId).delete();
    } catch (e) {
      debugPrint('Error deleting study material: $e');
      rethrow;
    }
  }
}
