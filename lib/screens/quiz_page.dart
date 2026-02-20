import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question_model.dart';
import '../screens/score_screen.dart';

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
  Set<int> _bookmarkedIndices = {};
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
    await _loadBookmarks();
    if (!mounted) return;

    if (_questions.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('progress_${widget.bankName}') ?? 0;
    final savedAnswers = prefs.getString('answers_${widget.bankName}');

    if (savedIndex > 0 || savedAnswers != null) {
      _showContinueDialog(savedIndex, savedAnswers);
    } else {
      _showModeSelection();
    }
  }

  void _shuffleOptionsOnce(List<Question> questions) {
    for (final q in questions) {
      if (q.options.isEmpty) continue;
      final correctText = q.options[q.correct];
      q.options.shuffle();
      q.correct = q.options.indexOf(correctText);
    }
  }

  Future<void> _loadQuestions() async {
    try {
      List<Question> loadedQuestions = [];
      if (widget.bankData is Map && widget.bankData['questions'] is List) {
        loadedQuestions = (widget.bankData['questions'] as List)
            .map((q) => q is Question ? q : Question.fromJson(Map<String, dynamic>.from(q)))
            .toList();
      } else if (widget.bankData is String) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/${widget.bankData}');
        if (await file.exists()) {
          final data = json.decode(await file.readAsString());
          loadedQuestions =
              (data['questions'] as List).map((q) => Question.fromJson(q)).toList();
        }
      }

      _shuffleOptionsOnce(loadedQuestions);

      if (!mounted) return;
      setState(() {
        _questions = loadedQuestions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Xəta: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('bookmarks_${widget.bankName}') ?? [];
    if (!mounted) return;
    setState(() {
      _bookmarkedIndices = list.map((e) => int.parse(e)).toSet();
    });
  }

  Future<void> _toggleBookmark() async {
    setState(() {
      if (_bookmarkedIndices.contains(_currentIndex)) {
        _bookmarkedIndices.remove(_currentIndex);
      } else {
        _bookmarkedIndices.add(_currentIndex);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'bookmarks_${widget.bankName}',
      _bookmarkedIndices.map((e) => e.toString()).toList(),
    );
  }

  void _showJumpToDialog() {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Text('Suala keçid', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _questions.length,
                itemBuilder: (ctx, index) {
                  final isCurrent = _currentIndex == index;
                  final isAnswered = _userAnswers.containsKey(index);
                  final isCorrect = isAnswered && _userAnswers[index] == _questions[index].correct;

                  Color tileColor = scheme.surfaceContainerHighest;
                  Color borderColor = scheme.outlineVariant;
                  Color textColor = scheme.onSurface;

                  if (isCurrent) {
                    tileColor = scheme.primary;
                    borderColor = scheme.primary;
                    textColor = scheme.onPrimary;
                  } else if (isAnswered) {
                    tileColor = isCorrect
                        ? Colors.green.withOpacity(0.15)
                        : scheme.errorContainer.withOpacity(0.6);
                    borderColor = isCorrect ? Colors.green : scheme.error;
                  }

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _currentIndex = index;
                        _updateCurrentState();
                      });
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tileColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shuffleEverything() {
    setState(() {
      _questions.shuffle();
      _currentIndex = 0;
      _userAnswers.clear();
      _updateCurrentState();
    });
    _clearProgress(updateState: false);
  }

  void _updateCurrentState() {
    final selected = _userAnswers[_currentIndex];
    _isAnswered = selected != null;
    _selectedOption = selected;
  }

  void _answerQuestion(int i) {
    if (_isAnswered) return;

    setState(() {
      _isAnswered = true;
      _selectedOption = i;
      _userAnswers[_currentIndex] = i;
    });

    _saveProgress();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _updateCurrentState();
      });
      _saveProgress();
    } else {
      _calculateFinalScoreAndFinish();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _updateCurrentState();
      });
    }
  }

  void _calculateFinalScoreAndFinish() {
    final answersSnapshot = Map<int, int>.from(_userAnswers);
    var finalScore = 0;

    for (var i = 0; i < _questions.length; i++) {
      if (answersSnapshot[i] == _questions[i].correct) {
        finalScore++;
      } else if (answersSnapshot.containsKey(i)) {
        _saveWrong(_questions[i]);
      }
    }

    _clearProgress(updateState: false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (c) => ScoreScreen(
          score: finalScore,
          total: _questions.length,
          bankName: widget.bankName,
          questions: _questions,
          userAnswers: answersSnapshot,
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
        actions: [
          IconButton(
            icon: Icon(
              _bookmarkedIndices.contains(_currentIndex)
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
            color: _bookmarkedIndices.contains(_currentIndex) ? Colors.orange : null,
            onPressed: _toggleBookmark,
          ),
          IconButton(icon: const Icon(Icons.grid_view_rounded), onPressed: _showJumpToDialog),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: SingleChildScrollView(
                  key: ValueKey(_currentIndex),
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
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                              label: const Text('Əvvəlki'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_currentIndex + 1) / _questions.length,
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            q.question,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (q.image != null && q.image!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _QuestionImage(imagePath: q.image!),
                      ],
                      const SizedBox(height: 24),
                      ...q.options.asMap().entries.map((e) {
                        final isCorrect = _isAnswered && e.key == q.correct;
                        final isWrong =
                            _isAnswered && e.key == _selectedOption && e.key != q.correct;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _answerQuestion(e.key),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 230),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? Colors.green.withOpacity(0.12)
                                    : isWrong
                                        ? scheme.errorContainer.withOpacity(0.55)
                                        : scheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isCorrect
                                      ? Colors.green
                                      : isWrong
                                          ? scheme.error
                                          : scheme.outlineVariant,
                                  width: (isCorrect || isWrong) ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: isCorrect
                                        ? Colors.green
                                        : isWrong
                                            ? scheme.error
                                            : scheme.secondaryContainer,
                                    child: Text(
                                      String.fromCharCode(65 + e.key),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: (isCorrect || isWrong)
                                            ? Colors.white
                                            : scheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
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
              ),
            ),
            if (_isAnswered)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(top: BorderSide(color: scheme.outlineVariant)),
                ),
                child: FilledButton.icon(
                  onPressed: _nextQuestion,
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(_currentIndex == _questions.length - 1
                      ? 'Testi Bitir'
                      : 'Növbəti Sual'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showModeSelection() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sıralama seçin'),
        content:
            const Text('Suallar qarışıq gəlsin? (Variantlar hər iki halda qarışıq olacaq)'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _shuffleEverything();
            },
            child: const Text('Suallar Qarışıq'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Suallar Sıralı'),
          ),
        ],
      ),
    );
  }

  void _showContinueDialog(int idx, String? answersJson) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Davam edilsin?'),
        content: const Text('Yarımçıq qalan testiniz var.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearProgress();
              _showModeSelection();
            },
            child: const Text('Sıfırla'),
          ),
          FilledButton(
            onPressed: () {
              if (answersJson != null) {
                final Map<String, dynamic> decoded = json.decode(answersJson);
                _userAnswers
                  ..clear()
                  ..addAll(decoded.map((k, v) => MapEntry(int.parse(k), v as int)));
              }
              _currentIndex = idx.clamp(0, _questions.length - 1);
              Navigator.pop(ctx);
              if (!mounted) return;
              setState(_updateCurrentState);
            },
            child: const Text('Davam et'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('progress_${widget.bankName}', _currentIndex);
    final answersJson = json.encode(_userAnswers.map((k, v) => MapEntry(k.toString(), v)));
    await prefs.setString('answers_${widget.bankName}', answersJson);
  }

  Future<void> _clearProgress({bool updateState = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('progress_${widget.bankName}');
    await prefs.remove('answers_${widget.bankName}');

    if (mounted && updateState) {
      setState(() {
        _userAnswers.clear();
        _currentIndex = 0;
        _isAnswered = false;
        _selectedOption = null;
      });
    }
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
}

class _QuestionImage extends StatelessWidget {
  final String imagePath;

  const _QuestionImage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const baseUrl =
        'https://raw.githubusercontent.com/JediKedy/med_quiz_app_questions/refs/heads/main/';

    var finalImageUrl = imagePath;
    if (!imagePath.startsWith('http')) {
      finalImageUrl = baseUrl + imagePath.replaceAll(' ', '%20');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 160, maxHeight: 300),
        width: double.infinity,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
        child: CachedNetworkImage(
          imageUrl: finalImageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_rounded, color: scheme.error, size: 40),
              const SizedBox(height: 8),
              const Text('Şəkil yüklənə bilmədi', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
