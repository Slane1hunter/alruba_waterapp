import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';


/// ---------------------------------------------------------------------------
/// OwnerDashboardPage – displays monthly & daily financial performance.
/// Logic for fetching / processing data is unchanged; only UI
/// and minor structural improvements were made for better efficiency.
/// ---------------------------------------------------------------------------
class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NumberFormat _currency =
      NumberFormat.currency(symbol: 'LBP ', decimalDigits: 0);

  /// Raw data holders ---------------------------------------------------------
  List<Map<String, dynamic>> _dailySales = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _monthlySummary = [];
  bool _isLoading = true;

  // ──────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DATA FETCHING
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchDailySales(),
        _fetchExpenses(),
      ]);
      _buildMonthlySummary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading data: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDailySales() async {
    final raw = await _supabase.from('sales').select(r'''
        payment_date,
        quantity,
        price_per_unit,
        products:products!sales_product_id_fkey (id, name, production_cost)
      ''').eq('payment_status', 'paid').order('payment_date', ascending: false);

    final Map<String, Map<String, dynamic>> grouped = {};
    for (final sale in raw as List<dynamic>) {
      final dateStr = sale['payment_date'] as String?;
      if (dateStr == null) continue;

      final day = DateTime.parse(dateStr).toLocal();
      final key = DateFormat('yyyy-MM-dd').format(day);

      grouped.putIfAbsent(
          key,
          () => {
                'date': key,
                'revenue': 0.0,
                'cogs': 0.0,
                'products': <Map<String, dynamic>>[],
              });

      final entry = grouped[key]!;
      final qty = (sale['quantity'] as num?)?.toDouble() ?? 0.0;
      final price = (sale['price_per_unit'] as num?)?.toDouble() ?? 0.0;
      final prod = sale['products'] as Map<String, dynamic>? ?? {};
      final cost = (prod['production_cost'] as num?)?.toDouble() ?? 0.0;
      final name = (prod['name'] as String?) ?? 'Unknown Product';

      entry['revenue'] = (entry['revenue'] as double) + qty * price;
      entry['cogs'] = (entry['cogs'] as double) + qty * cost;
      (entry['products'] as List).add({
        'name': name,
        'quantity': qty,
        'total': qty * price,
      });
    }

    if (mounted) {
      setState(() => _dailySales = grouped.values.toList().reversed.toList());
    }
  }

  Future<void> _fetchExpenses() async {
    final raw = await _supabase
        .from('expenses')
        .select(r'date, amount')
        .order('date', ascending: false);

    if (mounted) {
      setState(() {
        _expenses = (raw as List<dynamic>)
            .map((e) => {
                  'date': e['date'] as String,
                  'amount': (e['amount'] as num?)?.toDouble() ?? 0.0,
                })
            .toList();
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AGGREGATION
  // ──────────────────────────────────────────────────────────────────────────
  void _buildMonthlySummary() {
    final Map<String, Map<String, dynamic>> monthly = {};

    for (final day in _dailySales) {
      final dt = DateTime.parse(day['date'] as String);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

      monthly.putIfAbsent(
          key,
          () => {
                'month': key,
                'revenue': 0.0,
                'cogs': 0.0,
                'expenses': 0.0,
                'net_profit': 0.0,
                'products': <String, Map<String, dynamic>>{},
              });

      final m = monthly[key]!;
      m['revenue'] = (m['revenue'] as double) + (day['revenue'] as double);
      m['cogs'] = (m['cogs'] as double) + (day['cogs'] as double);

      for (final p in day['products'] as List<dynamic>) {
        final name = p['name'] as String;
        final prodMap = m['products'] as Map<String, Map<String, dynamic>>;
        prodMap.putIfAbsent(name, () => {'quantity': 0.0, 'total': 0.0});
        prodMap[name]!['quantity'] =
            (prodMap[name]!['quantity'] as double) + (p['quantity'] as double);
        prodMap[name]!['total'] =
            (prodMap[name]!['total'] as double) + (p['total'] as double);
      }
    }

    for (final exp in _expenses) {
      final dt = DateTime.parse(exp['date'] as String);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      if (monthly.containsKey(key)) {
        monthly[key]!['expenses'] =
            (monthly[key]!['expenses'] as double) + (exp['amount'] as double);
      }
    }

    for (final m in monthly.values) {
      final gross = (m['revenue'] as double) - (m['cogs'] as double);
      m['net_profit'] = gross - (m['expenses'] as double);
    }

    if (mounted) setState(() => _monthlySummary = monthly.values.toList());
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Yearly Report',
            onPressed: _monthlySummary.isEmpty ? null : _exportYearlyExcel,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _monthlySummary.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No data to display')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _monthlySummary.length,
                      itemBuilder: (context, index) => _buildMonthCard(
                        _monthlySummary[index],
                        cs,
                      ),
                    ),
            ),
    );
  }

  // Monthly card -------------------------------------------------------------
  Widget _buildMonthCard(Map<String, dynamic> m, ColorScheme cs) {
    final monthDt = DateTime.parse('${m['month']}-01');
    final monthKey = m['month'] as String;
    final daily = _dailySales.where((d) {
      final dt = DateTime.parse(d['date'] as String);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}' == monthKey;
    }).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            offset: const Offset(0, 3),
            color: cs.shadow.withOpacity(.08),
          )
        ],
      ),
      child: ExpansionTile(
        leading: Icon(Icons.bar_chart, color: cs.primary),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 16),
        title: Text(DateFormat('MMMM yyyy').format(monthDt),
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
        subtitle: _buildProfitIndicator(m['net_profit'] as double, cs),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildMetricRow('Revenue', m['revenue'] as double, cs: cs),
                _buildMetricRow('COGS', m['cogs'] as double, cs: cs),
                _buildMetricRow('Expenses', m['expenses'] as double, cs: cs),
                _buildMetricRow('Net Profit', m['net_profit'] as double,
                    isTotal: true, cs: cs),
                const SizedBox(height: 16),
                _buildProductSummary(
                    m['products'] as Map<String, Map<String, dynamic>>,
                    'Monthly Product Summary',
                    cs),
                const SizedBox(height: 16),
                ...daily.map((d) => _buildDayTile(d, cs)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Day tile -----------------------------------------------------------------
  Widget _buildDayTile(Map<String, dynamic> d, ColorScheme cs) {
    final dt = DateTime.parse(d['date'] as String);
    final Map<String, Map<String, dynamic>> dailyProd = {
      for (final p in d['products'] as List<dynamic>) p['name'] as String: p
    };

    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
              left: BorderSide(
                  color: cs.primary.withAlpha((.3 * 255).toInt()), width: 4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(DateFormat('EEE, MMM d').format(dt)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniMetric(label: 'Rev', value: d['revenue'] as double, cs: cs),
              _MiniMetric(label: 'COGS', value: d['cogs'] as double, cs: cs),
              _MiniMetric(
                label: 'Profit',
                value: (d['revenue'] as double) - (d['cogs'] as double),
                cs: cs,
                isProfit: true,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Download Daily Report'),
                  onPressed: () => _exportSingleDayExcel(d),
                ),
              ),
            ],
          ),
          children: [
            _buildProductSummary(dailyProd, 'Daily Product Summary', cs,
                isDaily: true),
          ],
        ));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // REUSABLE WIDGETS
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMetricRow(String label, double value,
      {bool isTotal = false, required ColorScheme cs}) {
    final isProfit = label.toLowerCase().contains('profit');
    final color = isProfit
        ? (value >= 0 ? cs.tertiary : Colors.red.shade700)
        : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: color,
              )),
          Text(
            _currency.format(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSummary(
      Map<String, Map<String, dynamic>> products, String title, ColorScheme cs,
      {bool isDaily = false}) {
    final rows = products.entries.map((e) {
      return TableRow(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(e.key),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text((e.value['quantity'] as double).toStringAsFixed(1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_currency.format(e.value['total'] as double)),
        ),
      ]);
    }).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDaily ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(2),
            },
            children: [
                  const TableRow(
                    decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey))),
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('Product',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('Quantity',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('Total',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ] +
                rows,
          ),
        ],
      ),
    );
  }

  Widget _buildProfitIndicator(double netProfit, ColorScheme cs) {
    final isPositive = netProfit >= 0;
    return Row(
      children: [
        Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
            size: 18),
        const SizedBox(width: 4),
        Text(
          _currency.format(netProfit),
          style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isPositive ? Colors.green.shade700 : Colors.red.shade700),
        ),
      ],
    );
  }

  Future<void> _exportSingleDayExcel(Map<String, dynamic> day) async {
  if (!await requestStoragePermission(context)) return;

  final excel = xls.Excel.createExcel();
  final sheet = excel['Day Summary'];

  final date = day['date'] as String;
  final revenue = day['revenue'] as double;
  final cogs = day['cogs'] as double;
  final profit = revenue - cogs;
  final products = day['products'] as List<dynamic>;

  sheet.appendRow(['Date', date]);
  sheet.appendRow([]);
  sheet.appendRow(['Product', 'Quantity', 'Total']);

  for (final p in products) {
    sheet.appendRow([p['name'], p['quantity'], p['total']]);
  }

  sheet.appendRow([]);
  sheet.appendRow(['Revenue', revenue]);
  sheet.appendRow(['COGS', cogs]);
  sheet.appendRow(['Profit', profit]);

  final fileBytes = excel.encode();

  final downloadsDir = Directory('/storage/emulated/0/Download/alrubaspreadsheet');
  if (!await downloadsDir.exists()) {
    await downloadsDir.create(recursive: true);
  }

  final filePath = '${downloadsDir.path}/day_$date.xlsx';
  final file = File(filePath)..createSync(recursive: true);
  file.writeAsBytesSync(fileBytes!);
  print('Excel file saved at: $filePath');

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported day file to: $filePath')),
    );
  }
}


 Future<void> _exportYearlyExcel() async {
  if (!await requestStoragePermission(context)) return;

  final excel = xls.Excel.createExcel();

  for (final month in _monthlySummary) {
    final sheet = excel[month['month']];
    final monthTitle = DateFormat('MMMM yyyy')
        .format(DateTime.parse('${month['month']}-01'));

    sheet.appendRow(['Month', monthTitle]);
    sheet.appendRow([]);
    sheet.appendRow(['Product', 'Quantity', 'Total']);

    final products = month['products'] as Map<String, Map<String, dynamic>>;
    for (final entry in products.entries) {
      sheet.appendRow([
        entry.key,
        entry.value['quantity'],
        entry.value['total'],
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow(['Revenue', month['revenue']]);
    sheet.appendRow(['COGS', month['cogs']]);
    sheet.appendRow(['Expenses', month['expenses']]);
    sheet.appendRow(['Net Profit', month['net_profit']]);
  }

  final downloadsDir = Directory('/storage/emulated/0/Download/alrubaspreadsheet');
  if (!await downloadsDir.exists()) {
    await downloadsDir.create(recursive: true);
  }

  final filePath = '${downloadsDir.path}/yearly_summary_${DateTime.now().year}.xlsx';
  final fileBytes = excel.encode();
  final file = File(filePath)..createSync(recursive: true);
  file.writeAsBytesSync(fileBytes!);
  print('Excel file saved at: $filePath');

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported yearly file to: $filePath')),
    );
  }
}

}

