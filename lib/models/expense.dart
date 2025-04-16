
class Expense {
  final String id;
  final String type;
  final double amount;
  final String? description;
  final DateTime date;

  Expense({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    required this.date,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String?,
        date: DateTime.parse(json['date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'description': description,
        'date': date.toIso8601String(),
      };
}