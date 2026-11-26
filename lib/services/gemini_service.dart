import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/study_material.dart';
import 'firebase_ai_service.dart';
import 'gemini_nano_service.dart';

class GeminiProcessedResult {
  final String summary;
  final String notes;
  final List<FlashcardItem> flashcards;
  final List<QuizQuestion> quiz;
  final bool isOfflineFallback;

  GeminiProcessedResult({
    required this.summary,
    required this.notes,
    required this.flashcards,
    required this.quiz,
    this.isOfflineFallback = false,
  });
}

class GeminiService {
  static String? savedApiKey = const String.fromEnvironment('GEMINI_API_KEY').isNotEmpty
      ? const String.fromEnvironment('GEMINI_API_KEY')
      : null;
  final String? _apiKey;

  // Verified working models for generateContent with lowest latency and multimodal vision support
  static const List<String> _candidateModels = [
    'gemini-flash-lite-latest',
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
  ];

  GeminiService({String? apiKey})
      : _apiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY');

  GenerativeModel _getModel(String modelName, String apiKey) {
    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        responseMimeType: 'application/json',
      ),
    );
  }

  GeminiProcessedResult parseDecodedResult(Map<String, dynamic> decoded, {bool isOfflineFallback = false}) {
    final summary = decoded['summary'] as String? ?? 'No summary generated.';
    final notes = decoded['notes'] as String? ?? 'No notes generated.';

    final List<FlashcardItem> flashcards = [];
    if (decoded['flashcards'] is List) {
      for (var item in decoded['flashcards']) {
        if (item is Map<String, dynamic>) {
          flashcards.add(FlashcardItem.fromMap(item));
        }
      }
    }

    final List<QuizQuestion> quiz = [];
    if (decoded['quiz'] is List) {
      for (var item in decoded['quiz']) {
        if (item is Map<String, dynamic>) {
          quiz.add(QuizQuestion.fromMap(item));
        }
      }
    }

    return GeminiProcessedResult(
      summary: summary,
      notes: notes,
      flashcards: flashcards,
      quiz: quiz,
      isOfflineFallback: isOfflineFallback,
    );
  }

  /// Analyzes an uploaded image of student notes or textbook material
  /// and produces a structured JSON containing: summary, notes, flashcards, and quiz.
  Future<GeminiProcessedResult> processNoteImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
    String? customApiKey,
    String noteTitle = 'Study Notes',
  }) async {
    // 1. Primary runtime engine: Firebase AI Logic (client-side Gemini Developer API SDK)
    try {
      debugPrint('[SnapStudy] Invoking Firebase AI Logic (firebase_ai) runtime...');
      final decoded = await FirebaseAIService().processNoteImage(
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
      return parseDecodedResult(decoded, isOfflineFallback: false);
    } catch (firebaseAiError) {
      debugPrint('[Firebase AI Logic] Notice: $firebaseAiError - falling back to direct endpoint.');
    }

    // 2. Direct Gemini endpoint fallback
    final key = customApiKey ?? savedApiKey ?? _apiKey;
    if (key == null || key.isEmpty) {
      debugPrint('[SnapStudy] No API key provided. Activating Gemini Nano 4 On-Device engine...');
      final onDevicePack = await GeminiNanoService().generateOfflineStudyPack(
        title: noteTitle,
        imageBytes: imageBytes,
      );
      return parseDecodedResult(onDevicePack, isOfflineFallback: true);
    }

    const promptText = '''
You are an expert AI study companion designed to accelerate learning for students.
Analyze this photo of student study notes, blackboard/whiteboard, lecture slides, or textbook page carefully.
Extract all key topics, concepts, terms, definitions, equations, and details.

You MUST respond with a single valid JSON object containing EXACTLY these top-level keys:
1. "summary": A comprehensive 2-3 paragraph synthesis summarizing the core concepts.
2. "notes": Clean, structured, well-organized markdown formatted study notes with headings, bullet points, key takeaways, and key definitions.
3. "flashcards": An array of objects, where each object has:
   - "front": A concise question, term, or prompt
   - "back": A clear, accurate answer or definition
   (Generate between 5 to 10 high-yield flashcards)
4. "quiz": An array of quiz question objects designed for both multiple-choice and offline on-device short-answer evaluation, where each object has:
   - "question": The question text
   - "options": An array of exactly 4 plausible choices (strings)
   - "correctAnswerIndex": Integer (0, 1, 2, or 3) indicating the zero-based index of the correct option
   - "explanation": A helpful 1-2 sentence explanation of why the correct option is right
   - "sampleAnswer": An exemplary short-answer sentence answering the question completely for on-device recall evaluation
   - "keyConcepts": An array of 2 to 4 essential keywords or concept phrases that a student's short answer must address
   - "hints": An array of exactly 3 progressive hints:
     * Hint 1: A conceptual Socratic nudge that doesn't spoil the answer
     * Hint 2: Key terminology, mechanism, or clue
     * Hint 3: Structural breakdown or guiding formula
   (Generate between 4 to 8 questions)

Ensure the output is strictly valid JSON without any leading or trailing markdown fences or additional chatter.
''';

    final content = [
      Content.multi([
        TextPart(promptText),
        DataPart(mimeType, imageBytes),
      ]),
    ];

    Object? lastError;

    // Iterate through active models with retry and backoff on demand spikes
    for (final modelName in _candidateModels) {
      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          debugPrint('Processing with $modelName (attempt $attempt)...');
          final model = _getModel(modelName, key);
          final response = await model.generateContent(content);
          final rawText = response.text?.trim() ?? '';

          if (rawText.isEmpty) {
            throw Exception('Model $modelName returned an empty response.');
          }

          // Clean markdown code blocks if present
          String jsonClean = rawText;
          if (jsonClean.startsWith('```json')) {
            jsonClean = jsonClean.substring(7);
          } else if (jsonClean.startsWith('```')) {
            jsonClean = jsonClean.substring(3);
          }
          if (jsonClean.endsWith('```')) {
            jsonClean = jsonClean.substring(0, jsonClean.length - 3);
          }
          jsonClean = jsonClean.trim();

          final dynamic decoded = jsonDecode(jsonClean);
          if (decoded is! Map<String, dynamic>) {
            throw FormatException('Expected JSON object from Gemini, got: $decoded');
          }

          return parseDecodedResult(decoded, isOfflineFallback: false);
        } catch (e) {
          lastError = e;
          debugPrint('Model $modelName (attempt $attempt) error: $e');
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('api_key') || errStr.contains('401') || errStr.contains('unauthorized')) {
            break;
          }
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 1200 * attempt));
          }
        }
      }
    }

    debugPrint('[SnapStudy] Cloud generation unavailable ($lastError). Seamlessly falling back to Gemini Nano 4 On-Device engine...');
    final onDevicePack = await GeminiNanoService().generateOfflineStudyPack(
      title: noteTitle,
      imageBytes: imageBytes,
    );
    return parseDecodedResult(onDevicePack, isOfflineFallback: true);
  }
}
