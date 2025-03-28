import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Offline logic
import 'package:hive_flutter/hive_flutter.dart' show Hive; // If you need Hive references
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/offline_sale.dart';
import '../../services/offline_sales_queue.dart';

// Providers
import 'package:alruba_waterapp/providers/customers_provider.dart';
import 'package:alruba_waterapp/providers/products_provider.dart';
import 'package:alruba_waterapp/providers/location_provider.dart';

// Your custom widgets
import 'widgets/customer_selection_field.dart';
import 'widgets/customer_location_field.dart';
import 'widgets/product_dropdown.dart';
import 'widgets/pricing_section.dart';
import 'widgets/payment_section.dart';
import 'widgets/sale_form_submit_button.dart';

// If your Product model has marketPrice and homePrice
import 'package:alruba_waterapp/models/product.dart';

class MakeSalePage extends ConsumerStatefulWidget {
  const MakeSalePage({super.key});

  @override
  ConsumerState<MakeSalePage> createState() => _MakeSalePageState();
}

class _MakeSalePageState extends ConsumerState<MakeSalePage> {
  final _formKey = GlobalKey<FormState>();

  // ----------------------------
  // Customer Fields
  // ----------------------------
  bool _isNewCustomer = false;
  String? _existingCustomerId;
  String? _existingCustomerName;
  String? _existingCustomerPhone;
  String? _newCustomerName;      // If new user, name typed
  String? _newCustomerPhone;
  String? _newCustomerType;      // 'distributor' or 'regular'
  String? _newCustomerLocation;  // location ID from dropdown

  final List<String> _placeholderTypes = ['distributor', 'regular'];

  // ----------------------------
  // Product & Pricing
  // ----------------------------
  Product? _selectedProduct;
  final TextEditingController _priceController =
      TextEditingController(text: '0.00');
  final TextEditingController _quantityController =
      TextEditingController(text: '0');
  double _totalPrice = 0.0;

  // ----------------------------
  // Payment
  // ----------------------------
  String _paymentStatus = 'Paid';
  final List<String> _paymentOptions = ['Paid', 'Unpaid'];
  final TextEditingController _notesController = TextEditingController();

  // ----------------------------
  // Lifecycle
  // ----------------------------
  @override
  void initState() {
    super.initState();
    _priceController.addListener(_updateTotalPrice);
    _quantityController.addListener(_updateTotalPrice);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ----------------------------
  // Logic
  // ----------------------------
  /// Recompute total price
  void _updateTotalPrice() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final qty = int.tryParse(_quantityController.text) ?? 0;
    setState(() {
      _totalPrice = price * qty;
    });
  }

  /// Auto-fill price based on user type & product
  void _autoFillPrice() {
  if (_selectedProduct == null) return;
  bool isDistributor = false;
  if (_isNewCustomer) {
    if (_newCustomerType == 'distributor' || _newCustomerType == 'market') {
      isDistributor = true;
    }
  } else {
    // For existing customers, if you have a type stored (you might add that in your mapping), use it:
    // For demonstration, assume 'regular' unless specified.
    isDistributor = false;
  }

  final price = isDistributor
      ? _selectedProduct!.marketPrice
      : _selectedProduct!.homePrice;

  _priceController.text = price.toStringAsFixed(2);
  _updateTotalPrice();
}
  String _defaultLocationId() {
    // Replace with an actual valid location id from your locations table.
    return '17c1cb39-7b97-494b-be85-bae7290cd54c';
  }

  /// Save sale offline with product/customer name
  Future<void> _submitFormOffline() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

  final phoneToStore = _isNewCustomer ? _newCustomerPhone : _existingCustomerPhone;
final saleCustomerName = _isNewCustomer ? _newCustomerName : _existingCustomerName;

    // 2) Build offline sale
    final offlineSale = OfflineSale(
  isNewCustomer: _isNewCustomer,
  newCustomerPhone: _isNewCustomer ? _newCustomerPhone : null,
  existingCustomerId: !_isNewCustomer ? _existingCustomerId : null,
  customerName: saleCustomerName,
  customerPhone: phoneToStore,
  productId: _selectedProduct?.id,
  productName: _selectedProduct?.name,
  pricePerUnit: double.tryParse(_priceController.text) ?? 0.0,
  quantity: int.tryParse(_quantityController.text) ?? 0,
  totalPrice: _totalPrice,
  paymentStatus: _paymentStatus,
  notes: _paymentStatus == 'Unpaid' && _notesController.text.isNotEmpty
      ? _notesController.text
      : null,
  createdAt: DateTime.now(),
   soldBy: Supabase.instance.client.auth.currentUser?.id ?? 'unknown', // Provide the current user's id or a default value.
  locationId: _newCustomerLocation ?? _defaultLocationId(), // Use the new customer location if set, otherwise a default location.
  
);

