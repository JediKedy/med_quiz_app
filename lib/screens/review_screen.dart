import 'package:flutter/material.dart';
import '../models/question_model.dart';

class ReviewScreen extends StatelessWidget {
  final List<Question> questions;
  final Map<int, int> userAnswers;

  const ReviewScreen({super.key, required this.questions, required this.userAnswers});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sualların İcmalı')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final q = questions[index];
          final selected = userAnswers[index];
          final isCorrect = selected == q.correct;

          final tileColor = selected == null
              ? scheme.surfaceContainerHighest
              : isCorrect
                  ? Colors.green.withOpacity(0.12)
                  : scheme.errorContainer.withOpacity(0.45);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              leading: CircleAvatar(
                backgroundColor: selected == null
                    ? scheme.outline
                    : (isCorrect ? Colors.green : scheme.error),
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
              ),
              title: Text(q.question, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                selected == null
                    ? 'Cavab verilməyib'
                    : (isCorrect ? 'Doğru cavab' : 'Yanlış cavab'),
              ),
              backgroundColor: tileColor,
              collapsedBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              children: [
                ...q.options.asMap().entries.map((e) {
                  Color? textColor;
                  if (e.key == q.correct) textColor = Colors.green;
                  if (e.key == selected && !isCorrect) textColor = scheme.error;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          e.key == q.correct
                              ? Icons.check_circle
                              : (e.key == selected
                                  ? Icons.cancel
                                  : Icons.circle_outlined),
                          size: 18,
                          color: textColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.value,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: textColor != null ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
