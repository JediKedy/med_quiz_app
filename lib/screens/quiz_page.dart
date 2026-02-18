import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/question_model.dart';

class QuizPage extends StatefulWidget {
  final String bankName;
  final dynamic bankData; // String (path) və ya Map (composite config)

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

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final directory = await getApplicationDocumentsDirectory();
    List<Question> loadedQuestions = [];

    if (widget.bankData is String) {
      // Normal tək bank yükləmə
      File file = File("${directory.path}/${widget.bankData}");
      if (await file.exists()) {
        var data = json.decode(await file.readAsString());
        loadedQuestions = (data['questions'] as List)
            .map((q) => Question.fromJson(q))
            .toList();
      }
    } else if (widget.bankData is Map) {
      // Sənin Python-dakı "Ümumi sınaqlar" (Composite) məntiqi
      // Bu hissəni gələn addımda daha da detallandıracağıq
    }

    setState(() {
      _questions = loadedQuestions..shuffle(); // Sualları qarışdırırıq
    });
  }

  void _answerQuestion(int index) {
    if (_isAnswered) return;
    setState(() {
      _isAnswered = true;
      _selectedOption = index;
      if (index == _questions[_currentIndex].correct) {
        _score++;
      }
    });

    Future.delayed(Duration(seconds: 1), () {
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _isAnswered = false;
          _selectedOption = null;
        });
      } else {
        _showResults();
      }
    });
  }

  void _showResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Nəticə"),
        content: Text("Bal: $_score / ${_questions.length}"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text("Bağla"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) return Scaffold(body: Center(child: CircularProgressIndicator()));

    final currentQ = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text(widget.bankName)),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_currentIndex + 1) / _questions.length),
            SizedBox(height: 20),
            Text("Sual ${_currentIndex + 1}/${_questions.length}", style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 10),
            Text(currentQ.question, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (currentQ.image != null) ...[
              SizedBox(height: 10),
              // Şəkillər URL olsa Image.network, fayl olsa Image.file
              Image.network("https://raw.githubusercontent.com/.../${currentQ.image}"),
            ],
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: currentQ.options.length,
                itemBuilder: (ctx, i) {
                  Color btnColor = Colors.blue.shade50;
                  if (_isAnswered) {
                    if (i == currentQ.correct) btnColor = Colors.green.shade200;
                    else if (i == _selectedOption) btnColor = Colors.red.shade200;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: () => _answerQuestion(i),
                      child: Text(currentQ.options[i], textAlign: TextAlign.center),
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
}