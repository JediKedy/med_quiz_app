import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question_model.dart';
import 'score_screen.dart';

class QuizPage extends StatefulWidget {
  final String bankName;
  final dynamic bankData;

  const QuizPage({super.key, required this.bankName, required this.bankData});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final Map<int, int> _userAnswers = {};

  List<Question> _questions = [];
  int _currentIndex = 0;
  bool _isAnswered = false;
  int? _selectedOption;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initQuiz();
  }

  Future<void> _initQuiz() async {
    await _loadQuestions();
    if (!mounted) return;

    if (_questions.isEmpty) {
      Navigator.pop(context);
      return;
    }

    _shuffleQuestionOptions(_questions);

    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('progress_${widget.bankName}') ?? 0;

    if (!mounted) return;
    if (savedIndex > 0 && savedIndex < _questions.length) {
      _showContinueDialog(savedIndex);
    } else {
      _showModeSelection();
    }
  }

  void _shuffleQuestionOptions(List<Question> questions) {
    for (final q in questions) {
      if (q.correct < 0 || q.correct >= q.options.length) continue;
      final correctAnswerText = q.options[q.correct];
      q.options.shuffle();
      q.correct = q.options.indexOf(correctAnswerText);
    }
  }

  void _answerQuestion(int i) {
    if (_isAnswered) return;

    setState(() {
      _isAnswered = true;
      _selectedOption = i;
      _userAnswers[_currentIndex] = i;
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || _currentIndex >= _questions.length) return;
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        if (_userAnswers.containsKey(_currentIndex)) {
          _isAnswered = true;
          _selectedOption = _userAnswers[_currentIndex];
        } else {
          _isAnswered = false;
          _selectedOption = null;
        }
      });
      _saveProgress();
    } else {
      _calculateFinalScoreAndFinish();
    }
  }

  void _previousQuestion() {
    if (_currentIndex <= 0) return;

    setState(() {
      _currentIndex--;
      _selectedOption = _userAnswers[_currentIndex];
      _isAnswered = _selectedOption != null;
    });
  }

  void _calculateFinalScoreAndFinish() {
    var finalScore = 0;
    for (final entry in _userAnswers.entries) {
      final index = entry.key;
      final selectedIdx = entry.value;
      if (index >= _questions.length) continue;

      if (selectedIdx == _questions[index].correct) {
        finalScore++;
      } else {
        _saveWrong(_questions[index]);
      }
    }

    _clearProgress();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (c) => ScoreScreen(
          score: finalScore,
          total: _questions.length,
          bankName: widget.bankName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = _questions[_currentIndex];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bankName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sual ${_currentIndex + 1}/${_questions.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_currentIndex > 0)
                  TextButton.icon(
                    onPressed: _previousQuestion,
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Əvvəlki'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / _questions.length,
                minHeight: 9,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: scheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  q.question,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (q.image != null && q.image!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _QuestionImage(imagePath: q.image!),
            ],
            const SizedBox(height: 16),
            ...q.options.asMap().entries.map((e) {
              var cardColor = scheme.surface;
              var borderColor = scheme.outlineVariant;

              if (_isAnswered) {
                if (e.key == q.correct) {
                  cardColor = Colors.green.withOpacity(0.15);
                  borderColor = Colors.green;
                } else if (e.key == _selectedOption) {
                  cardColor = Colors.red.withOpacity(0.12);
                  borderColor = Colors.red;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _answerQuestion(e.key),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor,
                        width: _selectedOption == e.key ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${String.fromCharCode(65 + e.key)}) ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(child: Text(e.value)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _loadQuestions() async {
    try {
      if (widget.bankData is Map && widget.bankData['questions'] is List) {
        final rawQuestions = widget.bankData['questions'] as List;
        _questions = rawQuestions.map((q) {
          if (q is Question) return q;
          return Question.fromJson(Map<String, dynamic>.from(q as Map));
        }).toList();
      } else if (widget.bankData is String) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/${widget.bankData}');
        if (await file.exists()) {
          final data = json.decode(await file.readAsString()) as Map<String, dynamic>;
          final rawQuestions = data['questions'] as List<dynamic>? ?? [];
          _questions = rawQuestions
              .map((q) => Question.fromJson(Map<String, dynamic>.from(q as Map)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Sual yükləmə xətası: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('progress_${widget.bankName}', _currentIndex);
  }

  Future<void> _clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('progress_${widget.bankName}');
  }

  Future<void> _saveWrong(Question q) async {
    final prefs = await SharedPreferences.getInstance();
    final wrongs = prefs.getStringList('wrong_questions') ?? [];
    final encoded = json.encode(q.toJson());

    if (!wrongs.contains(encoded)) {
      wrongs.add(encoded);
      await prefs.setStringList('wrong_questions', wrongs);
    }
  }

  void _showModeSelection() {
    _userAnswers.clear();
    setState(() {
      _currentIndex = 0;
      _isAnswered = false;
      _selectedOption = null;
    });
  }

  void _showContinueDialog(int idx) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Davam edilsin?'),
        content: const Text('Bu test üçün saxlanmış irəliləyiş tapıldı.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showModeSelection();
            },
            child: const Text('Yenidən başla'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentIndex = idx;
                _selectedOption = _userAnswers[idx];
                _isAnswered = _selectedOption != null;
              });
            },
            child: const Text('Davam et'),
          ),
        ],
      ),
    );
  }
}

class _QuestionImage extends StatelessWidget {
  final String imagePath;

  const _QuestionImage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final isNetworkImage = imagePath.startsWith('http://') || imagePath.startsWith('https://');

    Widget imageWidget;
    if (isNetworkImage) {
      imageWidget = CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image_outlined, size: 36)),
      );
    } else {
      final file = File(imagePath);
      imageWidget = Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 36)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: imageWidget,
        ),
      ),
    );
  }
}
