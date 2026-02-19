import 'package:flutter/material.dart';
import '../theme_controller.dart';
import '../models/question_model.dart';
import 'review_screen.dart';

class ScoreScreen extends StatelessWidget {
  final int score;
  final int total;
  final String bankName;
  final List<Question> questions;
  final Map<int, int> userAnswers;

  const ScoreScreen({
    super.key,
    required this.score,
    required this.total,
    required this.bankName,
    required this.questions,
    required this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (score / total) * 100;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nəticə'),
        actions: [
          IconButton(
            tooltip: 'Tema',
            icon: Icon(isDarkMode(context) ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: toggleAppTheme,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primaryContainer.withOpacity(0.3), scheme.surface],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(bankName, 
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: score / total,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: percentage >= 50 ? Colors.green : scheme.error,
                        ),
                      ),
                      Text('${percentage.toInt()}%', 
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Statistikalar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ResultStat(
                    label: "Düzgün",
                    value: score.toString(),
                    color: Colors.green,
                  ),
                  _ResultStat(
                    label: "Səhv",
                    value: (total - score).toString(),
                    color: scheme.error,
                  ),
                ],
              ),
              
              const SizedBox(height: 48),

              // Düymələr
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReviewScreen(
                        questions: questions,
                        userAnswers: userAnswers,
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                ),
                icon: const Icon(Icons.fact_check_rounded),
                label: const Text('Sualları Təkrar Nəzərdən Keçir'),
              ),
              
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Ana Menyuya Qayıt'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Kiçik statistika vidceti
class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.w500)),
      ],
    );
  }
}