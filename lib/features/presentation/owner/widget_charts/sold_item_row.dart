// import 'package:alruba_waterapp/models/sold_item.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// class SoldItemRow extends StatelessWidget {
//   final SoldItem item;
//   final NumberFormat currencyFormat;

//   const SoldItemRow({
//     super.key,
//     required this.item,
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
//         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         leading: Container(
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: Colors.blue.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: const Icon(Icons.shopping_bag, color: Colors.blue, size: 20),
//         ),
//         title: Text(item.productName),
//         subtitle: Text(
//           DateFormat('MMM dd, yyyy – HH:mm').format(item.date),
//           style: TextStyle(color: Colors.grey.shade600),
//         ),
//         trailing: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             Text('${item.quantity}x'),
//             const SizedBox(height: 4),
//             Text(
//               currencyFormat.format(item.total),
//               style: const TextStyle(
//                 fontWeight: FontWeight.bold,
//                 color: Colors.green,
//               ),
//             ),
//             Text(
//               '${currencyFormat.format(item.pricePerUnit)}/unit',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey.shade600),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }