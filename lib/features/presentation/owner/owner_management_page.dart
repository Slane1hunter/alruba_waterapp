// lib/features/presentation/owner/owner_management_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// عدّل هذه الاستيرادات حسب مسارات ملفاتك الفعلية:
import 'package:alruba_waterapp/features/presentation/owner/locations/add_location_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/locations/edit_location_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/products/add_product_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/products/edit_product_page.dart';

import 'package:alruba_waterapp/providers/products_provider.dart';
import 'package:alruba_waterapp/providers/location_provider.dart';

import 'package:alruba_waterapp/models/product.dart';
import 'package:alruba_waterapp/models/location.dart';

/// منسق العملة المشترك
final _currencyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'LBP ',
  decimalDigits: 2,
);

/// صفحة واحدة لإدارة المنتجات والمواقع باستخدام تبويبات + واجهة محسّنة.
class OwnerManagementPage extends ConsumerStatefulWidget {
  const OwnerManagementPage({super.key});

  @override
  ConsumerState<OwnerManagementPage> createState() => _OwnerManagementPageState();
}

class _OwnerManagementPageState extends ConsumerState<OwnerManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0; // 0 => المنتجات, 1 => المواقع

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentTabIndex = _tabController.index);
    });
  }

  /// زر FAB واحد يتغير حسب التبويب النشط
  void _handleFabPressed() {
    if (_currentTabIndex == 0) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const AddProductPage(),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const AddLocationPage(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المالك'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.onPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'المنتجات'),
            Tab(icon: Icon(Icons.map), text: 'المواقع'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ProductsTab(),
          _LocationsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleFabPressed,
        label: Text(_currentTabIndex == 0 ? 'إضافة منتج' : 'إضافة موقع'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
// تبويب المنتجات
////////////////////////////////////////////////////////////////////////////////

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  Future<void> _refreshProducts(WidgetRef ref) async {
    ref.invalidate(productsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return RefreshIndicator(
      onRefresh: () => _refreshProducts(ref),
      child: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('لا توجد منتجات.')),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _ProductCard(product: product);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(child: Text('خطأ: $error')),
          ],
        ),
      ),
    );
  }
}

/// بطاقة لكل منتج مع زر تعديل، والأسعار بتنسيق "LBP 1,200.00"
class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          product.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: _buildProductSubtitle(product),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => EditProductPage(product: product),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductSubtitle(Product p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('سعر المنزل: ${_currencyFormat.format(p.homePrice)}'),
        Text('السعر في السوق: ${_currencyFormat.format(p.marketPrice)}'),
        Text('تكلفة الإنتاج: ${_currencyFormat.format(p.productionCost)}'),
      ],
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
// تبويب المواقع
////////////////////////////////////////////////////////////////////////////////

class _LocationsTab extends ConsumerWidget {
  const _LocationsTab();

  Future<void> _refreshLocations(WidgetRef ref) async {
    ref.invalidate(locationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsProvider);

    return RefreshIndicator(
      onRefresh: () => _refreshLocations(ref),
      child: locationsAsync.when(
        data: (locations) {
          if (locations.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('لا توجد مواقع.')),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final location = locations[index];
              return _LocationCard(location: location);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(child: Text('خطأ: $error')),
          ],
        ),
      ),
    );
  }
}

/// بطاقة لكل موقع مع زر تعديل
class _LocationCard extends StatelessWidget {
  final Location location;
  const _LocationCard({required this.location});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 3,
      child: ListTile(
        title: Text(location.name, style: const TextStyle(fontSize: 16)),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => EditLocationPage(location: location),
            );
          },
        ),
      ),
    );
  }
}
