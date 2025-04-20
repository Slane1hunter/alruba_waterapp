// lib/repositories/expense_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../services/supabase_service.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

class ExpenseRepository {
  /// Fetch all expenses, newest first.
  Future<List<Expense>> fetchExpenses() async {
    // returns List<Map<String,dynamic>>
    final response = await SupabaseService.client
      .from('expenses')
      .select()
      .order('date', ascending: false);

    // cast each item into your Expense model
    return (response as List)
        .map((item) => Expense.fromMap(item as Map<String, dynamic>))
        .toList();
  }
  // In expense_repository.dart
Future<List<String>> getExpenseTypes() async {
  final response = await SupabaseService.client
    .from('expenses')
    .select('type')
    .order('type', ascending: true);

  // Handle null response and null type values
  final data = response as List<dynamic>? ?? [];

  return data
    .map((e) => e['type']?.toString() ?? '') // Handle null type values
    .where((t) => t.isNotEmpty) // Filter out empty strings
    .toSet()
    .toList();
}

  /// Create a new expense and return the created record.
  Future<Expense> addExpense(Expense expense) async {
    // .insert(...).select().single() returns a Map<String,dynamic>
    final inserted = await SupabaseService.client
      .from('expenses')
      .insert(expense.toMap())
      .select()
      .single();

    return Expense.fromMap(inserted);
  }

  /// Update an existing expense by its ID.
  Future<Expense> updateExpense(Expense expense) async {
    final updated = await SupabaseService.client
      .from('expenses')
      .update(expense.toMap())
      .eq('id', expense.id)
      .select()
      .single();

    return Expense.fromMap(updated);
  }

  /// Delete an expense by its ID.
  Future<void> deleteExpense(String id) async {
    await SupabaseService.client
      .from('expenses')
      .delete()
      .eq('id', id);
  }
  
}
