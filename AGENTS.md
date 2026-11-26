# AGENTS.md - SnapStudy Developer & Agent Rules

This document outlines the architecture, coding standards, development workflows, and conventions for AI agents and human contributors working on **SnapStudy**.

---

## 1. Project Overview

- **Project Name:** SnapStudy
- **Description:** An intelligent study companion application designed to help students capture, organize, and study learning materials (notes, flashcards, summaries, and quizzes) powered by Flutter, Firebase, and Gemini Multimodal AI.
- **Core Mission:** Accelerate learning and retention through intuitive capture and AI-driven study tools.
- **Firebase Project:** `snapstudy-hackathon`

---

## 2. Tech Stack & Environment

- **Platform:** Cross-platform (Flutter Web, Android, iOS, macOS, Windows)
- **Language / Runtime:** Dart (Flutter SDK >= 3.24.0)
- **Backend Services:**
  - **Firebase Authentication:** Google Sign-In, reactive state streams
  - **Cloud Firestore:** Document database, user-isolated collection tree (`users/{userId}/**`)
  - **Cloud Storage:** Photo storage under `users/{userId}/notes/`
  - **Gemini API & Hybrid Edge AI:**
    - **Cloud Ingestion:** Gemini Flash (`gemini-flash-lite-latest` / `gemini-3.5-flash-lite`) via Firebase AI Logic and Google Generative AI for heavy multimodal note processing and study pack extraction.
    - **On-Device Offline Edge:** Gemini Nano 4 (`GeminiNanoService`) for sub-100ms offline short-answer evaluation, semantic rubric grading, and interactive progressive scaffolding hints during commutes.
- **State Management:** Provider / StreamBuilder
- **Package Manager:** `flutter pub`

---

## 3. Development Workflow & Commands

| Task | Command | Description |
| :--- | :--- | :--- |
| **Install Dependencies** | `flutter pub get` | Install Dart & Flutter packages |
| **Dev Server (Web)** | `flutter run -d chrome` | Start Web development session |
| **Run Native** | `flutter run` | Start mobile / desktop app |
| **Build Web** | `flutter build web` | Produce web build artifacts |
| **Lint / Analyze** | `flutter analyze` | Run Dart analyzer checks |
| **Test** | `flutter test` | Run widget and unit tests |
| **Deploy Rules** | `npx -y firebase-tools@latest deploy --only firestore:rules,storage` | Deploy security rules to Firebase |

---

## 4. Coding Conventions & Best Practices

- **Code Quality:**
  - Strong typing with explicit models (`StudyMaterial`, `FlashcardItem`, `QuizQuestion`).
  - Separation of concerns: UI in `lib/screens/`, logic/backends in `lib/services/`, data contracts in `lib/models/`.
  - Follow Flutter Material 3 guidelines and responsive layout principles.
- **Security & Authorization:**
  - All user-specific Firestore documents and Storage objects MUST be scoped under `users/{userId}/**`.
  - Never allow unauthenticated reads or cross-user writes in `firestore.rules` or `storage.rules`.
  - Do not hardcode secret keys in client code; use `--dart-define` or runtime entry.
- **Cross-Platform Authentication:**
  - On Flutter Web, use `signInWithPopup(GoogleAuthProvider())` to avoid DWDS assertion crashes.
  - On Mobile, use `GoogleSignIn.instance.signIn()` and pass credentials to `FirebaseAuth`.

---

## 5. Guidelines for AI Agents

1. **Verify Before and After:**
   - Inspect project structure and existing patterns before making changes.
   - Run `flutter analyze` or verification commands when tools are present.
2. **Security Rules Authoring:**
   - Any modifications to Firestore Security Rules (`firestore.rules`) MUST adhere to the Validator Function Pattern, default-deny at root, and ownership isolation.
3. **Documentation:**
   - Keep this file and `README.md` updated as new features or endpoints are added.
