import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final NumberFormat currencyFormat;
  final bool isBalance;

  const SummaryTile({
    super.key,
    required this.label,
    required this.amount,
    required this.currencyFormat,
    this.isBalance = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = amount >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isBalance 
                  ? (isPositive ? Colors.green.shade50 : Colors.red.shade50)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: isBalance 
                  ? Border.all(
                      color: isPositive ? Colors.green.shade100 : Colors.red.shade100)
                  : null,
            ),
            child: Text(
              currencyFormat.format(amount),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isBalance 
                    ? (isPositive ? Colors.green.shade800 : Colors.red.shade800)
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}