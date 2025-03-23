import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

class ProductRepository {
  // Fetch all products
  Future<List<Product>> fetchProducts() async {
    final response = await SupabaseService.client
        .from('products')
        .select('*'); // returns List<dynamic>

    return response.map((item) => Product.fromMap(item)).toList();
      // If something unexpected happens
  }

  // Add a new product - returns the newly created row
  Future<Product> addProduct({
    required String name,
    required double homePrice,
    required double marketPrice,
    required double productionCost,
  }) async {
    // Force PostgREST to return the inserted row by calling .select()
    // and then .single() so we parse exactly one row
    final inserted = await SupabaseService.client
        .from('products')
        .insert({
          'name': name,
          'home_price': homePrice,
          'market_price': marketPrice,
          'production_cost': productionCost,
        })
        .select()
        .single();
    // inserted is a Map, parse to Product
    return Product.fromMap(inserted);
  }

  // Update an existing product - returns the updated row
  Future<Product> updateProduct({
    required String productId,
    required String name,
    required double homePrice,
    required double marketPrice,
    required double productionCost,
  }) async {
    final updated = await SupabaseService.client
        .from('products')
        .update({
          'name': name,
          'home_price': homePrice,
          'market_price': marketPrice,
          'production_cost': productionCost,
        })
        .eq('id', productId)
        .select()
        .maybeSingle();

    if (updated == null) {
      throw Exception('No data returned from product update');
    }
    return Product.fromMap(updated);
  }
}
