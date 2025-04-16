import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Adjust these imports to match your actual file paths:
import 'package:alruba_waterapp/features/presentation/owner/locations/add_location_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/locations/edit_location_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/products/add_product_page.dart';
import 'package:alruba_waterapp/features/presentation/owner/products/edit_product_page.dart';

import 'package:alruba_waterapp/providers/products_provider.dart';
import 'package:alruba_waterapp/providers/location_provider.dart';

import 'package:alruba_waterapp/models/product.dart';
import 'package:alruba_waterapp/models/location.dart';

/// Single page that manages both Products and Locations using tabs + improved UI.
class OwnerManagementPage extends ConsumerStatefulWidget {
  const OwnerManagementPage({super.key});

  @override
  ConsumerState<OwnerManagementPage> createState() => _OwnerManagementPageState();
}

class _OwnerManagementPageState extends ConsumerState<OwnerManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0; // 0 => Products, 1 => Locations

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentTabIndex = _tabController.index);
    });
  }

  /// Single FAB that depends on the active tab:
  /// - Tab 0 => "Add Product"
  /// - Tab 1 => "Add Location"
  void _handleFabPressed() {
    if (_currentTabIndex == 0) {
      // Show Add Product bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const AddProductPage(),
      );
    } else {
      // Show Add Location bottom sheet
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
      // AppBar with tabbed navigation for Products & Locations
      appBar: AppBar(
        title: const Text('Owner Management'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.onPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Products'),
            Tab(icon: Icon(Icons.map), text: 'Locations'),
          ],
        ),
      ),

      // TabBarView: first tab => products, second => locations
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ProductsTab(),
          _LocationsTab(),
        ],
      ),

      // A single FAB that changes label based on tab
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleFabPressed,
        label: Text(_currentTabIndex == 0 ? 'Add Product' : 'Add Location'),
        icon: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
// PRODUCTS TAB
////////////////////////////////////////////////////////////////////////////////

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  Future<void> _refreshProducts(WidgetRef ref) async {
    // Pull-to-Refresh: Force reload from DB
    ref.invalidate(productsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    // Add a RefreshIndicator so user can pull down to refresh
    return RefreshIndicator(
      onRefresh: () => _refreshProducts(ref),
      child: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No products found.')),
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
            Center(child: Text('Error: $error')),
          ],
        ),
      ),
    );
  }
}

/// Card for each product with an Edit button
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
        Text('Home Price: \$${p.homePrice.toStringAsFixed(2)}'),
        Text('Market Price: \$${p.marketPrice.toStringAsFixed(2)}'),
        Text('Production Cost: \$${p.productionCost.toStringAsFixed(2)}'),
      ],
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
// LOCATIONS TAB
////////////////////////////////////////////////////////////////////////////////

class _LocationsTab extends ConsumerWidget {
  const _LocationsTab();

  Future<void> _refreshLocations(WidgetRef ref) async {
    // Force re-fetch from DB on pull to refresh
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
                Center(child: Text('No locations found.')),
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
            Center(child: Text('Error: $error')),
          ],
        ),
      ),
    );
  }
}

/// Card for each location with an Edit button
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