// ---------------------------------------------------------------------------
// Helper mini metric chip shown under each day
// ---------------------------------------------------------------------------
class _MiniMetric extends StatelessWidget {
  final String label;
  final double value;
  final bool isProfit;
  final ColorScheme cs;
  const _MiniMetric(
      {required this.label,
      required this.value,
      required this.cs,
      this.isProfit = false});

  @override
  Widget build(BuildContext context) {
    final bg = isProfit
        ? (value >= 0 ? Colors.green.shade50 : Colors.red.shade50)
        : cs.surfaceVariant;
    final txt = isProfit
        ? (value >= 0 ? Colors.green.shade700 : Colors.red.shade700)
        : cs.onSurfaceVariant;
    final nf = NumberFormat.currency(symbol: 'LBP ', decimalDigits: 0);
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label:', style: TextStyle(fontSize: 12, color: txt)),
          const SizedBox(width: 4),
          Text(nf.format(value),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: txt)),
        ],
      ),
    );
  }
}

Future<bool> requestStoragePermission(BuildContext context) async {
  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final sdkInt = androidInfo.version.sdkInt;

  PermissionStatus status;

  if (sdkInt >= 30) {
    status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
  } else {
    status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
  }

  if (!status.isGranted) {
    final isPermanentlyDenied = sdkInt >= 30
        ? await Permission.manageExternalStorage.isPermanentlyDenied
        : await Permission.storage.isPermanentlyDenied;

    if (isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permission permanently denied. Open settings to allow.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required to export files.')),
      );
    }

    return false;
  }

  return true;
}

