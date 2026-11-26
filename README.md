# SnapStudy
> **Snap a photo. Master the subject. AI study packs in seconds.**

SnapStudy is an intelligent, cross-platform study companion built with Flutter, Firebase, and Gemini Multimodal AI. SnapStudy transforms photos of handwritten notes, textbook pages, and lecture slides into an all-in-one interactive study deck: **Executive Summaries**, **Structured Markdown Notes**, **Active Recall Flashcards**, and **Self-Grading Quizzes**.

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-AI%20Logic-FFCA28?logo=firebase)](https://firebase.google.com/docs/ai-logic)
[![Gemini](https://img.shields.io/badge/Google-Gemini%20Multimodal-4285F4?logo=google)](https://ai.google.dev)

---

## Value Proposition

Active recall and spaced repetition are scientifically proven to be the most effective study methods. However, manually transcribing notes into flashcards, creating summaries, and authoring practice test questions takes hours—often 3 to 4 times longer than the actual study session itself. Over 80% of students fall back on passive rereading, the least effective study technique.

**SnapStudy eliminates this friction entirely:**
1. **Sub-Second Upload Friction:** Snap a picture and tap "Generate". Notes are queued and stored in under 1 second without blocking your screen.
2. **4-in-1 Study Ecosystem:** A single photo generates an Executive Summary, formatted Markdown study notes, flip flashcards, and an auto-graded quiz with explanations.
3. **Resilient Background Queue:** Built-in sequential rate pacing (2.5s intervals) and automatic exponential backoff retry (`4s`, `8s`, `16s`, `32s`) gracefully absorb API 503 traffic spikes without failing.
4. **Zero-Setup Cloud Storage:** Multi-provider storage supporting Cloudflare R2 (zero egress fees) and instant embedded fallbacks.

---

## Firebase AI Logic Integration (Runtime Architecture)

SnapStudy demonstrates the direct runtime use of **Firebase AI Logic** via the official `package:firebase_ai` SDK.

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

---

## System Architecture

```mermaid
graph TD
    A[Student Snaps Note Photo] --> B[SnapStudy Flutter App]
    B -->|Non-Blocking Enqueue| Q[StudyQueueService]
    Q -->|Paced Background Execution| FAI[Firebase AI Logic / Gemini Multimodal]
    FAI -->|Structured Study JSON| Q
    Q -->|Persist Completed Deck| FS[Cloud Firestore: users/{userId}/notes]
    B -->|Reactive Real-Time Stream| FS
    B -->|Photo Asset Storage| R2[Cloudflare R2 / Free Tier Storage]
    U[Google Sign-In] --> FA[Firebase Authentication]
    FA -->|Strict Owner Isolation| SR[Firestore Security Rules]
```

### Key Components:
- **`StudyQueueService`:** Non-blocking sequential job runner that processes notes in the background, pacing requests and deploying exponential backoff on demand spikes.
- **`Cloud Firestore`:** User-scoped document storage under `/users/{userId}/notes/{noteId}` with live real-time sync.
- **`Security Rules`:** Validated with the Validator Function Pattern, default-deny root, and owner isolation.
- **`StudyViewScreen`:** Interactive 4-tab study deck with 3D card flips and live quiz scoring.

---

## Repository Structure

```
snapstudy/
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
├── lib/
│   ├── firebase_options.dart       # DefaultFirebaseOptions wired for snapstudy-hackathon
│   ├── main.dart                   # App entrypoint with Firebase.initializeApp and Providers
│   ├── models/
│   │   └── study_material.dart     # Domain models: FlashcardItem, QuizQuestion, StudyMaterial
│   ├── services/
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
# Run on Web (Chrome)
flutter run -d chrome --dart-define=GEMINI_API_KEY="your-gemini-api-key"

# Or build the production web bundle
flutter build web --dart-define=GEMINI_API_KEY="your-gemini-api-key"
```

---

## License

This project is licensed under the **Apache License, Version 2.0** - see the [LICENSE](LICENSE) file for details.
