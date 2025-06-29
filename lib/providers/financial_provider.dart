import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_financial.dart';
import '../models/monthly_summary.dart';

/// Fetches daily financial summary from view `daily_financial_summary`
final dailySummaryProvider = FutureProvider.autoDispose<List<DailyFinancial>>((ref) async {
  final rows = await Supabase.instance.client
      .from('daily_financial_summary')
      .select();
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map((m) => DailyFinancial.fromMap(m))
      .toList();
});

/// Fetches monthly summary from view `monthly_summary`
final monthlySummaryProvider = FutureProvider.autoDispose<List<MonthlySummary>>((ref) async {
  final rows = await Supabase.instance.client
      .from('monthly_summary')
      .select();
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map((m) => MonthlySummary.fromMap(m))
      .toList();
});
