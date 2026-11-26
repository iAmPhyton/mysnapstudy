import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/study_material.dart';
import 'firestore_service.dart';
import 'gemini_service.dart';

class StudyQueueTask {
  final String noteId;
  final String userId;
  final String title;
  final Uint8List imageBytes;
  final String mimeType;
  final String imageUrl;
  final String? customApiKey;
  int retryCount;
  final DateTime enqueuedAt;

  StudyQueueTask({
    required this.noteId,
    required this.userId,
    required this.title,
    required this.imageBytes,
    this.mimeType = 'image/jpeg',
    this.imageUrl = '',
    this.customApiKey,
    this.retryCount = 0,
    DateTime? enqueuedAt,
  }) : enqueuedAt = enqueuedAt ?? DateTime.now();
}

class StudyQueueService extends ChangeNotifier {
  static final StudyQueueService _instance = StudyQueueService._internal();
  factory StudyQueueService() => _instance;
  static StudyQueueService get instance => _instance;

  StudyQueueService._internal();

  final Queue<StudyQueueTask> _queue = Queue<StudyQueueTask>();
  final Map<String, Uint8List> _imageCache = <String, Uint8List>{};
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isProcessing = false;
  String? _currentlyProcessingId;

  bool get isProcessing => _isProcessing;
  int get queueLength => _queue.length;
  String? get currentlyProcessingId => _currentlyProcessingId;

  /// Enqueues a note photo for asynchronous background processing
  Future<void> enqueue({
    required String noteId,
    required String userId,
    required String title,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
    String imageUrl = '',
    String? customApiKey,
  }) async {
    // 1. Cache the image bytes in memory for instant retry if needed
    _imageCache[noteId] = imageBytes;

    // Guard imageUrl so large base64 data URIs never exceed Firestore's 1 MiB limit
    final safeImageUrl = imageUrl.length > 700000 ? '' : imageUrl;

    // 2. Immediately create / save document in Firestore with 'queued' status
    final now = DateTime.now();
    final initialMaterial = StudyMaterial(
      id: noteId,
      userId: userId,
      title: title,
      imageUrl: safeImageUrl,
      summary: 'AI study generation queued. Processing in background to prevent server overload...',
      notes: '',
      flashcards: [],
      quiz: [],
      status: 'queued',
      errorMessage: null,
      createdAt: now,
      updatedAt: now,
    );

    await _firestoreService.saveStudyMaterial(initialMaterial);

    // 3. Add task to background queue
    final task = StudyQueueTask(
      noteId: noteId,
      userId: userId,
      title: title,
      imageBytes: imageBytes,
      mimeType: mimeType,
      imageUrl: imageUrl,
      customApiKey: customApiKey,
    );

    _queue.add(task);
    notifyListeners();

    debugPrint('[StudyQueue] Enqueued note "$title" (ID: $noteId). Queue depth: ${_queue.length}');

    // 4. Trigger processing loop if not already running
    _processNext();
  }

  /// Re-enqueues a failed note
  Future<bool> retry(StudyMaterial material, {String? customApiKey}) async {
    Uint8List? bytes = _imageCache[material.id];

    // If not in RAM, try to decode from data URI if present
    if (bytes == null && material.imageUrl.startsWith('data:')) {
      try {
        final commaIndex = material.imageUrl.indexOf(',');
        if (commaIndex != -1) {
          final b64 = material.imageUrl.substring(commaIndex + 1);
          bytes = base64Decode(b64);
          _imageCache[material.id] = bytes;
        }
      } catch (e) {
        debugPrint('[StudyQueue] Error decoding base64 image: $e');
      }
    }

    if (bytes == null) {
      debugPrint('[StudyQueue] Cannot retry note ${material.id}: photo bytes not available in cache.');
      return false;
    }

    // Reset status in Firestore to 'queued'
    final updated = StudyMaterial(
      id: material.id,
      userId: material.userId,
      title: material.title,
      imageUrl: material.imageUrl,
      summary: 'Retrying AI study generation in background...',
      notes: '',
      flashcards: [],
      quiz: [],
      status: 'queued',
      errorMessage: null,
      createdAt: material.createdAt,
      updatedAt: DateTime.now(),
    );
    await _firestoreService.saveStudyMaterial(updated);

    final task = StudyQueueTask(
      noteId: material.id,
      userId: material.userId,
      title: material.title,
      imageBytes: bytes,
      imageUrl: material.imageUrl,
      customApiKey: customApiKey,
      retryCount: 0,
    );

    _queue.add(task);
    notifyListeners();
    _processNext();
    return true;
  }

