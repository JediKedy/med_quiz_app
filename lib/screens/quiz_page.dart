import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question_model.dart';
import 'score_screen.dart';

class QuizPage extends StatefulWidget {
  final String bankName;
  final dynamic bankData;

  QuizPage({required this.bankName, required this.bankData});

  @override
  _QuizPageState createState() => _QuizPageState();
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
    if (_questions.isEmpty) { Navigator.pop(context); return; }

    final prefs = await SharedPreferences.getInstance();
    int savedIndex = prefs.getInt('progress_${widget.bankName}') ?? 0;

    if (savedIndex > 0 && savedIndex < _questions.length) {
      _showContinueDialog(savedIndex);
    } else {
      _showModeSelection();
    }
  }

  String? _findFilePath(Map<String, dynamic> data, String bankName) {
    for (var key in data.keys) {
      var value = data[key];
      if (key == bankName && value is String) return value;
      if (value is Map<String, dynamic>) {
        var found = _findFilePath(value, bankName);
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<List<Question>> _collectQuestions(Map<String, dynamic> allBanks, dynamic config) async {
    List<Question> result = [];
    final dir = await getApplicationDocumentsDirectory();

    if (config is Map) {
      if (config.containsKey('banks')) {
        for (String bName in config['banks']) {
          String? path = _findFilePath(allBanks, bName);
          if (path != null) {
            File f = File("${dir.path}/$path");
            if (await f.exists()) {
              var d = json.decode(await f.readAsString());
              result.addAll((d['questions'] as List).map((q) => Question.fromJson(q)));
            }
          }
        }
      } else if (config.containsKey('parts')) {
        Map<String, dynamic> p = config['parts'];
        for (var e in p.entries) {
          var sub = allBanks['Ümumi sınaqlar']?[e.key];
          if (sub != null) {
            List<Question> pool = await _collectQuestions(allBanks, sub);
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
      setState(() => _isLoading = false);
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    try {
      File main = File("${dir.path}/banks.json");
      Map<String, dynamic> all = json.decode(await main.readAsString());

      if (widget.bankData is String) {
        File f = File("${dir.path}/${widget.bankData}");
        var d = json.decode(await f.readAsString());
        _questions = (d['questions'] as List).map((q) => Question.fromJson(q)).toList();
      } else {
        _questions = await _collectQuestions(all, widget.bankData);
      }
    } catch (e) { debugPrint("Xəta: $e"); }
    setState(() => _isLoading = false);
  }

  void _showModeSelection() {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: Text("Rejim"),
      actions: [
        TextButton(onPressed: () { setState(() { _questions.shuffle(); }); Navigator.pop(ctx); }, child: Text("Qarışıq")),
        TextButton(onPressed: () { Navigator.pop(ctx); }, child: Text("Sıralı")),
      ],
    ));
  }

  void _showContinueDialog(int idx) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      title: Text("Davam?"),
      actions: [
        TextButton(onPressed: () { _currentIndex = 0; Navigator.pop(ctx); _showModeSelection(); }, child: Text("Başdan")),
        TextButton(onPressed: () { setState(() { _currentIndex = idx; }); Navigator.pop(ctx); }, child: Text("Davam")),
      ],
    ));
  }

  void _answerQuestion(int i) {
    if (_isAnswered) return;
    setState(() {
      _isAnswered = true; _selectedOption = i;
      if (i == _questions[_currentIndex].correct) _score++;
      else _saveWrong(_questions[_currentIndex]);
    });
    Future.delayed(Duration(milliseconds: 800), () {
      if (_currentIndex < _questions.length - 1) {
        setState(() { _currentIndex++; _isAnswered = false; _selectedOption = null; });
        _saveProgress();
      } else { _clearProgress(); _showRes(); }
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
    List<String> w = prefs.getStringList('wrong_questions') ?? [];
    String j = json.encode(q.toJson());
    if (!w.contains(j)) { w.add(j); await prefs.setStringList('wrong_questions', w); }
  }

  void _showRes() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => ScoreScreen(score: _score, total: _questions.length, bankName: widget.bankName)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    final q = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text(widget.bankName)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_currentIndex + 1) / _questions.length),
            SizedBox(height: 10),
            Text("${_currentIndex + 1}/${_questions.length}"),
            SizedBox(height: 10),
            Text(q.question, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (q.image != null) ...[
              SizedBox(height: 10),
              CachedNetworkImage(imageUrl: "https://raw.githubusercontent.com/JediKedy/med_quiz_app_questions/main/${q.image}", height: 200),
            ],
            SizedBox(height: 20),
            ...q.options.asMap().entries.map((e) {
              Color c = Colors.white;
              if (_isAnswered) {
                if (e.key == q.correct) c = Colors.green.shade100;
                else if (e.key == _selectedOption) c = Colors.red.shade100;
              }
              return Container(
                margin: EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: c, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
                child: ListTile(title: Text(e.value), onTap: () => _answerQuestion(e.key)),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}