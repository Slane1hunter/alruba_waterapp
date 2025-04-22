import 'package:intl/intl.dart';

class DailyFinancial {
  final DateTime date;
  final double totalRevenue;
  final double grossProfit;

  const DailyFinancial({
    required this.date,
    required this.totalRevenue,
    required this.grossProfit,
  });

  String get monthLabel => DateFormat.yMMM().format(date);
  String get dateLabel => DateFormat.MMMd().format(date);
  String get revenueFormatted => NumberFormat.simpleCurrency().format(totalRevenue);
  String get profitFormatted => NumberFormat.simpleCurrency().format(grossProfit);
}


class MonthlyFinancial {
  final DateTime month;
  final List<DailyFinancial> days;
  double get totalRevenue => days.fold(0, (sum, day) => sum + day.totalRevenue);

  MonthlyFinancial(this.month, this.days);

  String get monthLabel => DateFormat.yMMM().format(month);
  String get revenueFormatted => NumberFormat.simpleCurrency().format(totalRevenue);
}

