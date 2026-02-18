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

    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('progress_${widget.bankName}') ?? 0;

    if (!mounted) return;
    if (savedIndex > 0 && savedIndex < _questions.length) {
      _showContinueDialog(savedIndex);
    } else {
      _showModeSelection();
    }
  }

  String? _findFilePath(Map<String, dynamic> data, String bankName) {
    for (final key in data.keys) {
      final value = data[key];
      if (key == bankName && value is String) return value;
      if (value is Map<String, dynamic>) {
        final found = _findFilePath(value, bankName);
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<List<Question>> _collectQuestions(Map<String, dynamic> allBanks, dynamic config) async {
    var result = <Question>[];
    final dir = await getApplicationDocumentsDirectory();

    if (config is Map) {
      if (config.containsKey('banks')) {
        for (final bName in config['banks']) {
          final path = _findFilePath(allBanks, bName);
          if (path != null) {
            final f = File('${dir.path}/$path');
            if (await f.exists()) {
              final d = json.decode(await f.readAsString());
              result.addAll((d['questions'] as List).map((q) => Question.fromJson(q)));
            }
          }
        }
      } else if (config.containsKey('parts')) {
        final p = config['parts'] as Map<String, dynamic>;
        for (final e in p.entries) {
          final sub = allBanks['Ümumi sınaqlar']?[e.key];
          if (sub != null) {
            final pool = await _collectQuestions(allBanks, sub);
            pool.shuffle();
            result.addAll(pool.take(e.value));
          }
        }
      }

      if (config.containsKey('total') && config['total'] < result.length) {
        result.shuffle();
        result = result.sublist(0, config['total']);
      }
    }
    return result;
  }

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
      } else {
        _questions = await _collectQuestions(all, widget.bankData);
      }
    } catch (e) {
      debugPrint('Xəta: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showModeSelection() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejim seçin'),
        content: const Text('Sualları qarışıq və ya sıralı başlatmaq istəyirsiniz?'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _questions.shuffle());
              Navigator.pop(ctx);
            },
            child: const Text('Qarışıq'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Sıralı'),
          ),
        ],
      ),
    );
  }

  void _showContinueDialog(int idx) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Davam edilsin?'),
        content: Text('Siz ${idx + 1}-ci sualdan davam edə bilərsiniz.'),
        actions: [
          TextButton(
            onPressed: () {
              _currentIndex = 0;
              Navigator.pop(ctx);
              _showModeSelection();
            },
            child: const Text('Başdan'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _currentIndex = idx);
              Navigator.pop(ctx);
            },
            child: const Text('Davam'),
          ),
        ],
      ),
    );
  }

  void _answerQuestion(int i) {
    if (_isAnswered) return;
    setState(() {
      _isAnswered = true;
      _selectedOption = i;
      if (i == _questions[_currentIndex].correct) {
        _score++;
      } else {
        _saveWrong(_questions[_currentIndex]);
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _isAnswered = false;
          _selectedOption = null;
        });
        _saveProgress();
      } else {
        _clearProgress();
        _showRes();
      }
    });
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

  void _showRes() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (c) => ScoreScreen(score: _score, total: _questions.length, bankName: widget.bankName),
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
            tooltip: 'Tema',
            icon: Icon(isDarkMode(context) ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: toggleAppTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sual ${_currentIndex + 1}/${_questions.length}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: (_currentIndex + 1) / _questions.length, minHeight: 8),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(q.question, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            if (q.image != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: 'https://raw.githubusercontent.com/JediKedy/med_quiz_app_questions/main/${q.image}',
                  height: 220,
                  fit: BoxFit.cover,
                  placeholder: (context, _) => Container(
                    height: 220,
                    alignment: Alignment.center,
                    color: scheme.surfaceContainerHighest,
                    child: const CircularProgressIndicator(),
                  ),
                  errorWidget: (context, _, __) => Container(
                    height: 220,
                    alignment: Alignment.center,
                    color: scheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_rounded, size: 40),
                  ),
                ),
              ),
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
                child: Material(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _answerQuestion(e.key),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: ListTile(title: Text(e.value)),
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
}