  String _cleanImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return url.length > 700000 ? '' : url;
  }

  /// Core sequential processing loop with rate limiting and exponential backoff
  Future<void> _processNext() async {
    if (_isProcessing || _queue.isEmpty) {
      return;
    }

    _isProcessing = true;
    final task = _queue.removeFirst();
    _currentlyProcessingId = task.noteId;
    notifyListeners();

    debugPrint('[StudyQueue] Processing task ${task.noteId} (Attempt ${task.retryCount + 1})...');

    try {
      // 1. Update status to 'processing' in Firestore
      final existing = await _firestoreService.getStudyMaterial(task.userId, task.noteId);
      final rawImg = task.imageUrl.isNotEmpty ? task.imageUrl : (existing?.imageUrl ?? '');
      final currentImageUrl = _cleanImageUrl(rawImg);

      final processingMaterial = StudyMaterial(
        id: task.noteId,
        userId: task.userId,
        title: task.title,
        imageUrl: currentImageUrl,
        summary: 'Gemini AI is analyzing your notes & generating study materials...',
        notes: existing?.notes ?? '',
        flashcards: existing?.flashcards ?? [],
        quiz: existing?.quiz ?? [],
        status: 'processing',
        errorMessage: null,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestoreService.saveStudyMaterial(processingMaterial);

      // 2. Call Gemini service
      final result = await _geminiService.processNoteImage(
        imageBytes: task.imageBytes,
        mimeType: task.mimeType,
        customApiKey: task.customApiKey,
      );

      // 3. Success! Save completed material to Firestore
      final completedMaterial = StudyMaterial(
        id: task.noteId,
        userId: task.userId,
        title: task.title,
        imageUrl: currentImageUrl,
        summary: result.summary,
        notes: result.notes,
        flashcards: result.flashcards,
        quiz: result.quiz,
        status: 'completed',
        errorMessage: null,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.saveStudyMaterial(completedMaterial);
      debugPrint('[StudyQueue] Successfully completed note ${task.noteId}!');

      // Free cache memory for completed note
      _imageCache.remove(task.noteId);
    } catch (e) {
      debugPrint('[StudyQueue] Error processing note ${task.noteId}: $e');

      // Check if eligible for backoff retry (up to 4 retries for traffic spikes / 503)
      final errorStr = e.toString();
      final isDemandSpike = errorStr.contains('503') ||
          errorStr.contains('high demand') ||
          errorStr.contains('temporarily busy') ||
          errorStr.contains('RESOURCE_EXHAUSTED');

      if (isDemandSpike && task.retryCount < 4) {
        task.retryCount++;
        final backoffSeconds = 4 * task.retryCount;
        debugPrint('[StudyQueue] 503 Spike detected. Scheduling retry #${task.retryCount} in ${backoffSeconds}s for note ${task.noteId}...');

        // Update status in Firestore to notify user of backoff wait
        final existing = await _firestoreService.getStudyMaterial(task.userId, task.noteId);
        final rawImg = task.imageUrl.isNotEmpty ? task.imageUrl : (existing?.imageUrl ?? '');
        final currentImageUrl = _cleanImageUrl(rawImg);

        final waitingMaterial = StudyMaterial(
          id: task.noteId,
          userId: task.userId,
          title: task.title,
          imageUrl: currentImageUrl,
          summary: 'Gemini service is busy (traffic spike). Auto-retrying in ${backoffSeconds}s (attempt ${task.retryCount}/4)...',
          notes: existing?.notes ?? '',
          flashcards: existing?.flashcards ?? [],
          quiz: existing?.quiz ?? [],
          status: 'queued',
          errorMessage: 'Demand spike: retrying automatically (${task.retryCount}/4)',
          createdAt: existing?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _firestoreService.saveStudyMaterial(waitingMaterial);

        // Put back at front of queue after delay
        Future.delayed(Duration(seconds: backoffSeconds), () {
          _queue.addFirst(task);
          _processNext();
        });
      } else {
        // Retries exhausted or non-retryable error: mark as failed
        final existing = await _firestoreService.getStudyMaterial(task.userId, task.noteId);
        final rawImg = task.imageUrl.isNotEmpty ? task.imageUrl : (existing?.imageUrl ?? '');
        final currentImageUrl = _cleanImageUrl(rawImg);

        final failedMaterial = StudyMaterial(
          id: task.noteId,
          userId: task.userId,
          title: task.title,
          imageUrl: currentImageUrl,
          summary: 'AI generation paused due to high server demand. Please tap "Retry" to process.',
          notes: existing?.notes ?? '',
          flashcards: existing?.flashcards ?? [],
          quiz: existing?.quiz ?? [],
          status: 'failed',
          errorMessage: errorStr.length > 300 ? errorStr.substring(0, 300) : errorStr,
          createdAt: existing?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _firestoreService.saveStudyMaterial(failedMaterial);
      }
    } finally {
      // 4. Rate-limiting interval: Wait 2.5 seconds between jobs to reduce traffic spikes
      await Future.delayed(const Duration(milliseconds: 2500));
      _isProcessing = false;
      _currentlyProcessingId = null;
      notifyListeners();

      // Process next item in queue
      _processNext();
    }
  }
}
