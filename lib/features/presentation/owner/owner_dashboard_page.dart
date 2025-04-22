import 'package:alruba_waterapp/features/presentation/owner/widget_charts/daily_sales_list.dart';
import 'package:alruba_waterapp/models/daily_financial.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class DailySalesPage extends StatefulWidget {
  const DailySalesPage({super.key});

  @override
  State<DailySalesPage> createState() => _DailySalesPageState();
}

class _DailySalesPageState extends State<DailySalesPage> {
  final _supabase = Supabase.instance.client;
  late Future<List<DailyFinancial>> _futureStats;
  bool _showAllDays = false;

  @override
  void initState() {
    super.initState();
    _futureStats = _loadStats();
  }

  Future<List<DailyFinancial>> _loadStats() async {
    final response = await _supabase
        .from('daily_gross_margin')
        .select('date, total_revenue, gross_profit')
        .order('date', ascending: false);

    return (response as List).map((row) => DailyFinancial(
      date: DateTime.parse(row['date'] as String),
      totalRevenue: (row['total_revenue'] as num).toDouble(),
      grossProfit: (row['gross_profit'] as num).toDouble(),
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Analytics'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: FutureBuilder<List<DailyFinancial>>(
        future: _futureStats,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final stats = snap.data ?? [];
          if (stats.isEmpty) {
            return const Center(child: Text('No sales data available'));
          }

          return DailySalesList(
            dailySales: stats,
            showAllDays: _showAllDays,
            onToggle: () => setState(() => _showAllDays = !_showAllDays),
          );
        },
      ),
    );
  }
}