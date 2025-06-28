import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PricingSection extends StatelessWidget {
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final double totalPrice;

  PricingSection({
    super.key,
    required this.priceController,
    required this.quantityController,
    required this.totalPrice,
  });

  /// LBP formatter (no decimals)
  final _lbpFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'LBP ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.price_change_outlined, size: 20),
            SizedBox(width: 8),
            Text(
              'Pricing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: priceController,
          decoration: const InputDecoration(
            labelText: 'Price Per Gallon',
            hintText: 'e.g., 2500',
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
          onTap: () {
            if (quantityController.text == '0') {
              quantityController.clear();
            }
          },
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
          'Total Price: ${_lbpFormat.format(totalPrice)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
