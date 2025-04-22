import 'package:alruba_waterapp/models/daily_financial.dart';
import 'package:flutter/material.dart';

class DailySalesList extends StatefulWidget {
  final List<DailyFinancial> dailySales;
  final bool showAllDays;
  final VoidCallback onToggle;

  const DailySalesList({
    super.key,
    required this.dailySales,
    required this.showAllDays,
    required this.onToggle,
  });

  @override
  State<DailySalesList> createState() => _DailySalesListState();
}

class _DailySalesListState extends State<DailySalesList> {
  final Map<String, bool> _monthExpansionStates = {};

  @override
  Widget build(BuildContext context) {
    final months = _groupByMonth(widget.dailySales);
    
    return Column(
      children: [
        _buildHeader(context),
        if (widget.showAllDays)
          Expanded(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: months.length,
              itemBuilder: (context, index) => _buildMonthCard(
                months.keys.elementAt(index),
                months.values.elementAt(index),
              ),
            ),
          ),
      ],
    );
  }

  Map<String, List<DailyFinancial>> _groupByMonth(List<DailyFinancial> sales) {
    final Map<String, List<DailyFinancial>> grouped = {};
    for (final daily in sales) {
      final monthKey = daily.monthLabel;
      grouped.putIfAbsent(monthKey, () => []).add(daily);
    }
    return grouped;
  }

  Widget _buildMonthCard(String month, List<DailyFinancial> days) {
    final isExpanded = _monthExpansionStates[month] ?? false;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          ListTile(
            title: Text(month, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _monthExpansionStates[month] = !isExpanded),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: days.map((daily) => _buildDayTile(daily)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayTile(DailyFinancial daily) {
    return ListTile(
      title: Text(daily.dateLabel),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Revenue: ${daily.revenueFormatted}'),
          _buildDetailRow('Profit: ${daily.profitFormatted}', 
            color: daily.grossProfit >= 0 ? Colors.green : Colors.red),
        ],
      ),
      trailing: Icon(
        daily.grossProfit >= 0 ? Icons.trending_up : Icons.trending_down,
        color: daily.grossProfit >= 0 ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildDetailRow(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.grey.shade700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: widget.onToggle,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sales Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
            Icon(
              widget.showAllDays ? Icons.expand_less : Icons.expand_more,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}