import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/question_model.dart';
import 'score_screen.dart';

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

  // 1. Normal tək bank yükləmə (String path)
  if (widget.bankData is String) {
    File file = File("${directory.path}/${widget.bankData}");
    if (await file.exists()) {
      var data = json.decode(await file.readAsString());
      loadedQuestions = (data['questions'] as List)
          .map((q) => Question.fromJson(q))
          .toList();
    }
  } 
  // 2. Ümumi Sınaq məntiqi (Map config)
  else if (widget.bankData is Map) {
    Map<String, dynamic> config = widget.bankData;
    
    // Bütün banks.json-u yenidən oxuyuruq ki, digər bankların yollarını tapa bilək
    File mainBanksFile = File("${directory.path}/banks.json");
    Map<String, dynamic> allBanks = json.decode(await mainBanksFile.readAsString());

    // Funksiya: Bank adına görə sualları gətirir
    Future<List<Question>> getQuestionsFromBank(String name) async {
      String? path = _findPathInMap(allBanks, name);
      if (path != null) {
        File f = File("${directory.path}/$path");
        if (await f.exists()) {
          var d = json.decode(await f.readAsString());
          return (d['questions'] as List).map((q) => Question.fromJson(q)).toList();
        }
      }
      return [];
    }

    if (config.containsKey('banks')) {
      // Birbaşa bank siyahısı: "total" qədər sual seç
      for (String bName in config['banks']) {
        loadedQuestions.addAll(await getQuestionsFromBank(bName));
      }
      loadedQuestions.shuffle();
      if (config['total'] < loadedQuestions.length) {
        loadedQuestions = loadedQuestions.sublist(0, config['total']);
      }
    } else if (config.containsKey('parts')) {
      // Hissələr (parts) məntiqi: hər hissədən müəyyən sayda
      Map<String, dynamic> parts = config['parts'];
      for (var entry in parts.entries) {
        // Burada "Kardiologiya ümumi" kimi alt-sınaqları tapmaq lazımdır
        var partConfig = allBanks['Ümumi sınaqlar'][entry.key];
        List<Question> partPool = [];
        for (String bName in partConfig['banks']) {
          partPool.addAll(await getQuestionsFromBank(bName));
        }
        partPool.shuffle();
        loadedQuestions.addAll(partPool.take(entry.value));
      }
    }
  }

  setState(() {
    _questions = loadedQuestions..shuffle();
  });
}

// Rekursiv olaraq bank adını axtarıb yolunu (path) tapan köməkçi funksiya
String? _findPathInMap(Map<String, dynamic> map, String targetKey) {
  for (var entry in map.entries) {
    if (entry.key == targetKey && entry.value is String) return entry.value;
    if (entry.value is Map<String, dynamic>) {
      String? found = _findPathInMap(entry.value, targetKey);
      if (found != null) return found;
    }
  }
  return null;
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
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => ScoreScreen(
        score: _score,
        total: _questions.length,
        bankName: widget.bankName,
      ),
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
              SizedBox(height: 15),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                // Uri.encodeFull boşluqları və xüsusi simvolların URL-ə uyğunlaşdırılmasını təmin edir
                imageUrl: Uri.encodeFull("https://raw.githubusercontent.com/JediKedy/med_quiz_app_questions/main/${currentQ.image}"),
                placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => Column(
                  children: [
                    Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    Text("Şəkil yüklənmədi", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              fit: BoxFit.contain,
            ),
          ),
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
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isAnswered 
                             ? (i == currentQ.correct ? Colors.green : (i == _selectedOption ? Colors.red : Colors.grey.shade300))
                             : Colors.blue.shade200,
                              width: 2,
                        ),
                      ),
                      child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(String.fromCharCode(65 + i), style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                   ),
                    title: Text(currentQ.options[i]),
                    onTap: () => _answerQuestion(i),
                   tileColor: btnColor, // yuxarıdakı rəng məntiqi ilə eyni
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}