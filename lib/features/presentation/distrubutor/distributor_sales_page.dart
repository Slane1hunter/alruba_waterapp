import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:alruba_waterapp/providers/distributor_sales_provider.dart';
import 'package:alruba_waterapp/providers/location_provider.dart';

/// Internal event type for grouping sales and payments by day
class _DayEvent {
  final DistributorSale sale;
  final DateTime time;
  final bool isPayment;

  _DayEvent(this.sale, this.time, this.isPayment);
}

class DistributorSalesPage extends ConsumerStatefulWidget {
  const DistributorSalesPage({super.key});

  @override
  ConsumerState<DistributorSalesPage> createState() =>
      _DistributorSalesPageState();
}

class _DistributorSalesPageState extends ConsumerState<DistributorSalesPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchText = '';
  String? _locationFilter;

  final _lbpFormat = NumberFormat.currency(
    locale: 'ar_LB',
    symbol: 'LBP ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(distributorSalesProvider);
    final locationsAsync = ref.watch(locationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('مبيعاتي')),
      body: Column(
        children: [
          _buildFilterSection(context, locationsAsync),
          Expanded(
            child: salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('خطأ: $err')),
              data: (allSales) {
                final filtered = _applyFilters(allSales);
                if (filtered.isEmpty)
                  return const Center(child: Text('لا توجد سجلات مطابقة.'));
                return _buildEventsList(filtered);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext ctx, AsyncValue<List<dynamic>> locs) {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم العميل...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) =>
                  setState(() => _searchText = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildLocationDropdown(locs)),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text('نطاق التاريخ'),
                  onPressed: () => _pickDateRange(ctx),
                ),
              ],
            ),
            if (_startDate != null && _endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${DateFormat('MMM dd, yyyy', 'ar').format(_startDate!)} — ${DateFormat('MMM dd, yyyy', 'ar').format(_endDate!)}',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDropdown(AsyncValue<List<dynamic>> locs) {
    return locs.when(
      data: (locations) {
        final items = <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
              value: null, child: Text('جميع المواقع')),
          ...locations.map((l) =>
              DropdownMenuItem<String?>(value: l.name, child: Text(l.name))),
        ];
        return DropdownButtonFormField<String?>(
          value: _locationFilter,
          items: items,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.location_on),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (v) => setState(() => _locationFilter = v),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('خطأ: $e'),
    );
  }

  Future<void> _pickDateRange(BuildContext ctx) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: ctx,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)), end: now),
      locale: const Locale('ar'),
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  List<DistributorSale> _applyFilters(List<DistributorSale> all) {
    return all.where((s) {
      if (_searchText.isNotEmpty &&
          !s.customerName.toLowerCase().contains(_searchText)) return false;
      if (_locationFilter != null &&
          !s.location.toLowerCase().contains(_locationFilter!.toLowerCase()))
        return false;
      if (_startDate != null && _endDate != null) {
        final d = s.date.toLocal();
        if (d.isBefore(_startDate!) || d.isAfter(_endDate!)) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildEventsList(List<DistributorSale> sales) {
    final Map<String, List<_DayEvent>> eventsByDay = {};
    for (final s in sales) {
      final saleDate = s.date.toLocal();
      final saleKey = DateFormat('yyyy-MM-dd').format(saleDate);

      // Always add the sale event
      eventsByDay
          .putIfAbsent(saleKey, () => [])
          .add(_DayEvent(s, s.date, false));

      // Only add payment if it exists and is on a different day
      if (s.paymentDate != null) {
        final paymentDate = s.paymentDate!.toLocal();

        // Check if payment is on a different day
        if (!_isSameDay(saleDate, paymentDate)) {
          final payKey = DateFormat('yyyy-MM-dd').format(paymentDate);
          eventsByDay
              .putIfAbsent(payKey, () => [])
              .add(_DayEvent(s, s.paymentDate!, true));
        }
      }
    }

    // Sort days descending (newest day first)
    final days = eventsByDay.keys.toList()..sort((b, a) => a.compareTo(b));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: days.length,
      itemBuilder: (ctx, idx) {
        final day = days[idx];
        // sort events within a day: newest first
        final events = eventsByDay[day]!
          ..sort((b, a) => a.time.compareTo(b.time));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                DateFormat('MMM dd, yyyy', 'ar').format(DateTime.parse(day)),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              children: events.map((e) {
                if (e.isPayment) {
                  // payment tile shows original sale date
                  return ListTile(
                    leading:
                        const Icon(Icons.attach_money, color: Colors.green),
                    title: Text(
                      'دفع مقابل البيع بتاريخ ${DateFormat('MMM dd', 'ar').format(e.sale.date.toLocal())}',
                    ),
                    subtitle: Text(
                      '${e.sale.customerName} — ${_lbpFormat.format(e.sale.totalAmount)}',
                    ),
                    trailing:
                        Text(DateFormat('HH:mm').format(e.time.toLocal())),
                  );
                } else {
                  // sale tile
                  final status = e.sale.paymentStatus;
                  IconData icon;
                  Color color;
                  if (status == 'paid') {
                    icon = Icons.check;
                    color = Colors.green;
                  } else if (status == 'deposit') {
                    icon = Icons.account_balance_wallet;
                    color = Colors.blue;
                  } else {
                    icon = Icons.hourglass_empty;
                    color = Colors.orange;
                  }
                  return ListTile(
                    leading: CircleAvatar(
                        backgroundColor: color,
                        child: Icon(icon, color: Colors.white)),
                    title: Text(e.sale.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle:
                        Text('${e.sale.productName} • الكمية: ${e.sale.quantity}'),
                    trailing: Text(_lbpFormat.format(e.sale.totalAmount)),
                    onTap: () => _showSaleDetailsDialog(e.sale),
                  );
                }
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // Helper method to compare dates ignoring time
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showSaleDetailsDialog(DistributorSale sale) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('البيع لـ ${sale.customerName}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(sale.date.toLocal())}'),
                const SizedBox(height: 4),
                Text('المنتج: ${sale.productName}'),
                const SizedBox(height: 4),
                Text('الكمية: ${sale.quantity}'),
                const SizedBox(height: 4),
                Text('السعر للوحدة: ${_lbpFormat.format(sale.pricePerUnit)}'),
                const SizedBox(height: 4),
                Text('الإجمالي: ${_lbpFormat.format(sale.totalAmount)}'),
                const SizedBox(height: 4),
                Text('الحالة: ${sale.paymentStatus.toUpperCase()}'),
                const SizedBox(height: 4),
                Text(
                  'تم الدفع في: ${sale.paymentDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(sale.paymentDate!) : '—'}',
                ),
                const SizedBox(height: 4),
                Text('الموقع: ${sale.location}'),
                const SizedBox(height: 12),
                if (sale.phone.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('اتصل بالعميل'),
                    onPressed: () => _openDialer(sale.phone),
                  ),
                if (sale.preciseLocation != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text('افتح في الخرائط'),
                    onPressed: () => _openInMaps(sale.preciseLocation!),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))
          ],
        );
      },
    );
  }

  Future<void> _openDialer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openInMaps(String loc) async {
    final googleUri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$loc');
    if (await canLaunchUrl(googleUri)) await launchUrl(googleUri);
  }
}
