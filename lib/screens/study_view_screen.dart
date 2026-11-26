import 'package:flutter/material.dart';
import '../models/study_material.dart';
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

  // Quiz state
  int _currentQuizIndex = 0;
  int? _selectedAnswerIndex;
  bool _hasAnsweredCurrentQuiz = false;
  int _quizScore = 0;
  bool _quizFinished = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.material.title),
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
    final colorScheme = Theme.of(context).colorScheme;
    final questions = widget.material.quiz;

    if (questions.isEmpty) {
      return const Center(child: Text('No quiz questions generated for this set.'));
    }

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
