import 'package:flutter/material.dart';

class ProductDropdown extends StatelessWidget {
  final String? selectedProduct;
  final ValueChanged<String?> onProductChanged;
  final List<Map<String, String>> products;

  const ProductDropdown({
    super.key,
    required this.selectedProduct,
    required this.onProductChanged,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Select Product',
        border: OutlineInputBorder(),
      ),
      value: selectedProduct,
      items: products.map((p) {
        return DropdownMenuItem<String>(
          value: p['id'],
          child: Text(p['name']!),
        );
      }).toList(),
      onChanged: onProductChanged,
      validator: (val) {
        if (val == null) {
          return 'Please select a product';
        }
        return null;
      },
    );
  }
}
