import 'package:flutter/material.dart';
import 'widgets/customer_selection_field.dart';
import 'widgets/customer_location_field.dart';
import 'widgets/product_dropdown.dart';
import 'widgets/pricing_section.dart';
import 'widgets/payment_section.dart';
import 'widgets/sale_form_submit_button.dart';

class MakeSalePage extends StatefulWidget {
  const MakeSalePage({super.key});

  @override
  State<MakeSalePage> createState() => _MakeSalePageState();
}

class _MakeSalePageState extends State<MakeSalePage> {
  final _formKey = GlobalKey<FormState>();

  // Customer fields
  bool _isNewCustomer = false;
  String? _existingCustomerId;
  String? _newCustomerName;
  String? _newCustomerPhone;
  String? _newCustomerType;
  String? _newCustomerLocation; // Now selected using CustomerLocationField

  // Placeholder data for demonstration
  final List<Map<String, String>> _placeholderCustomers = [
    {'id': 'cust-1', 'name': 'Alice Smith'},
    {'id': 'cust-2', 'name': 'Bob Johnson'},
  ];
  final List<Map<String, String>> _placeholderLocations = [
    {'id': 'loc-1', 'name': 'Downtown'},
    {'id': 'loc-2', 'name': 'Uptown'},
    {'id': 'loc-3', 'name': 'Suburb'},
  ];
  final List<String> _placeholderTypes = ['normal', 'family', 'market'];

  // Product fields
  String? _selectedProductId;
  final List<Map<String, String>> _placeholderProducts = [
    {'id': 'prod-1', 'name': '5-Gallon Water Bottle'},
    {'id': 'prod-2', 'name': '10-Gallon Water Bottle'},
  ];

  // Pricing fields
  final TextEditingController _priceController =
      TextEditingController(text: '2.50');
  final TextEditingController _quantityController =
      TextEditingController(text: '0');
  double _totalPrice = 0.0;

  // Payment fields
  String _paymentStatus = 'Paid';
  final List<String> _paymentOptions = ['Paid', 'Unpaid'];
  final TextEditingController _notesController = TextEditingController();

  // Sale type (for example, 'new')
  final String _saleType = 'new';

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_updateTotalPrice);
    _quantityController.addListener(_updateTotalPrice);
  }

  void _updateTotalPrice() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    setState(() {
      _totalPrice = price * quantity;
    });
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // For demonstration, show a summary in a SnackBar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sale Added:\n'
          'Sale Type: ${_isNewCustomer ? "New Customer Sale" : "Existing Customer Sale"}\n'
          'Customer: ${_isNewCustomer ? _newCustomerName : _existingCustomerId}\n'
          'Product: $_selectedProductId\n'
          'Price per Gallon: \$${_priceController.text}\n'
          'Quantity: ${_quantityController.text}\n'
          'Total Price: \$${_totalPrice.toStringAsFixed(2)}\n'
          'Payment Status: $_paymentStatus\n'
          '${_paymentStatus == "Unpaid" ? "Notes: ${_notesController.text}" : ""}',
        ),
      ),
    );

    // TODO: Instead of immediate submission, add sale to an in-memory list for later batch submission.
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Make a Sale'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toggle between new and existing customer
              SwitchListTile(
                title: const Text('Is this a new customer?'),
                value: _isNewCustomer,
                onChanged: (val) {
                  setState(() {
                    _isNewCustomer = val;
                    _existingCustomerId = null;
                    _newCustomerName = null;
                    _newCustomerPhone = null;
                    _newCustomerType = null;
                    _newCustomerLocation = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              // If existing customer, show selection field
              if (!_isNewCustomer)
                CustomerSelectionField(
                  isNewCustomer: _isNewCustomer,
                  selectedCustomer: _existingCustomerId,
                  onCustomerChanged: (val) {
                    setState(() {
                      _existingCustomerId = val;
                    });
                  },
                  customers: _placeholderCustomers,
                ),
              // If new customer, show input fields
              if (_isNewCustomer) ...[
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    hintText: 'Enter full name',
                    border: OutlineInputBorder(),
                  ),
                  onSaved: (val) => _newCustomerName = val,
                  validator: (val) {
                    if (_isNewCustomer && (val == null || val.isEmpty)) {
                      return 'Please enter the customer name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. +1 555-1234',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  onSaved: (val) => _newCustomerPhone = val,
                  validator: (val) {
                    if (_isNewCustomer && (val == null || val.isEmpty)) {
                      return 'Please enter the phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Customer Type',
                    border: OutlineInputBorder(),
                  ),
                  value: _newCustomerType,
                  items: _placeholderTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _newCustomerType = val;
                    });
                  },
                  validator: (val) {
                    if (_isNewCustomer && val == null) {
                      return 'Please select a customer type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Use the CustomerLocationField widget to select the location.
                // In your MakeSalePage build method, inside the new customer section:
                CustomerLocationField(
                  selectedLocation: _newCustomerLocation,
                  onLocationChanged: (val) {
                    setState(() {
                      _newCustomerLocation = val;
                    });
                  },
                  locations:
                      _placeholderLocations, // Replace with your dynamic location data
                ),
              ],
              const SizedBox(height: 24),
              // Product selection widget
              ProductDropdown(
                selectedProduct: _selectedProductId,
                onProductChanged: (val) {
                  setState(() {
                    _selectedProductId = val;
                  });
                },
                products: _placeholderProducts,
              ),
              const SizedBox(height: 24),
              // Pricing section widget
              PricingSection(
                priceController: _priceController,
                quantityController: _quantityController,
                totalPrice: _totalPrice,
              ),
              const SizedBox(height: 24),
              // Payment section widget
              PaymentSection(
                paymentStatus: _paymentStatus,
                onPaymentStatusChanged: (val) {
                  setState(() {
                    _paymentStatus = val ?? 'Paid';
                  });
                },
                paymentOptions: _paymentOptions,
                notesController: _notesController,
              ),
              const SizedBox(height: 24),
              // Submit button widget
              SaleFormSubmitButton(
                onPressed: _submitForm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
