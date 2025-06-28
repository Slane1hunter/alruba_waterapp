class ExpenseEntry {
  final DateTime date;
  final String category;
  final double amount;

  ExpenseEntry({
    required this.date,
    required this.category,
    required this.amount,
  });

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry(
      date: DateTime.parse(json['date']),
      category: json['category'],
      amount: (json['amount'] as num).toDouble(),
    );
  }
}