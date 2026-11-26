import 'package:flutter_test/flutter_test.dart';
import 'package:snapstudy/models/study_material.dart';
import 'package:snapstudy/services/gemini_nano_service.dart';

void main() {
  group('GeminiNanoService On-Device Offline Tests', () {
    late GeminiNanoService nanoService;

    setUp(() {
      nanoService = GeminiNanoService();
    });

    test('Availability probe initializes on-device runtime', () async {
      final available = await nanoService.checkAvailability();
      expect(available, isTrue);
      expect(nanoService.isAvailable, isTrue);
      expect(nanoService.hardwareStatus, isNotEmpty);
    });

    test('Evaluates accurate short-answer response correctly with high score', () async {
      final eval = await nanoService.evaluateShortAnswer(
        question: 'What is the primary function of the mitochondria in eukaryotic cells?',
        studentAnswer: 'The mitochondria produces ATP cellular energy through aerobic cellular respiration.',
        referenceAnswer: 'Mitochondria generate most of the cell\'s chemical energy in the form of ATP through cellular respiration.',
        keyConcepts: ['ATP production', 'cellular respiration', 'energy'],
      );

      expect(eval.isOffline, isTrue);
      expect(eval.modelUsed, contains('Gemini Nano 4'));
      expect(eval.score, greaterThanOrEqualTo(80));
      expect(eval.status, NanoEvaluationStatus.correct);
      expect(eval.identifiedConcepts, isNotEmpty);
      expect(eval.feedback, contains('Spot on'));
      expect(eval.latencyMs, greaterThanOrEqualTo(0));
    });

    test('Evaluates partial short-answer and identifies missing concepts', () async {
      final eval = await nanoService.evaluateShortAnswer(
        question: 'Explain Newton\'s second law of motion and its formula.',
        studentAnswer: 'It states that force depends on mass.',
        referenceAnswer: 'Force equals mass times acceleration (F = m * a).',
        keyConcepts: ['mass', 'acceleration', 'force equals mass times acceleration'],
      );

      expect(eval.isOffline, isTrue);
      expect(eval.status, NanoEvaluationStatus.partial);
      expect(eval.score, inInclusiveRange(45, 84));
      expect(eval.identifiedConcepts, contains('mass'));
      expect(eval.missingConcepts, contains('acceleration'));
      expect(eval.feedback, contains('Great effort'));
    });

    test('Evaluates off-topic or empty answer as needing review', () async {
      final eval = await nanoService.evaluateShortAnswer(
        question: 'What causes photosynthesis in plant leaves?',
        studentAnswer: "i don't know sorry",
        referenceAnswer: 'Chloroplasts absorb sunlight via chlorophyll to convert water and carbon dioxide into glucose and oxygen.',
        keyConcepts: ['chloroplasts', 'chlorophyll', 'sunlight'],
      );

      expect(eval.isOffline, isTrue);
      expect(eval.status, NanoEvaluationStatus.incorrect);
      expect(eval.score, lessThan(40));
      expect(eval.feedback, contains('Don\'t worry'));
    });

    test('Generates progressive tiered hints (Levels 1, 2, 3)', () async {
      // Level 1: Socratic nudge
      final hint1 = await nanoService.generateStudyHint(
        question: 'What is the role of ribosomes?',
        referenceAnswer: 'Ribosomes translate mRNA to synthesize proteins in the cell.',
        hintLevel: 1,
        keyConcepts: ['protein synthesis', 'translation'],
      );
      expect(hint1.level, equals(1));
      expect(hint1.text, isNotEmpty);
      expect(hint1.title, contains('Socratic'));

      // Level 2: Conceptual clue
      final hint2 = await nanoService.generateStudyHint(
        question: 'What is the role of ribosomes?',
        referenceAnswer: 'Ribosomes translate mRNA to synthesize proteins in the cell.',
        hintLevel: 2,
        keyConcepts: ['protein synthesis', 'translation'],
      );
      expect(hint2.level, equals(2));
      expect(hint2.text, isNotEmpty);
      expect(hint2.title, contains('Conceptual'));

      // Level 3: Structural guide
      final hint3 = await nanoService.generateStudyHint(
        question: 'What is the role of ribosomes?',
        referenceAnswer: 'Ribosomes translate mRNA to synthesize proteins in the cell.',
        hintLevel: 3,
        keyConcepts: ['protein synthesis', 'translation'],
      );
      expect(hint3.level, equals(3));
      expect(hint3.text, isNotEmpty);
      expect(hint3.title, contains('Structural'));
    });

    test('Generates real-time personalized hint on student partial draft', () async {
      final hint = await nanoService.generateStudyHint(
        question: 'How do enzymes accelerate chemical reactions?',
        referenceAnswer: 'Enzymes lower the activation energy required for a chemical reaction to occur.',
        hintLevel: 1,
        keyConcepts: ['activation energy', 'catalyst'],
        studentDraft: 'They act as a biological catalyst to speed things up',
      );

      expect(hint.isPersonalized, isTrue);
      expect(hint.title, contains('Draft Insight'));
      expect(hint.text, contains('catalyst'));
    });
  });

  group('StudyMaterial Quiz Model Backwards Compatibility', () {
    test('QuizQuestion parses both legacy and enhanced short-answer rubrics', () {
      // Legacy quiz question without sampleAnswer or keyConcepts
      final legacyMap = {
        'question': 'What is the capital of France?',
        'options': ['London', 'Berlin', 'Paris', 'Madrid'],
        'correctAnswerIndex': 2,
        'explanation': 'Paris is the capital of France.',
      };

      final legacyQuestion = QuizQuestion.fromMap(legacyMap);
      expect(legacyQuestion.question, 'What is the capital of France?');
      expect(legacyQuestion.sampleAnswer, 'Paris'); // Auto-defaulted to correct option!
      expect(legacyQuestion.keyConcepts, isEmpty);
      expect(legacyQuestion.hints, isEmpty);

      // Enhanced quiz question with full rubrics
      final enhancedMap = {
        'question': 'Define osmosis.',
        'options': ['Active transport', 'Diffusion of water', 'Endocytosis', 'Exocytosis'],
        'correctAnswerIndex': 1,
        'explanation': 'Osmosis is the net movement of water across a semipermeable membrane.',
        'sampleAnswer': 'Osmosis is the spontaneous passive diffusion of water molecules through a selectively permeable membrane.',
        'keyConcepts': ['water diffusion', 'semipermeable membrane', 'concentration gradient'],
        'hints': [
          'Think about which specific molecule moves and whether it requires ATP.',
          'It is a special case of passive diffusion across a selective barrier.',
          'Formula: Water moves from low solute concentration to high solute concentration.',
        ],
      };

      final enhancedQuestion = QuizQuestion.fromMap(enhancedMap);
      expect(enhancedQuestion.sampleAnswer, contains('selectively permeable membrane'));
      expect(enhancedQuestion.keyConcepts.length, 3);
      expect(enhancedQuestion.hints.length, 3);

      final exportedMap = enhancedQuestion.toMap();
      expect(exportedMap['sampleAnswer'], equals(enhancedQuestion.sampleAnswer));
      expect(exportedMap['keyConcepts'], equals(enhancedQuestion.keyConcepts));
      expect(exportedMap['hints'], equals(enhancedQuestion.hints));
    });
  });
}
