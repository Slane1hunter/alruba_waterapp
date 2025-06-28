import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

/// ─────────────────────────────────────────────────────────────
///  MODEL
/// ─────────────────────────────────────────────────────────────
class DailyMetrics {
  final double revenue;
  final double cogs;
  final double profit;
  final Map<String, int> itemsSold;
  const DailyMetrics(
      {required this.revenue,
      required this.cogs,
      required this.profit,
      required this.itemsSold});
}

class MonthlyRecord {
  final DateTime month; // first day‑of‑month
  final double revenue;
  final double expenses;
  final double net;
  const MonthlyRecord(
      {required this.month,
      required this.revenue,
      required this.expenses,
      required this.net});
}

class OwnerMetrics {
  final DailyMetrics today;
  final List<MonthlyRecord> monthly;
  const OwnerMetrics({required this.today, required this.monthly});
}

/// ─────────────────────────────────────────────────────────────
///  PROVIDER
/// ─────────────────────────────────────────────────────────────
final ownerMetricsProvider = FutureProvider<OwnerMetrics>((ref) async {
  final supa = SupabaseService.client;

  // ---------- TODAY ----------
  final today = DateTime.now().toLocal();
  final start = DateTime(today.year, today.month, today.day);
  final end = DateTime(today.year, today.month, today.day, 23, 59, 59);

  // 1) revenue / cogs / profit  (from daily_financial_summary view)
  final dRow = await supa
      .from('daily_financial_summary')
      .select('revenue,cogs,net_profit')
      .eq('date', DateFormat('yyyy-MM-dd').format(start))
      .maybeSingle();

  final revenue = (dRow?['revenue'] as num?)?.toDouble() ?? 0;
  final cogs = (dRow?['cogs'] as num?)?.toDouble() ?? 0;
  final profit = (dRow?['net_profit'] as num?)?.toDouble() ?? 0;

  // 2) Items sold today  (from sales_with_products view)
  final itemRows = await supa
      .from('sales_with_products')
      .select('product_name,quantity')
      .gte('created_at', start.toIso8601String())
      .lte('created_at', end.toIso8601String());

  final itemMap = <String, int>{};
  for (final r in (itemRows as List)) {
    final name = (r['product_name'] ?? '–') as String;
    final qty = (r['quantity'] as int?) ?? 0;
    itemMap[name] = (itemMap[name] ?? 0) + qty;
  }

  // ---------- MONTHLY ----------
  final mRows = await supa
      .from('monthly_summary')
      .select('month,total_profit,total_expenses,net_balance')
      .order('month', ascending: false);

  final monthly = <MonthlyRecord>[
    for (final r in (mRows as List))
      MonthlyRecord(
        month: DateTime.parse(r['month'] as String).toLocal(),
        revenue: (r['total_profit'] as num).toDouble() + // profit + expenses = revenue
            (r['total_expenses'] as num).toDouble(),
        expenses: (r['total_expenses'] as num).toDouble(),
        net: (r['net_balance'] as num).toDouble(),
      )
  ];

  return OwnerMetrics(
    today: DailyMetrics(
        revenue: revenue, cogs: cogs, profit: profit, itemsSold: itemMap),
    monthly: monthly,
  );
});