    // 3) Add to local queue
    await OfflineSalesQueue.addSale(offlineSale);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale stored offline in queue!')),
    );
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // watch the providers
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(productsProvider);
    final locationsAsync = ref.watch(locationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Make a Sale'),
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 1) Customer Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Switch new/existing
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Info',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(_isNewCustomer ? 'New' : 'Existing'),
                          Switch(
                            value: _isNewCustomer,
                            onChanged: (val) {
                              setState(() {
                                _isNewCustomer = val;
                                _existingCustomerId = null;
                                _existingCustomerName = null;
                                _newCustomerName = null;
                                _newCustomerPhone = null;
                                _newCustomerType = null;
                                _newCustomerLocation = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // If not new => existing selection
                      if (!_isNewCustomer)
                        customersAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (err, st) => Text('Error: $err'),
                          data: (customerList) {
                            final mapped = customerList.map((c) {
  return {
    'id': c['id'].toString(),
    'name': c['name'].toString(),
    'phone': c['phone'].toString(), // include phone
  };
}).toList();
return CustomerSelectionField(
  isNewCustomer: _isNewCustomer,
  selectedCustomer: _existingCustomerId,
  onCustomerChanged: (val) {
    setState(() {
      _existingCustomerId = val;
      // Find the selected customer's details:
      final found = mapped.firstWhere(
        (x) => x['id'] == val,
        orElse: () => {'name': 'Unknown', 'phone': 'N/A'},
      );
      _existingCustomerName = found['name'];
      _existingCustomerPhone = found['phone'];
    });
  },
  customers: mapped,
);
                          },
                        ),

                      // If new => name, phone, type
                      if (_isNewCustomer) ...[
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Full Name (Optional)',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          onSaved: (val) => _newCustomerName = val,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          onSaved: (val) => _newCustomerPhone = val,
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Enter phone' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Customer Type',
                            border: OutlineInputBorder(),
                          ),
                          value: _newCustomerType,
                          items: _placeholderTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _newCustomerType = val;
                              _autoFillPrice();
                            });
                          },
                          validator: (val) =>
                              val == null ? 'Please select a type' : null,
                        ),
                        const SizedBox(height: 16),
                        locationsAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (err, st) => Text('Error: $err'),
                          data: (locList) {
                            final mappedLocs = locList.map((loc) => {
                                  'id': loc.id.toString(),
                                  'name': loc.name.toString(),
                                }).toList();
                            return CustomerLocationDropdown(
                              selectedLocation: _newCustomerLocation,
                              onLocationChanged: (val) =>
                                  setState(() => _newCustomerLocation = val),
                              locations: mappedLocs,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const ExactLocationWidget(),
                      ],
                    ],
                  ),
                ),
              ),

              // 2) Product & Pricing
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Product & Pricing',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ref.watch(productsProvider).when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (err, st) => Text('Product Error: $err'),
                            data: (prodList) {
                              final typed = prodList as List<Product>;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ProductDropdown(
                                    selectedProduct: _selectedProduct,
                                    onProductChanged: (prod) {
                                      setState(() {
                                        _selectedProduct = prod;
                                        _autoFillPrice();
                                      });
                                    },
                                    products: typed,
                                  ),
                                  const SizedBox(height: 24),
                                  PricingSection(
                                    priceController: _priceController,
                                    quantityController: _quantityController,
                                    totalPrice: _totalPrice,
                                  ),
                                ],
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),

              // 3) Payment
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payment_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Payment Details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PaymentSection(
                        paymentStatus: _paymentStatus,
                        onPaymentStatusChanged: (val) =>
                            setState(() => _paymentStatus = val ?? 'Paid'),
                        paymentOptions: _paymentOptions,
                        notesController: _notesController,
                      ),
                      if (_paymentStatus == 'Unpaid') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Reason / Notes',
                            hintText: 'Why is payment pending?',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 4) Submit => offline
              SaleFormSubmitButton(
                onPressed: _submitFormOffline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
