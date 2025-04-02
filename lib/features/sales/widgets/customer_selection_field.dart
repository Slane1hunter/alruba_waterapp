import 'package:flutter/material.dart';

class CustomerSelectionField extends StatefulWidget {
  final List<Map<String, String>> customers;
  final ValueChanged<String?> onCustomerChanged;

  const CustomerSelectionField({
    Key? key,
    required this.customers,
    required this.onCustomerChanged,
  }) : super(key: key);

  @override
  State<CustomerSelectionField> createState() => _CustomerSelectionFieldState();
}

class _CustomerSelectionFieldState extends State<CustomerSelectionField> {
  final _searchController = TextEditingController();
  List<Map<String, String>> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
    _searchController.addListener(_filterList);
  }

  void _filterList() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = widget.customers;
      } else {
        _filteredCustomers = widget.customers.where((c) {
          final name = c['name']!.toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search box
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Search Customer',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // Dropdown for filtered customers
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Select Existing Customer',
            border: OutlineInputBorder(),
          ),
          items: _filteredCustomers.map((customer) {
            return DropdownMenuItem(
              value: customer['id'],
              child: Text(customer['name']!),
            );
          }).toList(),
          onChanged: widget.onCustomerChanged,
        ),
      ],
    );
  }
}
