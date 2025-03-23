import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alruba_waterapp/models/product.dart';
import 'package:alruba_waterapp/providers/products_provider.dart';
import 'edit_product_page.dart'; // We'll create this
import 'add_product_page.dart';  // We'll create this

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
          // Show a bottom sheet or navigate to a dedicated "Add Product" page
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
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(product.name, style: const TextStyle(fontSize: 18)),
        subtitle: Text(
          'Home Price: \$${product.homePrice.toStringAsFixed(2)}\n'
          'Market Price: \$${product.marketPrice.toStringAsFixed(2)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            // Show a bottom sheet or go to an edit screen
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
