import 'package:alruba_waterapp/models/customer.dart';
import 'package:alruba_waterapp/models/offline_gallon_transaction.dart';
import 'package:alruba_waterapp/services/offline_gallon_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../models/offline_sale.dart';
import '../../../../../services/offline_sales_queue.dart';

// Providers
import 'package:alruba_waterapp/providers/customers_provider.dart';
import 'package:alruba_waterapp/providers/products_provider.dart';
import 'package:alruba_waterapp/providers/location_provider.dart';

// Custom widgets
import 'widgets/customer_location_field.dart';
import 'widgets/product_dropdown.dart';
import 'widgets/pricing_section.dart';
import 'widgets/payment_section.dart';
import 'widgets/sale_form_submit_button.dart';

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
  String? _newCustomerName; // If new, name typed
  String? _newCustomerPhone;
  String? _newCustomerType; // 'distributor' or 'regular'
  String? _newCustomerLocation; // location ID from dropdown
  String? _preciseLocation; // used for storing location from ExactLocationWidget

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
      if (_newCustomerType == 'distributor') {
        isDistributor = true;
      }
    } else {
      // For existing customers, assume 'regular'
      isDistributor = false;
    }

    final price = isDistributor
        ? _selectedProduct!.marketPrice
        : _selectedProduct!.homePrice;

    _priceController.text = price.toStringAsFixed(2);
    _updateTotalPrice();
  }

  String _defaultLocationId() {
    // Replace with an actual valid location id if needed
    return '17c1cb39-7b97-494b-be85-bae7290cd54c';
  }

  /// Save sale offline with product/customer details
  Future<void> _submitFormOffline() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    String? customerId;
    // For new customers, store them offline
    if (_isNewCustomer) {
      final newLocalCustomer = Customer(
        name: _newCustomerName ?? "Unknown Customer",
        phone: _newCustomerPhone ?? "",
        type: _newCustomerType ?? "regular",
        locationId: _newCustomerLocation ?? _defaultLocationId(),
        preciseLocation: _preciseLocation,
      );

      final customerBox = await Hive.openBox<Customer>('offline_customers');
      await customerBox.add(newLocalCustomer);

      // Sync logic will create them in Supabase
      customerId = null;
    } else {
      // For existing
      customerId = _existingCustomerId;
    }

    final phoneToStore =
        _isNewCustomer ? _newCustomerPhone : _existingCustomerPhone;
    final saleCustomerName =
        _isNewCustomer ? _newCustomerName : _existingCustomerName;
    final qty = int.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    final offlineSale = OfflineSale(
      isNewCustomer: _isNewCustomer,
      newCustomerPhone: _isNewCustomer ? _newCustomerPhone : null,
      existingCustomerId: customerId,
      customerName: saleCustomerName,
      customerPhone: phoneToStore,
      productId: _selectedProduct?.id,
      productName: _selectedProduct?.name,
      pricePerUnit: price,
      quantity: qty,
      totalPrice: _totalPrice,
      paymentStatus: _paymentStatus,
      notes: _paymentStatus == 'Unpaid' && _notesController.text.isNotEmpty
          ? _notesController.text
          : null,
      createdAt: DateTime.now(),
      soldBy: Supabase.instance.client.auth.currentUser?.id ?? 'unknown',
      locationId: _newCustomerLocation ?? _defaultLocationId(),
      preciseLocation: _preciseLocation,
    );

    debugPrint("[MakeSalePage] OfflineSale: $offlineSale");
    await OfflineSalesQueue.addSale(offlineSale);

    final queuedSales = await OfflineSalesQueue.getAllSales();
    debugPrint(
        "[MakeSalePage] Total unsynced sales in queue: ${queuedSales.length}");
// 2) If product is refillable, also record container movement
  if (_selectedProduct != null && _selectedProduct!.isRefillable) {
    final containerTx = OfflineGallonTransaction(
      customerId: customerId ?? 'unknown',
      productId: _selectedProduct!.id,
      quantity: qty, // if it's a deposit or purchase, +qty. A return would be -qty
      transactionType: 'purchase', // or 'deposit', etc
      status: _paymentStatus,       // 'paid', 'unpaid'
      createdAt: DateTime.now(),
    );
    await OfflineGallonQueue.addTransaction(containerTx);
  }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale queued for sync!')),
    );
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              // --------------------------------
              // Customer Card
              // --------------------------------
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
                      // Switch between new/existing
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
                                _preciseLocation = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // If NOT new customer, show a styled button
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
                                'phone': c['phone'].toString(),
                              };
                            }).toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.people_alt),
                                  label: Text(_existingCustomerName ??
                                      'Select Existing Customer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[500],
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: Colors.grey),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: () async {
                                    final chosen = await showModalBottomSheet<
                                        Map<String, String>>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => _CustomerSearchSheet(
                                          customers: mapped),
                                    );
                                    if (chosen != null) {
                                      setState(() {
                                        _existingCustomerId = chosen['id'];
                                        _existingCustomerName = chosen['name'];
                                        _existingCustomerPhone =
                                            chosen['phone'];
                                      });
                                    }
                                  },
                                ),

                                const SizedBox(height: 8),

                                if (_existingCustomerId != null)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_pin),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$_existingCustomerName',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '($_existingCustomerPhone)',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),

                      // If NEW customer
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
                            final mappedLocs = locList.map((loc) {
                              return {
                                'id': loc.id,
                                'name': loc.name.toString(),
                              };
                            }).toList();

                            return CustomerLocationDropdown(
                              selectedLocation: _newCustomerLocation,
                              onLocationChanged: (val) =>
                                  setState(() => _newCustomerLocation = val),
                              locations: List<Map<String, String>>.from(
                                mappedLocs,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        ExactLocationWidget(
                          onLocationSelected: (val) {
                            setState(() {
                              _preciseLocation = val;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // --------------------------------
              // Product & Pricing Card
              // --------------------------------
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

              // --------------------------------
              // Payment Card
              // --------------------------------
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

              // --------------------------------
              // Submit Button
              // --------------------------------
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

// ---------------------------------------------------------------
// This is a stylish bottom sheet with DraggableScrollableSheet
// ---------------------------------------------------------------
class _CustomerSearchSheet extends StatefulWidget {
  final List<Map<String, String>> customers;
  const _CustomerSearchSheet({Key? key, required this.customers})
      : super(key: key);

  @override
  State<_CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends State<_CustomerSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<Map<String, String>> _filteredCustomers;

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
    _searchCtrl.addListener(_filterList);
  }

  void _filterList() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredCustomers = query.isEmpty
          ? widget.customers
          : widget.customers.where((c) {
              final name = c['name']!.toLowerCase();
              return name.contains(query);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.5, // half screen
      minChildSize: 0.3, // can’t go smaller than 30%
      maxChildSize: 0.9, // can drag up to 90% of screen
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select a Customer',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search Customer',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (ctx, i) {
                    final cust = _filteredCustomers[i];
                    return ListTile(
                      title: Text(cust['name']!),
                      subtitle: Text(cust['phone'] ?? ''),
                      onTap: () {
                        Navigator.pop(context, cust);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
