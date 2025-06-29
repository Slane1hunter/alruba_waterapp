import 'package:alruba_waterapp/models/product.dart';
import 'package:flutter/material.dart';

class ProductDropdown extends StatelessWidget {
  final Product? selectedProduct;
  final ValueChanged<Product?> onProductChanged;
  final List<Product> products;

  const ProductDropdown({
    super.key,
    required this.selectedProduct,
    required this.onProductChanged,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Product>(
      decoration: const InputDecoration(
        labelText: 'اختر المنتج',
        border: OutlineInputBorder(),
      ),
      value: selectedProduct,
      items: products.map((p) {
        // Show '(Refillable)' if p.isRefillable is true
        final displayName = p.isRefillable ? '${p.name} (قابل لإعادة التعبئة)' : p.name;

        return DropdownMenuItem<Product>(
          value: p,
          child: Text(displayName),
        );
      }).toList(),
      onChanged: onProductChanged,
      validator: (val) {
        if (val == null) {
          return 'يرجى اختيار المنتج';
        }
        return null;
      },
    );
  }
}
