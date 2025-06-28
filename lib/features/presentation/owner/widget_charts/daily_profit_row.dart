import 'package:alruba_waterapp/models/daily_profit.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailyProfitRow extends StatelessWidget {
  final DailyProfit profit;
  final NumberFormat currencyFormat;

  const DailyProfitRow({
    super.key,
    required this.profit,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getProfitColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            profit.profit >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
            color: _getProfitColor,
            size: 18,
          ),
        ),
        title: Text(
          DateFormat('EEE, MMM d').format(profit.date),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${currencyFormat.format(profit.revenue)} Revenue',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormat.format(profit.profit),
              style: TextStyle(
                color: _getProfitColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              currencyFormat.format(profit.productionCost),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _getProfitColor => 
    profit.profit >= 0 ? Colors.green.shade800 : Colors.red.shade800;
}