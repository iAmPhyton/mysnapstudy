import 'package:cloud_firestore/cloud_firestore.dart';

class FlashcardItem {
  final String front;
  final String back;

  FlashcardItem({
    required this.front,
    required this.back,
  });

  factory FlashcardItem.fromMap(Map<String, dynamic> map) {
    return FlashcardItem(
      front: map['front'] as String? ?? '',
      back: map['back'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'front': front,
      'back': back,
    };
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    List<String> parsedOptions = [];
    if (rawOptions is List) {
      parsedOptions = rawOptions.map((e) => e.toString()).toList();
    }
    return QuizQuestion(
      question: map['question'] as String? ?? '',
      options: parsedOptions,
      correctAnswerIndex: (map['correctAnswerIndex'] as num?)?.toInt() ?? 0,
      explanation: map['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
    };
  }
}

class StudyMaterial {
  final String id;
  final String userId;
  final String title;
  final String imageUrl;
  final String summary;
  final String notes;
  final List<FlashcardItem> flashcards;
  final List<QuizQuestion> quiz;
  final String status; // 'queued', 'processing', 'completed', 'failed'
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyMaterial({
    required this.id,
    required this.userId,
    required this.title,
    this.imageUrl = '',
    required this.summary,
    required this.notes,
    required this.flashcards,
    required this.quiz,
    this.status = 'completed',
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isQueued => status == 'queued';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isPending => isQueued || isProcessing;

  factory StudyMaterial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StudyMaterial.fromMap(data, doc.id);
  }

  factory StudyMaterial.fromMap(Map<String, dynamic> map, String docId) {
    final rawFlashcards = map['flashcards'];
    List<FlashcardItem> parsedFlashcards = [];
    if (rawFlashcards is List) {
      parsedFlashcards = rawFlashcards
          .whereType<Map<String, dynamic>>()
          .map((item) => FlashcardItem.fromMap(item))
          .toList();
    }

    final rawQuiz = map['quiz'];
    List<QuizQuestion> parsedQuiz = [];
    if (rawQuiz is List) {
      parsedQuiz = rawQuiz
          .whereType<Map<String, dynamic>>()
          .map((item) => QuizQuestion.fromMap(item))
          .toList();
    }

    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return StudyMaterial(
      id: docId,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled Study Notes',
      imageUrl: map['imageUrl'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      flashcards: parsedFlashcards,
      quiz: parsedQuiz,
      status: map['status'] as String? ?? 'completed',
      errorMessage: map['errorMessage'] as String?,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'imageUrl': imageUrl,
      'summary': summary,
      'notes': notes,
      'flashcards': flashcards.map((f) => f.toMap()).toList(),
      'quiz': quiz.map((q) => q.toMap()).toList(),
      'status': status,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
