import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// لوحة تحكم المالك - تعرض الأداء المالي الشهري واليومي
/// تمت ترجمة الواجهة بالكامل للغة العربية مع دعم التخطيط من اليمين لليسار
class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'ar_LB', symbol: 'ل.ل ', decimalDigits: 0);

  /// حوامل البيانات الخام -----------------------------------------------------
  List<Map<String, dynamic>> _dailySales = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _monthlySummary = [];
  bool _isLoading = true;

  // ──────────────────────────────────────────────────────────────────────────
  // دورة الحياة
  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // جلب البيانات
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
              content: Text('خطأ في تحميل البيانات: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDailySales() async {
    final raw = await _supabase.from('sales').select(r'''
        created_at,
        payment_date,
        quantity,
        price_per_unit,
        total_amount,
        payment_status,
        customer:customers!sales_customer_id_fkey (name, phone),
        product:products!sales_product_id_fkey (name, production_cost),
        location:locations!sales_location_id_fkey (name),
        sold_by,
        seller:profiles!sold_by (first_name, last_name)
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
                'rawSales': <Map<String, dynamic>>[],
              });

      final entry = grouped[key]!;
      final qty = (sale['quantity'] as num?)?.toDouble() ?? 0.0;
      final price = (sale['price_per_unit'] as num?)?.toDouble() ?? 0.0;
      final prod = sale['product'] as Map<String, dynamic>? ?? {};
      final cost = (prod['production_cost'] as num?)?.toDouble() ?? 0.0;
      final name = (prod['name'] as String?) ?? 'منتج غير معروف';

      entry['revenue'] = (entry['revenue'] as double) + qty * price;
      entry['cogs'] = (entry['cogs'] as double) + qty * cost;
      (entry['products'] as List).add({
        'name': name,
        'quantity': qty,
        'total': qty * price,
      });
      (entry['rawSales'] as List).add(sale);
    }

    if (mounted) {
      setState(() => _dailySales = grouped.values.toList().reversed.toList());
    }
  }

  Future<void> _fetchExpenses() async {
    final raw = await _supabase
        .from('expenses')
        .select(r'date, amount, description') // Added description
        .order('date', ascending: false);

    if (mounted) {
      setState(() {
        _expenses = (raw as List<dynamic>)
            .map((e) => {
                  'date': e['date'] as String,
                  'amount': (e['amount'] as num?)?.toDouble() ?? 0.0,
                  'description': e['description'] as String? ?? 'بدون وصف',
                })
            .toList();
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // تجميع البيانات
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
              'expenses': 0.0, // Ensure this exists
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

  // Process expenses
  for (final exp in _expenses) {
    final dt = DateTime.parse(exp['date'] as String);
    final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    if (monthly.containsKey(key)) {
      monthly[key]!['expenses'] =
          (monthly[key]!['expenses'] as double) + (exp['amount'] as double);
    }
  }

  // Calculate net profit
  for (final m in monthly.values) {
    final gross = (m['revenue'] as double) - (m['cogs'] as double);
    m['net_profit'] = gross - (m['expenses'] as double);
  }

  if (mounted) setState(() => _monthlySummary = monthly.values.toList());
}

  // ──────────────────────────────────────────────────────────────────────────
  // واجهة المستخدم
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة تحكم المالك'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'تحديث البيانات',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'تصدير تقرير سنوي',
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
                          Center(child: Text('لا توجد بيانات للعرض')),
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
      ),
    );
  }

  // بطاقة الشهر -------------------------------------------------------------
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy', 'ar').format(monthDt),
                style:
                    TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _exportMonthlyExcel(m),
              tooltip: 'تصدير التقرير الشهري',
            ),
          ],
        ),
        subtitle: _buildProfitIndicator(m['net_profit'] as double, cs),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildMetricRow('الإيرادات', m['revenue'] as double, cs: cs),
                _buildMetricRow('تكلفة البضاعة المباعة', m['cogs'] as double,
                    cs: cs),
                _buildMetricRow('المصروفات', m['expenses'] as double, cs: cs),
                _buildMetricRow('صافي الربح', m['net_profit'] as double,
                    isTotal: true, cs: cs),
                const SizedBox(height: 16),
                _buildProductSummary(
                    m['products'] as Map<String, Map<String, dynamic>>,
                    'ملخص المنتجات الشهري',
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

  // بطاقة اليوم -----------------------------------------------------------------
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
          title: Text(DateFormat('EEE, MMM d', 'ar').format(dt)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniMetric(
                  label: 'إيراد', value: d['revenue'] as double, cs: cs),
              _MiniMetric(label: 'تكلفة', value: d['cogs'] as double, cs: cs),
              _MiniMetric(
                label: 'ربح',
                value: (d['revenue'] as double) - (d['cogs'] as double),
                cs: cs,
                isProfit: true,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('تحميل التقرير اليومي'),
                  onPressed: () => _exportSingleDayExcel(d),
                ),
              ),
            ],
          ),
          children: [
            _buildProductSummary(dailyProd, 'ملخص المنتجات اليومي', cs,
                isDaily: true),
          ],
        ));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // عناصر واجهة قابلة لإعادة الاستخدام
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMetricRow(String label, double value,
      {bool isTotal = false, required ColorScheme cs}) {
    final isProfit = label.toLowerCase().contains('ربح');
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
                        child: Text('المنتج',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('الكمية',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('المجموع',
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

    try {
      final excel = xls.Excel.createExcel();
      final sheet = excel['Day Summary'];

      final date = day['date'] as String;
      final revenue = day['revenue'] as double;
      final cogs = day['cogs'] as double;
      final profit = revenue - cogs;
      final products = day['products'] as List<dynamic>;
      final rawSales = day['rawSales'] as List<dynamic>;

      // Get daily expenses
      final dayExpenses = _expenses.where((e) => e['date'] == date).toList();
      final totalExpenses = dayExpenses.fold<double>(
          0, (sum, exp) => sum + (exp['amount'] as double));

      // Header with date
      sheet.appendRow(['التقرير اليومي', '']);
      sheet.appendRow(['التاريخ', date]);
      sheet.appendRow(['']);

      // Summary section
      sheet.appendRow(['الملخص اليومي', '']);
      sheet.appendRow(['الإيرادات', revenue]);
      sheet.appendRow(['تكلفة البضاعة المباعة', cogs]);
      sheet.appendRow(['الربح', profit]);
      sheet.appendRow(['المصروفات', totalExpenses]);
      sheet.appendRow(['صافي الربح بعد المصروفات', profit - totalExpenses]);
      sheet.appendRow(['']);

      // Products sold section
      sheet.appendRow(['المنتجات المباعة', '']);
      sheet.appendRow(['المنتج', 'الكمية', 'المجموع']);

      for (final p in products) {
        sheet.appendRow([p['name'], p['quantity'], p['total']]);
      }
      sheet.appendRow(['']);

      // Detailed sales section
      sheet.appendRow(['التفاصيل الكاملة للمبيعات', '']);
      sheet.appendRow([
        'الوقت',
        'العميل',
        'المنتج',
        'الكمية',
        'السعر',
        'المجموع',
        'حالة الدفع',
        'البائع',
        'الموقع'
      ]);

      for (final sale in rawSales) {
        final createdAt = DateFormat('HH:mm')
            .format(DateTime.parse(sale['created_at']).toLocal());
        final customer = sale['customer']?['name']?.toString() ?? 'غير معروف';
        final product = sale['product']?['name']?.toString() ?? 'غير معروف';
        final quantity = sale['quantity'];
        final price = sale['price_per_unit'];
        final total = sale['total_amount'];
        final status =
            _translatePaymentStatus(sale['payment_status'] as String? ?? '');
        final seller = sale['seller'] != null
            ? '${sale['seller']['first_name']} ${sale['seller']['last_name']}'
            : 'غير معروف';
        final location = sale['location']?['name']?.toString() ?? 'غير معروف';

        sheet.appendRow([
          createdAt,
          customer,
          product,
          quantity,
          price,
          total,
          status,
          seller,
          location
        ]);
      }

      // Expenses section
      if (dayExpenses.isNotEmpty) {
        sheet.appendRow(['']);
        sheet.appendRow(['المصروفات اليومية', '']);
        sheet.appendRow(['الوصف', 'المبلغ']);

        for (final exp in dayExpenses) {
          sheet.appendRow(
              [exp['description'] as String? ?? 'بدون وصف', exp['amount']]);
        }

        sheet.appendRow(['الإجمالي', totalExpenses]);
      }

      final fileBytes = excel.encode();
      final downloadsDir =
          Directory('/storage/emulated/0/Download/alrubaspreadsheet');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final filePath = '${downloadsDir.path}/day_$date.xlsx';
      final file = File(filePath)..createSync(recursive: true);
      file.writeAsBytesSync(fileBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تصدير التقرير اليومي إلى: $filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')),
        );
      }
      print('Daily Excel export error: $e');
    }
  }

  Future<void> _exportMonthlyExcel(Map<String, dynamic> month) async {
    if (!await requestStoragePermission(context)) return;

    try {
      final excel = xls.Excel.createExcel();
      final summarySheet = excel['ملخص الشهر'];
      final detailsSheet = excel['تفاصيل المبيعات'];
      final expensesSheet = excel['المصروفات']; // New expenses sheet

      final monthKey = month['month'] as String;
      final monthTitle =
          DateFormat('MMMM yyyy', 'ar').format(DateTime.parse('$monthKey-01'));

      // Month summary sheet
      summarySheet.appendRow(['التقرير الشهري', '']);
      summarySheet.appendRow(['الشهر', monthTitle]);
      summarySheet.appendRow(['']);

      // Financial summary
      summarySheet.appendRow(['الملخص المالي', '']);
      summarySheet.appendRow(['الإيرادات', month['revenue']]);
      summarySheet.appendRow(['تكلفة البضاعة المباعة', month['cogs']]);
      summarySheet.appendRow(['المصروفات', month['expenses']]);
      summarySheet.appendRow(['صافي الربح', month['net_profit']]);
      summarySheet.appendRow(['']);

      // Product summary
      summarySheet.appendRow(['المنتجات المباعة', '']);
      summarySheet.appendRow(['المنتج', 'الكمية', 'المجموع']);

      final products = month['products'] as Map<String, Map<String, dynamic>>;
      for (final entry in products.entries) {
        summarySheet.appendRow([
          entry.key,
          entry.value['quantity'],
          entry.value['total'],
        ]);
      }

      // Daily summaries
      summarySheet.appendRow(['']);
      summarySheet.appendRow(['الملخص اليومي', '']);
      summarySheet
          .appendRow(['التاريخ', 'الإيرادات', 'التكلفة', 'الربح', 'المصروفات']);

      final dailySales = _dailySales.where((d) {
        final dt = DateTime.parse(d['date'] as String);
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}' == monthKey;
      }).toList();

      for (final day in dailySales) {
        final dayExpenses = _expenses
            .where((e) => e['date'] == day['date'])
            .fold<double>(0, (sum, exp) => sum + (exp['amount'] as double));

        summarySheet.appendRow([
          day['date'],
          day['revenue'],
          day['cogs'],
          (day['revenue'] as double) - (day['cogs'] as double),
          dayExpenses
        ]);
      }

      // Detailed sales sheet
      detailsSheet.appendRow(['تفاصيل جميع المبيعات للشهر', '']);
      detailsSheet.appendRow([
        'التاريخ',
        'الوقت',
        'العميل',
        'المنتج',
        'الكمية',
        'السعر',
        'المجموع',
        'حالة الدفع',
        'البائع',
        'الموقع'
      ]);

      for (final day in dailySales) {
        final rawSales = day['rawSales'] as List<dynamic>;
        for (final sale in rawSales) {
          final date = DateFormat('yyyy-MM-dd')
              .format(DateTime.parse(sale['created_at']).toLocal());
          final time = DateFormat('HH:mm')
              .format(DateTime.parse(sale['created_at']).toLocal());
          final customer = sale['customer']?['name']?.toString() ?? 'غير معروف';
          final product = sale['product']?['name']?.toString() ?? 'غير معروف';
          final quantity = sale['quantity'];
          final price = sale['price_per_unit'];
          final total = sale['total_amount'];
          final status =
              _translatePaymentStatus(sale['payment_status'] as String? ?? '');
          final seller = sale['seller'] != null
              ? '${sale['seller']['first_name']} ${sale['seller']['last_name']}'
              : 'غير معروف';
          final location = sale['location']?['name']?.toString() ?? 'غير معروف';

          detailsSheet.appendRow([
            date,
            time,
            customer,
            product,
            quantity,
            price,
            total,
            status,
            seller,
            location
          ]);
        }
      }

      // Expenses sheet
      expensesSheet.appendRow(['تفاصيل المصروفات الشهرية', '']);
      expensesSheet.appendRow(['التاريخ', 'الوصف', 'المبلغ']);

      final monthExpenses = _expenses.where((e) {
        final dt = DateTime.parse(e['date'] as String);
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}' == monthKey;
      }).toList();

      for (final exp in monthExpenses) {
        expensesSheet.appendRow([
          exp['date'],
          exp['description'] as String? ?? 'بدون وصف',
          exp['amount']
        ]);
      }

      expensesSheet.appendRow(['الإجمالي', '', month['expenses']]);

      final downloadsDir =
          Directory('/storage/emulated/0/Download/alrubaspreadsheet');
      final filePath = '${downloadsDir.path}/month_$monthKey.xlsx';
      final fileBytes = excel.encode();
      final file = File(filePath)..createSync(recursive: true);
      file.writeAsBytesSync(fileBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تصدير التقرير الشهري إلى: $filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')),
        );
      }
      print('Monthly Excel export error: $e');
    }
  }

  String _translatePaymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'مدفوع';
      case 'unpaid':
        return 'غير مدفوع';
      case 'deposit':
        return 'عربون';
      default:
        return status;
    }
  }

  Future<void> _exportYearlyExcel() async {
    if (!await requestStoragePermission(context)) return;

    try {
      final excel = xls.Excel.createExcel();
      final expensesSheet = excel['المصروفات السنوية']; // New expenses sheet

      // Add monthly summaries
      for (final month in _monthlySummary) {
        final sheet = excel[month['month']];
        final monthTitle = DateFormat('MMMM yyyy', 'ar')
            .format(DateTime.parse('${month['month']}-01'));

        sheet.appendRow(['الشهر', monthTitle]);
        sheet.appendRow([]);
        sheet.appendRow(['المنتج', 'الكمية', 'المجموع']);

        final products = month['products'] as Map<String, Map<String, dynamic>>;
        for (final entry in products.entries) {
          sheet.appendRow([
            entry.key,
            entry.value['quantity'],
            entry.value['total'],
          ]);
        }

        sheet.appendRow([]);
        sheet.appendRow(['الإيرادات', month['revenue']]);
        sheet.appendRow(['تكلفة البضاعة المباعة', month['cogs']]);
        sheet.appendRow(['المصروفات', month['expenses']]);
        sheet.appendRow(['صافي الربح', month['net_profit']]);
      }

      // Add yearly expenses summary
      expensesSheet.appendRow(['المصروفات السنوية', '']);
      expensesSheet.appendRow(['الشهر', 'المبلغ']);

      double yearlyExpenses = 0.0;
      for (final month in _monthlySummary) {
        final monthTitle = DateFormat('MMMM yyyy', 'ar')
            .format(DateTime.parse('${month['month']}-01'));

        expensesSheet.appendRow([monthTitle, month['expenses']]);

        yearlyExpenses += month['expenses'] as double;
      }

      expensesSheet.appendRow(['الإجمالي السنوي', yearlyExpenses]);

      final downloadsDir =
          Directory('/storage/emulated/0/Download/alrubaspreadsheet');
      final filePath =
          '${downloadsDir.path}/yearly_summary_${DateTime.now().year}.xlsx';
      final fileBytes = excel.encode();
      final file = File(filePath)..createSync(recursive: true);
      file.writeAsBytesSync(fileBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تصدير ملف السنة إلى: $filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تصدير التقرير السنوي: $e')),
        );
      }
      print('Yearly Excel export error: $e');
    }
  }
}
// ---------------------------------------------------------------------------
// شريحة القياسات الصغيرة المعروضة تحت كل يوم
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
    final nf = NumberFormat.currency(
        locale: 'ar_LB', symbol: 'ل.ل ', decimalDigits: 0);
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
   if (!Platform.isAndroid) {
    // No permission needed for desktop
    return true;
  }
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
          content: const Text('تم رفض الإذن بشكل دائم. افتح الإعدادات للسماح.'),
          action: SnackBarAction(
            label: 'الإعدادات',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب منح إذن التخزين لتصدير الملفات.')),
      );
    }

    return false;
  }

  return true;
}
