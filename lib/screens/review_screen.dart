import 'package:flutter/material.dart';
import '../models/question_model.dart';

class ReviewScreen extends StatelessWidget {
  final List<Question> questions;
  final Map<int, int> userAnswers;

  const ReviewScreen({super.key, required this.questions, required this.userAnswers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sualların İcmalı")),
      body: ListView.builder(
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final q = questions[index];
          final selected = userAnswers[index];
          final isCorrect = selected == q.correct;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: selected == null ? Colors.grey : (isCorrect ? Colors.green : Colors.red),
                child: Text("${index + 1}", style: const TextStyle(color: Colors.white)),
              ),
              title: Text(q.question, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(selected == null ? "Cavab verilməyib" : (isCorrect ? "Doğru cavab" : "Yanlış cavab")),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...q.options.asMap().entries.map((e) {
                        Color? textColor;
                        if (e.key == q.correct) textColor = Colors.green;
                        else if (e.key == selected && !isCorrect) textColor = Colors.red;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                e.key == q.correct ? Icons.check_circle : (e.key == selected ? Icons.cancel : Icons.circle_outlined),
                                size: 18,
                                color: textColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(e.value, style: TextStyle(color: textColor, fontWeight: textColor != null ? FontWeight.bold : null))),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}