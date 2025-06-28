import 'package:alruba_waterapp/features/presentation/owner/widget_charts/daily_profit_row.dart';
import 'package:alruba_waterapp/features/presentation/owner/widget_charts/expense_row.dart';
import 'package:alruba_waterapp/features/presentation/owner/widget_charts/sold_item_row.dart';
import 'package:alruba_waterapp/features/presentation/owner/widget_charts/summary_tile.dart';
import 'package:alruba_waterapp/models/daily_profit.dart';
import 'package:alruba_waterapp/models/expense_entry.dart';
import 'package:alruba_waterapp/models/monthly_summary.dart';
import 'package:alruba_waterapp/models/sold_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MonthSection extends ConsumerWidget {
  final MonthlySummary monthSummary;
  final List<DailyProfit> dailyProfits;
  final List<ExpenseEntry> expenses;
  final List<SoldItem> soldItems;
  final NumberFormat currencyFormat;

  const MonthSection({
    super.key,
    required this.monthSummary,
    required this.dailyProfits,
    required this.expenses,
    required this.currencyFormat,
    required this.soldItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final monthDays = dailyProfits.where((d) => 
      d.date.month == monthSummary.month.month &&
      d.date.year == monthSummary.month.year
    ).toList();

    final monthExpenses = expenses.where((e) =>
      e.date.month == monthSummary.month.month &&
      e.date.year == monthSummary.month.year
    ).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                theme.primaryColor.withAlpha(25),
                Colors.white,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_month, color: theme.primaryColor),
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM').format(monthSummary.month),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('yyyy').format(monthSummary.month),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.4,
                    ),
                    child: Text(
                      currencyFormat.format(monthSummary.netBalance),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: monthSummary.netBalance >= 0 
                            ? Colors.green.shade800 
                            : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    monthSummary.netBalance >= 0 ? 'Profit' : 'Loss',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: monthSummary.netBalance >= 0 
                          ? Colors.green.shade800 
                          : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            _buildSection('Daily Profits', Icons.trending_up, Colors.blue, [
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: monthDays.length,
                  itemBuilder: (context, index) => DailyProfitRow(
                    profit: monthDays[index],
                    currencyFormat: currencyFormat,
                  ),
                ),
              ),
            ]),
            _buildSection('Items Sold', Icons.shopping_cart, Colors.purple, [
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _buildSoldItems(monthSummary.month).length,
                  itemBuilder: (context, index) => _buildSoldItems(monthSummary.month)[index],
                ),
              ),
            ]),
            _buildSection('Monthly Expenses', Icons.money_off, Colors.orange, [
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: monthExpenses.length,
                  itemBuilder: (context, index) => ExpenseRow(
                    expense: monthExpenses[index],
                    currencyFormat: currencyFormat,
                  ),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SummaryTile(
                    label: 'Total Profit',
                    amount: monthSummary.totalProfit,
                    currencyFormat: currencyFormat,
                  ),
                  SummaryTile(
                    label: 'Total Expenses',
                    amount: monthSummary.totalExpenses,
                    currencyFormat: currencyFormat,
                  ),
                  const Divider(height: 24),
                  SummaryTile(
                    label: 'Net Balance',
                    amount: monthSummary.netBalance,
                    currencyFormat: currencyFormat,
                    isBalance: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSoldItems(DateTime month) {
    final filteredItems = soldItems.where((item) => 
      item.date.month == month.month &&
      item.date.year == month.year
    ).toList();

    if (filteredItems.isEmpty) {
      return [
        const ListTile(
          title: Text('No items sold this month',
              style: TextStyle(color: Colors.grey))
        )
      ];
    }

    return filteredItems.map((item) => SoldItemRow(
      item: item,
      currencyFormat: currencyFormat,
    )).toList();
  }

  Widget _buildSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}