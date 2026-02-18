class Question {
  final String question;
  List<String> options; // final silindi
  int correct;         // final silindi
  final String? image;

  Question({
    required this.question,
    required this.options,
    required this.correct,
    this.image,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      question: json['question'],
      options: List<String>.from(json['options']),
      correct: json['correct'],
      image: json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correct': correct,
      'image': image,
    };
  }
}