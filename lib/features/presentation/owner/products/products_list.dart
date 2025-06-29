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
            return const Center(child: Text('لا توجد منتجات.'));
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
            Center(child: Text('خطأ: ${error.toString()}')),
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
    // مساعدة لتنسيق السعر مثل "LBP 1,200.00"
    String format(double value) => 'ل.ل ${value.toStringAsFixed(2)}';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(product.name, style: const TextStyle(fontSize: 18)),
        subtitle: Text(
          'سعر التوصيل للمنزل: ${format(product.homePrice)}\n'
          'سعر السوق: ${format(product.marketPrice)}\n'
          'تكلفة الإنتاج: ${format(product.productionCost)}\n'
          'قابل لإعادة التعبئة: ${product.isRefillable ? "نعم" : "لا"}',
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
