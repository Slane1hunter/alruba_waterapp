import 'package:flutter/material.dart';

class PricingSection extends StatelessWidget {
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final double totalPrice;

  const PricingSection({
    super.key,
    required this.priceController,
    required this.quantityController,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pricing',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: priceController,
          decoration: const InputDecoration(
            labelText: 'Price Per Gallon',
            hintText: 'e.g., 2.50',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (val) {
            if (val == null || val.isEmpty) {
              return 'Please enter the price per gallon';
            }
            if (double.tryParse(val) == null) {
              return 'Enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: quantityController,
          decoration: const InputDecoration(
            labelText: 'Quantity (gallons)',
            hintText: 'Enter quantity',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: (val) {
            if (val == null || val.isEmpty) {
              return 'Please enter a quantity';
            }
            if (int.tryParse(val) == null || int.parse(val) <= 0) {
              return 'Enter a valid quantity';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Total Price: \$${totalPrice.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
