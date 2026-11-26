# MySnapStudy
> **Snap a photo. Master the subject. AI study packs in seconds.**

MySnapStudy is an intelligent, cross-platform study companion built with Flutter, Firebase, and Gemini Multimodal AI. SnapStudy transforms photos of handwritten notes, textbook pages, and lecture slides into an all-in-one interactive study deck: **Executive Summaries**, **Structured Markdown Notes**, **Active Recall Flashcards**, and **Self-Grading Quizzes**.

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-AI%20Logic-FFCA28?logo=firebase)](https://firebase.google.com/docs/ai-logic)
[![Gemini](https://img.shields.io/badge/Google-Gemini%20Multimodal-4285F4?logo=google)](https://ai.google.dev)

---

## Value Proposition

Active recall and spaced repetition are scientifically proven to be the most effective study methods. However, manually transcribing notes into flashcards, creating summaries, and authoring practice test questions takes hours—often 3 to 4 times longer than the actual study session itself. Over 80% of students fall back on passive rereading, the least effective study technique.

**MySnapStudy eliminates this friction entirely:**
1. **Sub-Second Upload Friction:** Snap a picture of ANY note and tap "Generate". Notes are queued and stored on-device without blocking your screen.
2. **4-in-1 Study Ecosystem:** A single photo generates an Executive Summary, formatted Markdown study notes, flip flashcards, and an auto-graded quiz with explanations.
3. **Resilient Background Queue:** Built-in sequential rate pacing (2.5s intervals) and automatic exponential backoff retry (`4s`, `8s`, `16s`, `32s`) gracefully absorb API 503 traffic spikes without failing.
4. **Zero-Setup Cloud Storage:** Multi-provider storage supporting Cloudflare R2 (zero egress fees) and instant embedded fallbacks.

---

## Firebase AI Logic Integration (Runtime Architecture)

MySnapStudy demonstrates the direct runtime use of **Firebase AI Logic** via the official `package:firebase_ai` SDK.

### How It Is Imported & Called at Runtime:
In [`lib/services/firebase_ai_service.dart`](lib/services/firebase_ai_service.dart), the application interfaces directly with the Firebase AI client SDK:

```dart
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAIService {
  GenerativeModel _getModel(String modelName) {
    // 1. Initialize Firebase AI Logic with authenticated user identity
    final googleAI = FirebaseAI.googleAI(auth: FirebaseAuth.instance);
    
    // 2. Instantiate generative model with structured JSON response schema
    return googleAI.generativeModel(
      model: modelName,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        responseMimeType: 'application/json',
      ),
    );
  }

  Future<Map<String, dynamic>> processNoteImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    // 3. Assemble multimodal parts using InlineDataPart
    final content = [
      Content.multi([
        TextPart(promptText),
        InlineDataPart(mimeType, imageBytes),
      ]),
    ];

    // 4. Execute generative multimodal inference at runtime
    final model = _getModel('gemini-flash-lite-latest');
    final response = await model.generateContent(content);
    return jsonDecode(response.text!);
  }
}
```

The app pairs this with `gemini_service.dart` in a dual-engine architecture, ensuring maximum availability across both Firebase AI Logic client SDKs and direct Gemini developer endpoints.

## Gemini Nano 4 On-Device: Offline Commuter Recall & Study Hints

MySnapStudy implements a **hybrid cloud-and-edge AI architecture**:
- **Cloud Heavy Ingestion:** Heavy multimodal note photo parsing, high-resolution OCR, lecture synthesis, structured markdown generation, flashcard extraction, and initial quiz authoring run in the cloud using **Gemini Flash** via `FirebaseAIService` and `GeminiService`.
- **On-Device Offline Edge (`GeminiNanoService`):** High-frequency active recall evaluations and interactive hints run 100% locally on-device using **Gemini Nano 4** (AICore / on-device neural edge runtime).

```
   ┌────────────────────────────────────────────────────────┐
   │                   CLOUD WORKLOAD                      │
   │  • Multimodal Note Image Processing                    │
   │  • 2-3 Paragraph Executive Summary                     │
   │  • Structured Markdown Notes Extraction                │
   │  • High-Yield Flashcards & Quiz Generation             │
   │  (Powered by Gemini Flash & Firebase AI Logic)         │
   └──────────────────────────┬─────────────────────────────┘
                              │ Pre-computed Deck & Rubrics
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │              ON-DEVICE GEMINI NANO 4 EDGE              │
   │  • Instant Short-Answer Evaluation (<60ms latency)     │
   │  • Semantic Rubric & Key Concept Coverage Analysis     │
   │  • Tiered Scaffolding Hints (Socratic ➔ Clue ➔ Guide)  │
   │  • Real-time Dynamic Draft Feedback                    │
   │  • 100% Offline: Subway, Commutes, Flights, Zero Data  │
   └────────────────────────────────────────────────────────┘
```

### Key Capabilities of On-Device Gemini Nano 4:
1. **Sub-100ms Instant Evaluation:** While commuting on trains, subways, or buses with spotty cellular reception, students test their active recall by answering in their own words. Gemini Nano 4 evaluates the response locally in ~30–60ms without server roundtrips or battery drain.
2. **Semantic Understanding vs Exact Match:** Evaluates conceptual meaning, recognizes synonyms, detects misconceptions, and awards partial credit based on essential concept coverage (`identifiedConcepts` vs `missingConcepts`).
3. **Interactive Progressive Study Hints:**
   - **Level 1 (Socratic Nudge):** Prompts the student with a high-level conceptual question without spoiling the answer.
   - **Level 2 (Conceptual Clue):** Highlights key mechanisms, formulas, or terminology.
   - **Level 3 (Structural Guide):** Provides a guiding sentence framework or exemplar structure.
   - **Draft Insight:** Evaluates the student's partially typed answer in real time to suggest how to complete their thought.
4. **Offline Commuter Badge & Dual Quiz Engine:** Students can seamlessly switch between classic Multiple Choice and active Short-Answer Recall with live offline readiness indicators.

---

## System Architecture

```mermaid
graph TD
    A[Student Snaps Note Photo] --> B[MySnapStudy Flutter App]
    B -->|Non-Blocking Enqueue| Q[StudyQueueService]
    Q -->|Paced Cloud Ingestion| FAI[Firebase AI Logic / Gemini Flash]
    FAI -->|Structured Study Pack & Nano Rubrics| Q
    Q -->|Persist Completed Deck| FS[Cloud Firestore: users/{userId}/notes]
    B -->|Reactive Real-Time Stream| FS
    B -->|Photo Asset Storage| R2[Cloudflare R2 / Free Tier Storage]
    B -->|Offline Short-Answer Evaluation| NANO[Gemini Nano 4 On-Device AICore]
    B -->|Interactive Progressive Hints| NANO
    U[Google Sign-In] --> FA[Firebase Authentication]
    FA -->|Strict Owner Isolation| SR[Firestore Security Rules]
```

### Key Components:
- **`GeminiNanoService`:** On-device edge inference service executing short-answer semantic evaluations and progressive hints with 0ms network latency.
- **`StudyQueueService`:** Non-blocking sequential job runner that processes notes in the background, pacing requests and deploying exponential backoff on demand spikes.
- **`Cloud Firestore`:** User-scoped document storage under `/users/{userId}/notes/{noteId}` with live real-time sync.
- **`Security Rules`:** Validated with the Validator Function Pattern, default-deny root, and owner isolation.
- **`StudyViewScreen`:** Interactive 4-tab study deck featuring 3D card flips, multiple-choice testing, and on-device Gemini Nano 4 short-answer recall.

---

## Repository Structure

```
mysnapstudy/
├── LICENSE                         # Apache License 2.0
├── README.md                       # Comprehensive project documentation
├── firebase.json                   # Firebase deployment configuration
├── firestore.rules                 # Strict security rules under users/{userId}/**
├── firestore.indexes.json          # Firestore indexes configuration
├── storage.rules                   # Storage access security rules
├── pubspec.yaml                    # Flutter dependencies (firebase_ai, firestore, auth)
├── web/
│   ├── index.html                  # Web bootstrap and manifest configuration
│   └── manifest.json               # Web PWA manifest
├── test/
│   └── gemini_nano_service_test.dart# Full test suite for Gemini Nano on-device evaluation & hints
├── lib/
│   ├── firebase_options.dart       # DefaultFirebaseOptions wired for snapstudy-hackathon
│   ├── main.dart                   # App entrypoint with Firebase.initializeApp and Providers
│   ├── models/
│   │   └── study_material.dart     # Domain models: FlashcardItem, QuizQuestion, ShortAnswerEvaluation, StudyHint
│   ├── services/
│   │   ├── gemini_nano_service.dart# On-device Gemini Nano 4 evaluation and hint generation engine
│   │   ├── firebase_ai_service.dart# Runtime Firebase AI Logic SDK implementation
│   │   ├── gemini_service.dart     # Multimodal AI processing pipeline with model rotation
│   │   ├── study_queue_service.dart# Asynchronous background rate-paced queue
│   │   ├── auth_service.dart       # Google Sign-In, sign-out, auth state stream
│   │   ├── firestore_service.dart  # Type-safe Firestore CRUD under users/{userId}/**
│   │   ├── storage_service.dart    # Storage router supporting Cloudflare R2 & fallbacks
│   │   └── cloudflare_storage_service.dart # Cloudflare R2 object storage service
│   ├── screens/
│   │   ├── auth_gate.dart          # Route & view protection based on auth state
│   │   ├── login_screen.dart       # Google Sign-In UI with Material 3 styling
│   │   ├── home_screen.dart        # Dashboard of recent study sets & live queue banner
│   │   ├── upload_notes_screen.dart# Camera/gallery capture & non-blocking queue trigger
│   │   └── study_view_screen.dart  # Interactive 4-tab study deck (Summary, Notes, Cards, Quiz)
│   └── widgets/
│       ├── study_image.dart        # Universal image renderer (R2 URLs & Base64 data URIs)
│       └── cloudflare_settings_dialog.dart # Storage provider configuration dialog
```

---

## Getting Started

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.24.0)
- [Node.js](https://nodejs.org/) (>= 18)
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools` or `npx firebase-tools`)

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Deploy Firestore Security Rules
```bash
npx -y firebase-tools@latest deploy --only firestore:rules --project snapstudy-hackathon
```

### 4. Run the Application
Run in your browser or target device:
```bash
# Run on Web (Edge)
flutter run -d chrome --dart-define=GEMINI_API_KEY="your-gemini-api-key"

# Or build the production web bundle
flutter build web --dart-define=GEMINI_API_KEY="your-gemini-api-key"
```

---

## License

This project is licensed under the **Apache License, Version 2.0** - see the [LICENSE](LICENSE) file for details.
