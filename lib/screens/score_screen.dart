import 'package:flutter/material.dart';
import '../theme_controller.dart';

class ScoreScreen extends StatelessWidget {
  final int score;
  final int total;
  final String bankName;

  const ScoreScreen({super.key, required this.score, required this.total, required this.bankName});

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
              Text(bankName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Card(
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
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: percentage >= 50 ? Colors.green : scheme.error,
                        ),
                      ),
                      Text('${percentage.toInt()}%', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Düzgün cavab: $score', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Səhv cavab: ${total - score}', style: TextStyle(fontSize: 18, color: scheme.error, fontWeight: FontWeight.bold)),
              const SizedBox(height: 36),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context),
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
