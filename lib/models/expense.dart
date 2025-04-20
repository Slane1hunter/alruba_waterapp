
class Expense {
  final String id;
  final String type;
  final double amount;
  final String? description;
  final DateTime date;
  final bool isRecurring;
  final DateTime? recurrenceEnd;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    required this.date,
    this.isRecurring = false,
    this.recurrenceEnd,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      isRecurring: map['is_recurring'] as bool? ?? false,
      recurrenceEnd: map['recurrence_end'] != null
          ? DateTime.parse(map['recurrence_end'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String().split('T').first,
      'is_recurring': isRecurring,
      'recurrence_end': recurrenceEnd?.toIso8601String().split('T').first,
    };
  }
}
