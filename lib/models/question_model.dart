class Question {
  final String question;
  final List<String> options;
  final int correct;
  final String? image;

  Question({
    required this.question,
    required this.options,
    required this.correct,
    this.image,
  });

  // JSON-dan obyektə çevirmək üçün (Mövcuddur)
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      question: json['question'],
      options: List<String>.from(json['options']),
      correct: json['correct'],
      image: json['image'],
    );
  }

  // Obyektdən JSON-a çevirmək üçün (BU HİSSƏ ÇATIŞMIRDI)
  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correct': correct,
      'image': image,
    };
  }
}