import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question_model.dart';
import '../theme_controller.dart';
import 'score_screen.dart';

class QuizPage extends StatefulWidget {
  final String bankName;
  final dynamic bankData;

  const QuizPage({super.key, required this.bankName, required this.bankData});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<Question> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isAnswered = false;
  int? _selectedOption;
  bool _isLoading = true;

  // İSTİFADƏÇİNİN CAVABLARINI YADDA SAXLAMAQ ÜÇÜN
  // Key: Sualın indeksi, Value: Seçilən variantın indeksi
  Map<int, int> _userAnswers = {};

  @override
  void initState() {
    super.initState();
    _initQuiz();
  }

  void _shuffleQuestionOptions(List<Question> questions) {
    for (var q in questions) {
      String correctAnswerText = q.options[q.correct];
      q.options.shuffle();
      q.correct = q.options.indexOf(correctAnswerText);
    }
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

    if (savedIndex > 0 && savedIndex < _questions.length) {
      _showContinueDialog(savedIndex);
    } else {
      _userAnswers.clear(); // Sıfırdan başlayanda cavabları sil
      _showModeSelection();
    }
  }

  // ... (_loadQuestions, _collectQuestions və s. metodları olduğu kimi qalır) ...

  void _answerQuestion(int i) {
    if (_isAnswered) return;
    
    setState(() {
      _isAnswered = true;
      _selectedOption = i;
      _userAnswers[_currentIndex] = i; // Cavabı yadda saxla

      // Hesablama yalnız irəli gedəndə və ya ilk dəfə cavab verəndə dəqiq olsun deyə 
      // score məntiqini burada yox, son nəticədə hesablamaq daha sağlamdır.
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        // Əgər bu suala əvvəl cavab verilibsə, onu bərpa et
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
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isAnswered = true; // Əvvəlki suala qayıdırıqsa, deməli cavab verilib
        _selectedOption = _userAnswers[_currentIndex];
      });
    }
  }

  void _calculateFinalScoreAndFinish() {
    int finalScore = 0;
    _userAnswers.forEach((index, selectedIdx) {
      if (selectedIdx == _questions[index].correct) {
        finalScore++;
      } else {
        _saveWrong(_questions[index]);
      }
    });
    
    _clearProgress();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (c) => ScoreScreen(score: finalScore, total: _questions.length, bankName: widget.bankName),
      ),
    );
  }

  // Digər metodlar (SaveProgress, LoadQuestions və s.) eyni qalır...
  // Aşağıdakı build metodunda düyməni əlavə edirik:

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final q = _questions[_currentIndex];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bankName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sual ${_currentIndex + 1}/${_questions.length}', style: Theme.of(context).textTheme.titleMedium),
                if (_currentIndex > 0)
                  TextButton.icon(
                    onPressed: _previousQuestion,
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text("Əvvəlki"),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: (_currentIndex + 1) / _questions.length, minHeight: 8),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: scheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(q.question, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            // ... (Şəkil hissəsi eyni qalır) ...
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
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: _selectedOption == e.key ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Text(String.fromCharCode(65 + e.key) + ") ", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(e.value)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            if (_isAnswered && _currentIndex < _questions.length - 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: FilledButton.icon(
                  onPressed: _nextQuestion,
                  icon: const Icon(Icons.navigate_next),
                  label: const Text("Növbəti sual"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Kodu tamamlamaq üçün çatışmayan köməkçi metodlar (yuxarıdakı xətaları aradan qaldırmaq üçün):
  Future<void> _loadQuestions() async {
    if (widget.bankData is Map && widget.bankData.containsKey('questions')) {
      _questions = List<Question>.from(widget.bankData['questions']);
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    try {
      final main = File('${dir.path}/banks.json');
      final all = json.decode(await main.readAsString()) as Map<String, dynamic>;
      if (widget.bankData is String) {
        final f = File('${dir.path}/${widget.bankData}');
        final d = json.decode(await f.readAsString());
        _questions = (d['questions'] as List).map((q) => Question.fromJson(q)).toList();
      }
    } catch (e) { debugPrint('Xəta: $e'); }
    if (mounted) setState(() => _isLoading = false);
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
    final w = prefs.getStringList('wrong_questions') ?? [];
    final j = json.encode(q.toJson());
    if (!w.contains(j)) {
      w.add(j);
      await prefs.setStringList('wrong_questions', w);
    }
  }

  void _showModeSelection() { /* ... mövud kodla eyni ... */ }
  void _showContinueDialog(int idx) { /* ... mövud kodla eyni ... */ }
}