// lib/features/presentation/owner/product_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alruba_waterapp/models/product.dart';
import 'package:alruba_waterapp/providers/products_provider.dart';
import 'edit_product_page.dart';
import 'add_product_page.dart';

class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('No products found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(context, product);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error: ${error.toString()}')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AddProductPage(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    // Helper to format as "LBP 1,200.00"
    String format(double value) =>
        'LBP ${value.toStringAsFixed(2)}';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(product.name, style: const TextStyle(fontSize: 18)),
        subtitle: Text(
          'Home Price: ${format(product.homePrice)}\n'
          'Market Price: ${format(product.marketPrice)}\n'
          'Production Cost: ${format(product.productionCost)}\n'
          'Refillable: ${product.isRefillable ? "Yes" : "No"}',
        ),
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
}
