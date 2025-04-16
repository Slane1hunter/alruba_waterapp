import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alruba_waterapp/services/supabase_service.dart';

class ManagerReassignCustomerPage extends ConsumerStatefulWidget {
  const ManagerReassignCustomerPage({super.key});

  @override
  ConsumerState<ManagerReassignCustomerPage> createState() =>
      _ManagerReassignCustomerPageState();
}

class _ManagerReassignCustomerPageState
    extends ConsumerState<ManagerReassignCustomerPage> {
  // Selected customer and distributor IDs.
  String? _selectedCustomerId;
  String? _selectedDistributorId;

  // Local lists for customers and distributors.
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _distributors = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  /// Fetches customer and distributor data from Supabase.
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Fetch customers from the 'customers' table.
      final customerResponse = await SupabaseService.client
          .from('customers')
          .select('id, name, phone, assigned_to')
          .order('name');
      _customers = List<Map<String, dynamic>>.from(customerResponse);
    
      // Fetch distributors from the 'profiles' table where role is 'distributor'.
      final distributorResponse = await SupabaseService.client
          .from('profiles')
          .select('user_id, first_name, last_name, role')
          .eq('role', 'distributor')
          .order('first_name');
      _distributors = List<Map<String, dynamic>>.from(distributorResponse)
          .map((d) {
        final firstName = d['first_name'] as String? ?? '';
        final lastName = d['last_name'] as String? ?? '';
        return {
          'id': d['user_id'] as String,
          'name': '$firstName $lastName'.trim(),
        };
      }).toList();
        } catch (e) {
      debugPrint('Error fetching data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }

  /// Updates the 'assigned_to' field for the selected customer.
  Future<void> _reassignCustomer() async {
    if (_selectedCustomerId == null || _selectedDistributorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select both a customer and a distributor')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await SupabaseService.client
          .from('customers')
          .update({'assigned_to': _selectedDistributorId})
          .eq('id', _selectedCustomerId!)
          .select();
      if ((response as List).isEmpty) {
        throw Exception("Update failed: No row updated.");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer reassigned successfully')),
      );
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reassigning customer: $e')),
      );
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reassign Customer'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Customer Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Customer',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedCustomerId,
                    items: _customers.map((customer) {
                      return DropdownMenuItem<String>(
                        value: customer['id'] as String,
                        child: Text(customer['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCustomerId = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a customer' : null,
                  ),
                  const SizedBox(height: 16),
                  // Distributor Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Assign to Distributor',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedDistributorId,
                    items: _distributors.map((distributor) {
                      return DropdownMenuItem<String>(
                        value: distributor['id'] as String,
                        child: Text(distributor['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDistributorId = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a distributor' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _reassignCustomer,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Reassign Customer'),
                  ),
                ],
              ),
            ),
    );
  }
}
