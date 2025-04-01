import 'package:flutter/material.dart';

class CustomerSelectionField extends StatelessWidget {
  final bool isNewCustomer;
  final String? selectedCustomer;
  final ValueChanged<String?> onCustomerChanged;
  final List<Map<String, String>> customers; // Each with 'id' and 'name'

  const CustomerSelectionField({
    super.key,
    required this.isNewCustomer,
    required this.selectedCustomer,
    required this.onCustomerChanged,
    required this.customers,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Select Existing Customer',
        border: OutlineInputBorder(),
      ),
      value: selectedCustomer,
      items: customers.map((customer) {
        return DropdownMenuItem<String>(
          // Convert the id to a string
          value: customer['id'].toString(),
          child: Text(customer['name']!),
        );
      }).toList(),
      onChanged: onCustomerChanged,
      validator: (val) {
        if (!isNewCustomer && val == null) {
          return 'Please select a customer';
        }
        return null;
      },
    );
  }
}
