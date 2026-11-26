import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase AI Logic Service
/// Implements multimodal inference via Firebase AI Logic (Gemini Developer API)
/// client SDKs with runtime App Check / Firebase Auth identity integration.
class FirebaseAIService {
  static final FirebaseAIService _instance = FirebaseAIService._internal();
  factory FirebaseAIService() => _instance;
  FirebaseAIService._internal();

  // Active models supported by Firebase AI Logic
  static const List<String> _models = [
    'gemini-flash-lite-latest',
    'gemini-3.5-flash-lite',
  ];

  GenerativeModel _getModel(String modelName) {
    // Initialize Firebase AI Logic (Google AI Developer API provider)
    final googleAI = FirebaseAI.googleAI(auth: FirebaseAuth.instance);
    return googleAI.generativeModel(
      model: modelName,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        responseMimeType: 'application/json',
      ),
    );
  }

  /// Extracts structured study materials from an uploaded note photo using Firebase AI Logic
  Future<Map<String, dynamic>> processNoteImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    const promptText = '''
You are an expert AI study companion powered by Firebase AI Logic.
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

Ensure the output is strictly valid JSON without markdown fences.
''';

    final content = [
      Content.multi([
        TextPart(promptText),
        InlineDataPart(mimeType, imageBytes),
      ]),
    ];

    Object? lastError;
    for (final modelName in _models) {
      try {
        debugPrint('[Firebase AI Logic] Processing notes with model: $modelName...');
        final model = _getModel(modelName);
        final response = await model.generateContent(content);
        final rawText = response.text?.trim() ?? '';

        if (rawText.isEmpty) {
          throw Exception('Firebase AI Logic returned empty response from $modelName');
        }

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
          throw FormatException('Expected JSON map, got: $decoded');
        }

        return decoded;
      } catch (e) {
        lastError = e;
        debugPrint('[Firebase AI Logic] Model $modelName notice: $e');
      }
    }

    throw Exception('Firebase AI Logic service error: $lastError');
  }
}
