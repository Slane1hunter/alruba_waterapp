import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
//import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alruba_waterapp/services/supabase_service.dart';
import 'package:alruba_waterapp/providers/location_provider.dart';

class _DayEvent {
  final Map<String, dynamic> sale;
  final DateTime time;
  final bool isPayment;

  _DayEvent(this.sale, this.time, this.isPayment);
}

class ManagerDashboardPage extends ConsumerStatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  ConsumerState<ManagerDashboardPage> createState() =>
      _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends ConsumerState<ManagerDashboardPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchText = '';
  String? _locationFilter;
  String? _soldByFilter;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final _lbp =
      NumberFormat.currency(locale: 'ar_LB', symbol: 'ل.ل ', decimalDigits: 0);

  static const _columns = '''
    id, created_at, quantity, price_per_unit, total_amount, payment_status, payment_date,
    customer:customers!fk_sales_customer(name, phone, precise_location),
    product:products!sales_product_id_fkey(name),
    location:locations!sales_location_id_fkey(name),
    sold_by, 
    seller:profiles!sold_by(first_name, last_name)
  ''';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchSales() async {
    final query = SupabaseService.client
        .from('sales')
        .select(_columns)
        .order('created_at', ascending: false);

    final response = await query;
    final rows = List<Map<String, dynamic>>.from(response);

    return rows.where((sale) {
      final created = DateTime.parse(sale['created_at']).toLocal();
      final paymentDate = sale['payment_date'] != null
          ? DateTime.parse(sale['payment_date']).toLocal()
          : null;

      final inDateRange = _startDate != null && _endDate != null
          ? (created.isAfter(_startDate!) && created.isBefore(_endDate!)) ||
              (paymentDate != null &&
                  paymentDate.isAfter(_startDate!) &&
                  paymentDate.isBefore(_endDate!))
          : true;

      final customerName =
          sale['customer']['name']?.toString().toLowerCase() ?? '';
      final productName =
          sale['product']['name']?.toString().toLowerCase() ?? '';
      final searchMatch = _searchText.isEmpty ||
          customerName.contains(_searchText) ||
          productName.contains(_searchText);

      final locationMatch = _locationFilter == null ||
          sale['location']['name']?.toString() == _locationFilter;
      final sellerMatch =
          _soldByFilter == null || sale['sold_by'] == _soldByFilter;

      return inDateRange && searchMatch && locationMatch && sellerMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة مبيعات'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 260,
                flexibleSpace:
                    FlexibleSpaceBar(background: _buildFilters(theme)),
              ),
              _buildSales(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(ThemeData t) => Container(
        decoration: BoxDecoration(
          color: t.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'بحث عن العميل أو المنتج...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _searchText = '';
                  }),
                ),
                filled: true,
                fillColor: t.colorScheme.surfaceContainerHighest,
              ),
              onChanged: (v) => setState(() => _searchText = v.toLowerCase()),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.calendar_month, color: t.colorScheme.primary),
              title: Text(_startDate != null && _endDate != null
                  ? '${DateFormat('dd MMM', 'ar').format(_startDate!)} - ${DateFormat('dd MMM', 'ar').format(_endDate!)}'
                  : 'اختر نطاق التاريخ'),
              trailing: const Icon(Icons.arrow_drop_down),
              tileColor: t.colorScheme.surfaceContainerHighest,
              onTap: _pickDateRange,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _buildLocationDrop(t)),
              const SizedBox(width: 16),
              Expanded(child: _buildSellerDrop(t)),
            ]),
          ],
        ),
      );

  Widget _buildLocationDrop(ThemeData t) => ref.watch(locationsProvider).when(
        data: (locs) => _FilterDrop<String>(
          hint: 'كل المواقع',
          items: locs.map((e) => e.name).toList(),
          value: _locationFilter,
          onChanged: (v) => setState(() => _locationFilter = v),
          theme: t,
          icon: Icons.location_on_outlined,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Text('خطأ: $e', style: TextStyle(color: t.colorScheme.error)),
      );

  Widget _buildSellerDrop(ThemeData t) => FutureBuilder(
        future: SupabaseService.client
            .from('profiles')
            .select('user_id, first_name, last_name')
            .inFilter('role', ['distributor', 'manager']),
        builder: (ctx, snap) {
          final list = snap.data ?? [];
          return _FilterDrop<String>(
            hint: 'كل البائعين',
            items: list.map((s) => s['user_id'].toString()).toList(),
            value: _soldByFilter,
            display: (v) {
              final seller = list.firstWhere((s) => s['user_id'] == v,
                  orElse: () => {'first_name': 'الكل', 'last_name': ''});
              return '${seller['first_name']} ${seller['last_name']}';
            },
            onChanged: (v) => setState(() => _soldByFilter = v),
            theme: t,
            icon: Icons.person_outline,
          );
        },
      );

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      locale: const Locale('ar'), // 👈 Force Arabic
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate!, end: _endDate!),
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  Widget _buildSales(ThemeData t) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchSales(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return SliverFillRemaining(
                child: Center(child: Text('خطأ: ${snap.error}')));
          }

          final eventsByDay = <String, List<_DayEvent>>{};
          for (final sale in snap.data!) {
            final saleDate = DateTime.parse(sale['created_at']).toLocal();
            final saleKey = DateFormat('yyyy-MM-dd').format(saleDate);
            eventsByDay
                .putIfAbsent(saleKey, () => [])
                .add(_DayEvent(sale, saleDate, false));
            if (sale['payment_date'] != null) {
              final paymentDate =
                  DateTime.parse(sale['payment_date']).toLocal();
              if (!_isSameDay(saleDate, paymentDate)) {
                final paymentKey = DateFormat('yyyy-MM-dd').format(paymentDate);
                eventsByDay
                    .putIfAbsent(paymentKey, () => [])
                    .add(_DayEvent(sale, paymentDate, true));
              }
            }
          }

          final days = eventsByDay.keys.toList()
            ..sort((b, a) => a.compareTo(b));

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final dayEvents = eventsByDay[days[i]]!
                  ..sort((a, b) => b.time.compareTo(a.time));
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                    iconColor: t.colorScheme.primary,
                    title: Text(DateFormat('dd MMM yyyy', 'ar').format(DateTime.parse(days[i]))),
                    children:
                        dayEvents.map((e) => _buildEventTile(e, t)).toList(),
                  ),
                );
              },
              childCount: days.length,
            ),
          );
        },
      );

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildEventTile(_DayEvent event, ThemeData t) {
    if (event.isPayment) {
      return ListTile(
        leading: const Icon(Icons.attach_money, color: Colors.green),
        title: Text(
            'دفعة لعملية بيع بتاريخ ${DateFormat('MMM dd').format(DateTime.parse(event.sale['created_at']).toLocal())}'),
        subtitle: Text(
            '${event.sale['customer']['name']} • ${_lbp.format(event.sale['total_amount'])}'),
        trailing: Text(DateFormat('HH:mm').format(event.time)),
      );
    }

    final status =
        (event.sale['payment_status'] as String? ?? 'unpaid').toLowerCase();
    final color = status == 'paid'
        ? Colors.green
        : status == 'deposit'
            ? Colors.blue
            : Colors.orange;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(
          status == 'paid'
              ? Icons.check
              : status == 'deposit'
                  ? Icons.account_balance_wallet
                  : Icons.hourglass_empty,
          color: Colors.white,
        ),
      ),
      title: Text(event.sale['customer']['name'],
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${event.sale['product']['name']} • الكمية: ${event.sale['quantity']}'),
          Text(
              'تم البيع بواسطة: ${event.sale['seller']['first_name']} ${event.sale['seller']['last_name']}'),
        ],
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_lbp.format(event.sale['total_amount'])),
          Text(DateFormat('HH:mm').format(event.time)),
        ],
      ),
      onTap: () => _showDetails(event.sale, t),
    );
  }

  void _showDetails(Map<String, dynamic> sale, ThemeData t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفاصيل البيع'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('العميل: ${sale['customer']['name']}',
                  style: t.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('المنتج: ${sale['product']['name']}'),
              Text('الكمية: ${sale['quantity']}'),
              Text('الإجمالي: ${_lbp.format(sale['total_amount'])}'),
              Text(
                  'الحالة: ${(sale['payment_status'] as String).toUpperCase()}'),
              if (sale['payment_date'] != null)
                Text(
                    'تم الدفع في: ${DateFormat('MMM dd, HH:mm').format(DateTime.parse(sale['payment_date']).toLocal())}'),
              const SizedBox(height: 16),
              Text('الموقع: ${sale['location']['name']}'),
              Text(
                  'تم البيع بواسطة: ${sale['seller']['first_name']} ${sale['seller']['last_name']}'),
              if (sale['customer']['phone']?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('اتصل بالعميل'),
                    onPressed: () => launchUrl(
                        Uri(scheme: 'tel', path: sale['customer']['phone'])),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}

class _FilterDrop<T> extends StatelessWidget {
  const _FilterDrop({
    required this.theme,
    required this.icon,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.display,
  });

  final ThemeData theme;
  final IconData icon;
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T?)? display;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint),
          items: [
            DropdownMenuItem(value: null, child: Text(hint)),
            ...items.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(display?.call(e) ?? e.toString()),
                ))
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
