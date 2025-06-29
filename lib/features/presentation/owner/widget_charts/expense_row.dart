// import 'package:alruba_waterapp/models/expense_entry.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// class ExpenseRow extends StatelessWidget {
//   final ExpenseEntry expense;
//   final NumberFormat currencyFormat;

//   const ExpenseRow({
//     super.key,
//     required this.expense,
//     required this.currencyFormat,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 2,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: ListTile(
//         contentPadding: const EdgeInsets.symmetric(horizontal: 16),
//         leading: Container(
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: Colors.red.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: const Icon(Icons.arrow_circle_down, color: Colors.red, size: 18),
//         ),
//         title: Text(
//           expense.category,
//           style: const TextStyle(fontWeight: FontWeight.w500),
//         ),
//         subtitle: Text(
//           DateFormat('MMM d').format(expense.date),
//           style: TextStyle(
//             fontSize: 12,
//             color: Colors.grey.shade600,
//           ),
//         ),
//         trailing: Text(
//           currencyFormat.format(expense.amount),
//           style: const TextStyle(
//             color: Colors.red,
//             fontWeight: FontWeight.bold,
//             fontSize: 14,
//           ),
//         ),
//       ),
//     );
//   }
// }