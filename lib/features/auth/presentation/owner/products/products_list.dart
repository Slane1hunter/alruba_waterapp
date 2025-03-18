import 'package:alruba_waterapp/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  Future<List<dynamic>> fetchProducts() async {
    // Query products from Supabase.
    final data = await SupabaseService.client.from('products').select('*');
    // data should be a List<dynamic>
    return data as List<dynamic>;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<dynamic>>(
      future: fetchProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          debugPrint('Error fetching products: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          final products = snapshot.data!;
          return Scaffold(
            body: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ListTile(
                  title: Text(product['name'].toString()),
                  subtitle: Text(
                    'Home Price: \$${product['home_price'].toString()}   Market Price: \$${product['market_price'].toString()}',
                  ),
                );
              },
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                // Navigate to add/edit product page (to be implemented)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add Product pressed')),
                );
              },
              child: const Icon(Icons.add),
            ),
          );
        }
        return const Center(child: Text('No products found'));
      },
    );
  }
}
