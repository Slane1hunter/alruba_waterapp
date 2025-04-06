import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

class ProductRepository {
  // Fetch all products
  Future<List<Product>> fetchProducts() async {
    // CHANGED: select('id, name, home_price, market_price, production_cost, is_refillable')
    final response = await SupabaseService.client
        .from('products')
        .select('id, name, home_price, market_price, production_cost, is_refillable'); 

    // parse JSON into Product objects
    return response.map<Product>((item) => Product.fromMap(item)).toList();
  }

  // Add a new product - returns the newly created row
  Future<Product> addProduct({
    required String name,
    required double homePrice,
    required double marketPrice,
    required double productionCost,
    bool isRefillable = false, // NEW if you want to set it on creation
  }) async {
    // Force PostgREST to return the inserted row by calling .select()
    final inserted = await SupabaseService.client
        .from('products')
        .insert({
          'name': name,
          'home_price': homePrice,
          'market_price': marketPrice,
          'production_cost': productionCost,
          'is_refillable': isRefillable, // CHANGED
        })
        .select()
        .single();
    return Product.fromMap(inserted);
  }

  // Update an existing product - returns the updated row
  Future<Product> updateProduct({
    required String productId,
    required String name,
    required double homePrice,
    required double marketPrice,
    required double productionCost,
    bool isRefillable = false, // NEW
  }) async {
    final updated = await SupabaseService.client
        .from('products')
        .update({
          'name': name,
          'home_price': homePrice,
          'market_price': marketPrice,
          'production_cost': productionCost,
          'is_refillable': isRefillable, // CHANGED
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
