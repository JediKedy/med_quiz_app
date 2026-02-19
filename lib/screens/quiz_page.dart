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
  Map<int, int> _userAnswers = {};
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

  // --- Bookmark Məntiqi ---
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('bookmarks_${widget.bankName}') ?? [];
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

  // --- Suala sürətli keçid dialoqu ---
  void _showJumpToDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Suala keçid", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _questions.length,
                itemBuilder: (ctx, index) {
                  bool isCurrent = _currentIndex == index;
                  bool isAnswered = _userAnswers.containsKey(index);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _currentIndex = index;
                        _updateCurrentState();
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isCurrent ? Colors.blue : (isAnswered ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isCurrent ? Colors.blue : Colors.grey.shade400),
                      ),
                      child: Text("${index + 1}", 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: isCurrent ? Colors.white : Colors.black
                        )
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
      for (final q in _questions) {
        if (q.options.isEmpty) continue;
        final correctAnswerText = q.options[q.correct];
        q.options.shuffle();
        q.correct = q.options.indexOf(correctAnswerText);
      }
      _currentIndex = 0;
      _userAnswers.clear();
      _updateCurrentState();
    });
  }

  void _updateCurrentState() {
    setState(() {
      if (_userAnswers.containsKey(_currentIndex)) {
        _isAnswered = true;
        _selectedOption = _userAnswers[_currentIndex];
      } else {
        _isAnswered = false;
        _selectedOption = null;
      }
    });
  }

  void _answerQuestion(int i) {
    if (_isAnswered) return;
    setState(() {
      _isAnswered = true;
      _selectedOption = i;
      _userAnswers[_currentIndex] = i;
    });
    _saveProgress();
    Future.delayed(const Duration(milliseconds: 700), () {
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
    var finalScore = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] == _questions[i].correct) {
        finalScore++;
      } else if (_userAnswers.containsKey(i)) {
        _saveWrong(_questions[i]);
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
          questions: _questions,
          userAnswers: _userAnswers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final q = _questions[_currentIndex];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bankName),
        actions: [
          IconButton(
            icon: Icon(
              _bookmarkedIndices.contains(_currentIndex)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            color: _bookmarkedIndices.contains(_currentIndex)
                ? Colors.orange
                : null,
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.grid_view),
            onPressed: _showJumpToDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Sual ${_currentIndex + 1}/${_questions.length}', 
                          style: Theme.of(context).textTheme.titleMedium),
                      if (_currentIndex > 0)
                        TextButton.icon(
                          onPressed: _previousQuestion,
                          icon: const Icon(Icons.arrow_back_ios, size: 14),
                          label: const Text('Əvvəlki'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentIndex + 1) / _questions.length,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    color: scheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(q.question, 
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (q.image != null && q.image!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _QuestionImage(imagePath: q.image!),
                  ],
                  const SizedBox(height: 24),
                  ...q.options.asMap().entries.map((e) {
                    bool isCorrect = _isAnswered && e.key == q.correct;
                    bool isWrong = _isAnswered && e.key == _selectedOption && e.key != q.correct;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _answerQuestion(e.key),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isCorrect ? Colors.green.withOpacity(0.15) : 
                                   isWrong ? Colors.red.withOpacity(0.15) : scheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCorrect ? Colors.green : 
                                     isWrong ? Colors.red : scheme.outlineVariant,
                              width: (isCorrect || isWrong) ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: isCorrect ? Colors.green : 
                                               isWrong ? Colors.red : scheme.secondaryContainer,
                                child: Text(String.fromCharCode(65 + e.key), 
                                    style: TextStyle(fontSize: 13, color: scheme.onSecondaryContainer)),
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
                icon: const Icon(Icons.arrow_forward),
                label: Text(_currentIndex == _questions.length - 1 ? "Testi Bitir" : "Növbəti Sual"),
              ),
            ),
        ],
        ),
      ),
    );
  }

  // --- Yardımçı Funksiyalar ---
  Future<void> _loadQuestions() async {
    try {
      if (widget.bankData is Map && widget.bankData['questions'] is List) {
        _questions = (widget.bankData['questions'] as List)
            .map((q) => q is Question ? q : Question.fromJson(Map<String, dynamic>.from(q)))
            .toList();
      } else if (widget.bankData is String) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/${widget.bankData}');
        if (await file.exists()) {
          final data = json.decode(await file.readAsString());
          _questions = (data['questions'] as List).map((q) => Question.fromJson(q)).toList();
        }
      }
    } catch (e) { debugPrint("Xəta: $e"); }
    setState(() => _isLoading = false);
  }

  void _showModeSelection() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Sıralama seçin"),
        content: const Text("Suallar və variantlar qarışıq gəlsin?"),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); _shuffleEverything(); }, child: const Text("Qarışıq")),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text("Sıralı")),
        ],
        ),
      ),
    );
  }

  void _showContinueDialog(int idx, String? answersJson) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Davam edilsin?"),
        content: const Text("Yarımçıq qalan testiniz var."),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); _clearProgress(); _showModeSelection(); }, child: const Text("Sıfırla")),
          FilledButton(onPressed: () {
            if (answersJson != null) {
              final Map<String, dynamic> decoded = json.decode(answersJson);
              _userAnswers = decoded.map((k, v) => MapEntry(int.parse(k), v as int));
            }
            _currentIndex = idx;
            Navigator.pop(ctx);
            _updateCurrentState();
          }, child: const Text("Davam et")),
        ],
        ),
      ),
    );
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('progress_${widget.bankName}', _currentIndex);
    String answersJson = json.encode(_userAnswers.map((k, v) => MapEntry(k.toString(), v)));
    await prefs.setString('answers_${widget.bankName}', answersJson);
  }

  Future<void> _clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('progress_${widget.bankName}');
    await prefs.remove('answers_${widget.bankName}');
    _userAnswers.clear();
    setState(() { _currentIndex = 0; _isAnswered = false; _selectedOption = null; });
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
    final isNetwork = imagePath.startsWith('http://') || imagePath.startsWith('https://');
    final normalizedPath = imagePath.startsWith('file://')
        ? Uri.parse(imagePath).toFilePath()
        : imagePath;

    Widget errorWidget() {
      return Container(
        height: 180,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: scheme.error),
            const SizedBox(height: 8),
            Text(
              'Şəkil yüklənmədi',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 160, maxHeight: 300),
        width: double.infinity,
        color: scheme.surfaceContainer,
        child: isNetwork
            ? CachedNetworkImage(
                imageUrl: imagePath,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => errorWidget(),
              )
            : Image.file(
                File(normalizedPath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => errorWidget(),
              ),
      ),
    );
  }
}
