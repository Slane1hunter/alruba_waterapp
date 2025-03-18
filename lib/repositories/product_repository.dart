import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

class ProductRepository {
  Future<List<Product>> fetchProducts() async {
    // Await the select() call; it returns a List
    final response = await SupabaseService.client.from('products').select();
    final List<dynamic> data = response as List<dynamic>;
    return data.map((e) => Product.fromMap(e)).toList();
  }
}
