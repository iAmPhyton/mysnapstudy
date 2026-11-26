import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/study_material.dart';
import '../services/gemini_nano_service.dart';
import '../widgets/study_image.dart';

class StudyViewScreen extends StatefulWidget {
  final StudyMaterial material;

  const StudyViewScreen({super.key, required this.material});

  @override
  State<StudyViewScreen> createState() => _StudyViewScreenState();
}

class _StudyViewScreenState extends State<StudyViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Flashcards state
  int _currentCardIndex = 0;
  bool _showCardBack = false;

  // Multiple Choice Quiz state
  int _currentQuizIndex = 0;
  int? _selectedAnswerIndex;
  bool _hasAnsweredCurrentQuiz = false;
  int _quizScore = 0;
  bool _quizFinished = false;

  // Quiz Mode: 'short_answer' (Gemini Nano 4 on-device) or 'multiple_choice'
  String _quizMode = 'short_answer';

  // Short-Answer Quiz State (Gemini Nano 4 On-Device)
  final TextEditingController _shortAnswerController = TextEditingController();
  final GeminiNanoService _nanoService = GeminiNanoService();
  int _currentShortAnswerIndex = 0;
  bool _isEvaluatingShortAnswer = false;
  ShortAnswerEvaluation? _currentEvaluation;
  StudyHint? _activeHint;
  int _currentHintLevel = 0;
  bool _isLoadingHint = false;
  bool _showReferenceAnswer = false;
  final Map<int, ShortAnswerEvaluation> _shortAnswerResults = {};
  bool _shortAnswerFinished = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _nanoService.checkAvailability();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shortAnswerController.dispose();
    super.dispose();
  }

  void _flipCard() {
    setState(() {
      _showCardBack = !_showCardBack;
    });
  }

  void _nextCard() {
    if (_currentCardIndex < widget.material.flashcards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _showCardBack = false;
      });
    }
  }

  void _prevCard() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _showCardBack = false;
      });
    }
  }

  void _selectQuizOption(int optionIndex) {
    if (_hasAnsweredCurrentQuiz || _quizFinished) return;

    final question = widget.material.quiz[_currentQuizIndex];
    final isCorrect = optionIndex == question.correctAnswerIndex;

    setState(() {
      _selectedAnswerIndex = optionIndex;
      _hasAnsweredCurrentQuiz = true;
      if (isCorrect) {
        _quizScore++;
      }
    });
  }

  void _nextQuizQuestion() {
    if (_currentQuizIndex < widget.material.quiz.length - 1) {
      setState(() {
        _currentQuizIndex++;
        _selectedAnswerIndex = null;
        _hasAnsweredCurrentQuiz = false;
      });
    } else {
      setState(() {
        _quizFinished = true;
      });
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentQuizIndex = 0;
      _selectedAnswerIndex = null;
      _hasAnsweredCurrentQuiz = false;
      _quizScore = 0;
      _quizFinished = false;
    });
  }

  Future<void> _evaluateCurrentShortAnswer() async {
    final questions = widget.material.quiz;
    if (_currentShortAnswerIndex >= questions.length) return;

    final question = questions[_currentShortAnswerIndex];
    final studentText = _shortAnswerController.text;

    setState(() {
      _isEvaluatingShortAnswer = true;
    });

    final evaluation = await _nanoService.evaluateShortAnswer(
      question: question.question,
      studentAnswer: studentText,
      referenceAnswer: question.sampleAnswer.isNotEmpty
          ? question.sampleAnswer
          : (question.options.isNotEmpty && question.correctAnswerIndex < question.options.length
              ? question.options[question.correctAnswerIndex]
              : question.explanation),
      keyConcepts: question.keyConcepts,
      explanation: question.explanation,
    );

    setState(() {
      _isEvaluatingShortAnswer = false;
      _currentEvaluation = evaluation;
      _shortAnswerResults[_currentShortAnswerIndex] = evaluation;
    });
  }

  Future<void> _requestHint({bool personalized = false}) async {
    final questions = widget.material.quiz;
    if (_currentShortAnswerIndex >= questions.length) return;

    final question = questions[_currentShortAnswerIndex];

    setState(() {
      _isLoadingHint = true;
    });

    final nextLevel = personalized ? math.max(1, _currentHintLevel) : (_currentHintLevel + 1);

    final hint = await _nanoService.generateStudyHint(
      question: question.question,
      referenceAnswer: question.sampleAnswer.isNotEmpty
          ? question.sampleAnswer
          : (question.options.isNotEmpty && question.correctAnswerIndex < question.options.length
              ? question.options[question.correctAnswerIndex]
              : question.explanation),
      hintLevel: nextLevel,
      hints: question.hints,
      keyConcepts: question.keyConcepts,
      studentDraft: personalized ? _shortAnswerController.text : null,
    );

    setState(() {
      _isLoadingHint = false;
      _activeHint = hint;
      if (!personalized) {
        _currentHintLevel = nextLevel;
      }
    });
  }

  void _nextShortAnswerQuestion() {
    final questions = widget.material.quiz;
    if (_currentShortAnswerIndex < questions.length - 1) {
      setState(() {
        _currentShortAnswerIndex++;
        _shortAnswerController.clear();
        _currentEvaluation = null;
        _activeHint = null;
        _currentHintLevel = 0;
        _showReferenceAnswer = false;
      });
    } else {
      setState(() {
        _shortAnswerFinished = true;
      });
    }
  }

  void _restartShortAnswerQuiz() {
    setState(() {
      _currentShortAnswerIndex = 0;
      _shortAnswerController.clear();
      _currentEvaluation = null;
      _activeHint = null;
      _currentHintLevel = 0;
      _showReferenceAnswer = false;
      _shortAnswerResults.clear();
      _shortAnswerFinished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.material.title),
        actions: [
          Tooltip(
            message: 'Gemini Nano 4 Active: Short-answer evaluation & hints work 100% offline during commutes with 0ms cloud latency',
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade400, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.bolt_rounded, size: 16, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'Nano 4 Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.summarize_rounded), text: 'Summary'),
            Tab(icon: Icon(Icons.notes_rounded), text: 'Notes'),
            Tab(icon: Icon(Icons.style_rounded), text: 'Flashcards'),
            Tab(icon: Icon(Icons.quiz_rounded), text: 'Quiz'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildNotesTab(),
          _buildFlashcardsTab(),
          _buildQuizTab(),
        ],
      ),
    );
  }

  // --- TAB 1: SUMMARY ---
  Widget _buildSummaryTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.material.imageUrl.isNotEmpty) ...[
            StudyImage(
              imageUrl: widget.material.imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AI Executive Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  SelectableText(
                    widget.material.summary,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: NOTES ---
  Widget _buildNotesTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Structured Study Notes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              SelectableText(
                widget.material.notes,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 3: FLASHCARDS ---
  Widget _buildFlashcardsTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final flashcards = widget.material.flashcards;

    if (flashcards.isEmpty) {
      return const Center(child: Text('No flashcards generated for this set.'));
    }

    final currentCard = flashcards[_currentCardIndex];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Counter
          Text(
            'Card ${_currentCardIndex + 1} of ${flashcards.length}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Flashcard Box
          Expanded(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _showCardBack
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: _showCardBack
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showCardBack
                              ? Icons.lightbulb_rounded
                              : Icons.help_outline_rounded,
                          size: 18,
                          color: _showCardBack
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showCardBack ? 'ANSWER' : 'QUESTION / TERM',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: _showCardBack
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Text(
                            _showCardBack ? currentCard.back : currentCard.front,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: _showCardBack
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap to flip',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                onPressed: _currentCardIndex > 0 ? _prevCard : null,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Previous Card',
              ),
              FilledButton.icon(
                onPressed: _flipCard,
                icon: const Icon(Icons.flip_rounded),
                label: Text(_showCardBack ? 'Show Question' : 'Show Answer'),
              ),
              IconButton.filledTonal(
                onPressed: _currentCardIndex < flashcards.length - 1
                    ? _nextCard
                    : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                tooltip: 'Next Card',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 4: QUIZ ---
  Widget _buildQuizTab() {
    final questions = widget.material.quiz;

    if (questions.isEmpty) {
      return const Center(child: Text('No quiz questions generated for this set.'));
    }

    return Column(
      children: [
        // Mode Selector: Short-Answer (Gemini Nano 4 On-Device) vs Multiple Choice
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'short_answer',
                icon: Icon(Icons.bolt_rounded, size: 18),
                label: Text('Short Answer (Nano 4)'),
              ),
              ButtonSegment<String>(
                value: 'multiple_choice',
                icon: Icon(Icons.list_alt_rounded, size: 18),
                label: Text('Multiple Choice'),
              ),
            ],
            selected: {_quizMode},
            onSelectionChanged: (val) {
              setState(() => _quizMode = val.first);
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _quizMode == 'short_answer'
              ? _buildShortAnswerQuizView(questions)
              : _buildMultipleChoiceQuizView(questions),
        ),
      ],
    );
  }

  // --- SHORT ANSWER RECALL VIEW (POWERED BY GEMINI NANO 4 ON-DEVICE) ---
  Widget _buildShortAnswerQuizView(List<QuizQuestion> questions) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_shortAnswerFinished) {
      final totalScores = _shortAnswerResults.values.fold<int>(0, (sum, e) => sum + e.score);
      final averageScore = _shortAnswerResults.isNotEmpty
          ? (totalScores / _shortAnswerResults.length).round()
          : 0;

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: averageScore >= 70
                      ? Colors.green.withOpacity(0.15)
                      : colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  averageScore >= 70
                      ? Icons.emoji_events_rounded
                      : Icons.psychology_rounded,
                  size: 64,
                  color: averageScore >= 70 ? Colors.green.shade700 : colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Short-Answer Practice Completed!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Overall Recall Score: $averageScore%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: averageScore >= 70 ? Colors.green.shade700 : colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_shortAnswerResults.length} questions evaluated completely on-device with zero cloud latency.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade400),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.bolt_rounded, size: 16, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      'Gemini Nano 4 • 100% Offline Active Recall',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _restartShortAnswerQuiz,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Practice Again'),
              ),
            ],
          ),
        ),
      );
    }

    final question = questions[_currentShortAnswerIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress and Score Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentShortAnswerIndex + 1} of ${questions.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.offline_bolt_rounded, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'Offline Mode',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentShortAnswerIndex + 1) / questions.length,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),

          // Commuter / On-Device Nano 4 Badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.green.withOpacity(0.2),
                  child: const Icon(Icons.bolt_rounded, size: 18, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gemini Nano 4 Active (On-Device)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        'Instant offline evaluation & interactive hints for study commutes.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Question Prompt Card
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Active Recall Question',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question.question,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Short-Answer Input Field
          TextField(
            controller: _shortAnswerController,
            minLines: 3,
            maxLines: 6,
            enabled: !_isEvaluatingShortAnswer,
            decoration: InputDecoration(
              hintText: 'Type your short answer in your own words...\n(e.g. explain the key function, mechanism, or definition)',
              hintStyle: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
              filled: true,
              fillColor: colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Interactive Hints Bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _currentHintLevel < 3 && !_isLoadingHint
                    ? () => _requestHint(personalized: false)
                    : null,
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                label: Text(
                  _currentHintLevel == 0
                      ? '💡 Ask Gemini Nano for Hint'
                      : '💡 Next Hint (${_currentHintLevel + 1}/3)',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _shortAnswerController,
                builder: (context, value, _) {
                  if (value.text.trim().isEmpty) return const SizedBox.shrink();
                  return OutlinedButton.icon(
                    onPressed: !_isLoadingHint
                        ? () => _requestHint(personalized: true)
                        : null,
                    icon: const Icon(Icons.psychology_alt_rounded, size: 16),
                    label: const Text(
                      '🔍 Hint on My Draft',
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                },
              ),
            ],
          ),

          // Hint Loading Indicator
          if (_isLoadingHint) ...[
            const SizedBox(height: 10),
            Row(
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Gemini Nano generating instant on-device hint...',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],

          // Active Hint Display Card
          if (_activeHint != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade700.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: Colors.amber.shade900, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _activeHint!.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      const Spacer(),
                      if (_activeHint!.isPersonalized)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Personalized',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _activeHint!.text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Evaluation Trigger Button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _shortAnswerController,
            builder: (context, val, _) {
              final hasText = val.text.trim().isNotEmpty;
              return FilledButton.icon(
                onPressed: hasText && !_isEvaluatingShortAnswer
                    ? _evaluateCurrentShortAnswer
                    : null,
                icon: _isEvaluatingShortAnswer
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bolt_rounded),
                label: Text(
                  _isEvaluatingShortAnswer
                      ? 'Evaluating on-device with Gemini Nano 4...'
                      : (_currentEvaluation != null
                          ? 'Re-evaluate Answer'
                          : 'Evaluate with Gemini Nano 4'),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: colorScheme.primary,
                ),
              );
            },
          ),

          // Gemini Nano 4 Evaluation Feedback Card
          if (_currentEvaluation != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _currentEvaluation!.isCorrect
                    ? Colors.green.withOpacity(0.12)
                    : (_currentEvaluation!.isPartial
                        ? Colors.amber.withOpacity(0.15)
                        : Colors.orange.withOpacity(0.12)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _currentEvaluation!.isCorrect
                      ? Colors.green
                      : (_currentEvaluation!.isPartial
                          ? Colors.amber.shade700
                          : Colors.orange.shade700),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status & Score Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _currentEvaluation!.isCorrect
                                ? Icons.check_circle_rounded
                                : (_currentEvaluation!.isPartial
                                    ? Icons.trending_up_rounded
                                    : Icons.info_outline_rounded),
                            color: _currentEvaluation!.isCorrect
                                ? Colors.green.shade800
                                : (_currentEvaluation!.isPartial
                                    ? Colors.amber.shade900
                                    : Colors.orange.shade900),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentEvaluation!.isCorrect
                                ? 'Mastered (${_currentEvaluation!.score}%)'
                                : (_currentEvaluation!.isPartial
                                    ? 'Partial Recall (${_currentEvaluation!.score}%)'
                                    : 'Needs Review (${_currentEvaluation!.score}%)'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _currentEvaluation!.isCorrect
                                  ? Colors.green.shade800
                                  : (_currentEvaluation!.isPartial
                                      ? Colors.amber.shade900
                                      : Colors.orange.shade900),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '⚡ ${_currentEvaluation!.latencyMs}ms • On-Device',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Qualitative Feedback
                  Text(
                    _currentEvaluation!.feedback,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  // Identified Concepts
                  if (_currentEvaluation!.identifiedConcepts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Identified Core Concepts:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _currentEvaluation!.identifiedConcepts.map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded, size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Missing Concepts
                  if (_currentEvaluation!.missingConcepts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Missing or Additional Concepts to Include:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _currentEvaluation!.missingConcepts.map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 14, color: Colors.amber.shade900),
                              const SizedBox(width: 4),
                              Text(c, style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Toggle Reference Answer
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showReferenceAnswer = !_showReferenceAnswer;
                      });
                    },
                    icon: Icon(_showReferenceAnswer ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16),
                    label: Text(_showReferenceAnswer ? 'Hide Exemplar Answer' : 'Show Exemplar Reference Answer'),
                  ),

                  if (_showReferenceAnswer) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Exemplar Answer:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            question.sampleAnswer.isNotEmpty
                                ? question.sampleAnswer
                                : (question.options.isNotEmpty && question.correctAnswerIndex < question.options.length
                                    ? question.options[question.correctAnswerIndex]
                                    : question.explanation),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (question.explanation.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SelectableText(
                              question.explanation,
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Next Question or Finish Action
            FilledButton.tonalIcon(
              onPressed: _nextShortAnswerQuestion,
              icon: Icon(_currentShortAnswerIndex < questions.length - 1
                  ? Icons.arrow_forward_rounded
                  : Icons.check_circle_outline_rounded),
              label: Text(
                _currentShortAnswerIndex < questions.length - 1
                    ? 'Next Question'
                    : 'Complete Practice',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- MULTIPLE CHOICE VIEW (ORIGINAL QUIZ ENGINE) ---
  Widget _buildMultipleChoiceQuizView(List<QuizQuestion> questions) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_quizFinished) {
      final percentage = (_quizScore / questions.length * 100).round();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  percentage >= 70
                      ? Icons.emoji_events_rounded
                      : Icons.psychology_rounded,
                  size: 64,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Quiz Completed!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'You scored $_quizScore out of ${questions.length} ($percentage%)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _restartQuiz,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retake Quiz'),
              ),
            ],
          ),
        ),
      );
    }

    final question = questions[_currentQuizIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quiz progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuizIndex + 1} of ${questions.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                'Score: $_quizScore',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentQuizIndex + 1) / questions.length,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 24),

          // Question Card
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                question.question,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Options list
          ...List.generate(question.options.length, (idx) {
            final optionText = question.options[idx];
            Color? tileColor;
            Color? borderColor;

            if (_hasAnsweredCurrentQuiz) {
              if (idx == question.correctAnswerIndex) {
                tileColor = Colors.green.withOpacity(0.15);
                borderColor = Colors.green;
              } else if (_selectedAnswerIndex == idx) {
                tileColor = Colors.red.withOpacity(0.15);
                borderColor = Colors.red;
              }
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: InkWell(
                onTap: () => _selectQuizOption(idx),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: tileColor ?? colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borderColor ?? colorScheme.outlineVariant,
                      width: borderColor != null ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: borderColor != null
                            ? borderColor.withOpacity(0.2)
                            : colorScheme.surfaceContainerHighest,
                        child: Text(
                          String.fromCharCode(65 + idx),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: borderColor ?? colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          optionText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: _selectedAnswerIndex == idx
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Feedback & Explanation
          if (_hasAnsweredCurrentQuiz) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selectedAnswerIndex == question.correctAnswerIndex
                    ? Colors.green.withOpacity(0.1)
                    : Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedAnswerIndex == question.correctAnswerIndex
                      ? Colors.green
                      : Colors.amber.shade700,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedAnswerIndex == question.correctAnswerIndex
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        color:
                            _selectedAnswerIndex == question.correctAnswerIndex
                                ? Colors.green
                                : Colors.amber.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedAnswerIndex == question.correctAnswerIndex
                            ? 'Correct!'
                            : 'Incorrect',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedAnswerIndex ==
                                  question.correctAnswerIndex
                              ? Colors.green.shade800
                              : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.explanation,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _nextQuizQuestion,
              child: Text(
                _currentQuizIndex < questions.length - 1
                    ? 'Next Question'
                    : 'See Results',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
