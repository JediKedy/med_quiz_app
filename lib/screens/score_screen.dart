import 'package:flutter/material.dart';

class ScoreScreen extends StatelessWidget {
  final int score;
  final int total;
  final String bankName;

  ScoreScreen({required this.score, required this.total, required this.bankName});

  @override
  Widget build(BuildContext context) {
    double percentage = (score / total) * 100;

    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(bankName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 30),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: score / total,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade200,
                    color: percentage >= 50 ? Colors.green : Colors.red,
                  ),
                ),
                Text("${percentage.toInt()}%", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 40),
            Text("Düzgün cavab: $score", style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
            Text("Səhv cavab: ${total - score}", style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
            SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
              child: Text("Ana Menyuya Qayıt"),
            ),
          ],
        ),
      ),
    );
  }
}