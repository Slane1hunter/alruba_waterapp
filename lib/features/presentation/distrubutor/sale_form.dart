import 'package:alruba_waterapp/features/presentation/distrubutor/sales/widgets/customer_location_field.dart';
import 'package:alruba_waterapp/features/presentation/distrubutor/sales/widgets/payment_section.dart';
import 'package:alruba_waterapp/features/presentation/distrubutor/sales/widgets/pricing_section.dart';
import 'package:alruba_waterapp/features/presentation/distrubutor/sales/widgets/product_dropdown.dart';
import 'package:alruba_waterapp/features/presentation/distrubutor/sales/widgets/sale_form_submit_button.dart';
import 'package:alruba_waterapp/models/customer.dart';
import 'package:alruba_waterapp/models/offline_gallon_transaction.dart';
import 'package:alruba_waterapp/models/offline_sale.dart';
import 'package:alruba_waterapp/models/product.dart';
import 'package:alruba_waterapp/providers/customers_provider.dart';
import 'package:alruba_waterapp/providers/location_provider.dart';
import 'package:alruba_waterapp/providers/products_provider.dart';
import 'package:alruba_waterapp/services/offline_gallon_queue.dart';
import 'package:alruba_waterapp/services/offline_sales_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';


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
  String? _newCustomerName;
  String? _newCustomerPhone;
  String? _newCustomerType; // 'distributor' or 'regular'
  String? _newCustomerLocation; // location ID from dropdown
  String? _preciseLocation; // from ExactLocationWidget

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
  List<String> _paymentOptions = ['Paid', 'Unpaid'];
  // NOTE: _notesController removed as it's not used in the database

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
    super.dispose();
  }

  /// Recompute total price based on price and quantity inputs.
  void _updateTotalPrice() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final qty = int.tryParse(_quantityController.text) ?? 0;
    setState(() {
      _totalPrice = price * qty;
    });
  }

  /// Auto-fill price based on selected product and customer type.
  /// Also updates payment options if product is refillable.
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

    // Add "Deposit" option if product is refillable.
    if (_selectedProduct!.isRefillable) {
      _paymentOptions = ['Paid', 'Unpaid', 'Deposit'];
    } else {
      _paymentOptions = ['Paid', 'Unpaid'];
    }
    if (!_paymentOptions.contains(_paymentStatus)) {
      setState(() {
        _paymentStatus = _paymentOptions.first;
      });
    }
  }

  String _defaultLocationId() {
    // Replace with an actual valid location id if needed.
    return '17c1cb39-7b97-494b-be85-bae7290cd54c';
  }

  /// Save sale offline with product and customer details.
  Future<void> _submitFormOffline() async {
    if (!_formKey.currentState!.validate()) return;

    // Ensure that if not creating a new customer, one is selected.
    if (!_isNewCustomer && (_existingCustomerId == null || _existingCustomerId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an existing customer.')),
      );
      return;
    }

    _formKey.currentState!.save();

    String? customerId;
    // For new customers, store them offline.
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
      customerId = null;
    } else {
      customerId = _existingCustomerId;
    }

    final phoneToStore = _isNewCustomer ? _newCustomerPhone : _existingCustomerPhone;
    final saleCustomerName = _isNewCustomer ? _newCustomerName : _existingCustomerName;
    final qty = int.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final String saleId = const Uuid().v4(); // <- requires uuid package


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
      paymentStatus: _paymentStatus, // 'Paid', 'Unpaid', or 'Deposit'
      createdAt: DateTime.now(),
      soldBy: Supabase.instance.client.auth.currentUser?.id ?? 'unknown',
      locationId: _newCustomerLocation ?? _defaultLocationId(),
      preciseLocation: _preciseLocation,
      id: saleId,
    );

    debugPrint("[MakeSalePage] OfflineSale: $offlineSale");
    await OfflineSalesQueue.addSale(offlineSale);

    // If product is refillable, also record container movement.
    // In sale_form.dart, inside _submitFormOffline()

if (_selectedProduct != null && _selectedProduct!.isRefillable) {
  final containerTx = OfflineGallonTransaction(
    customerId: customerId ?? 'unknown',
    productId: _selectedProduct!.id,
    quantity: qty,
    transactionType: _paymentStatus.toLowerCase() == 'deposit' ? 'deposit' : 'purchase',
    status: _paymentStatus.toLowerCase(),
    amount: _totalPrice,
    createdAt: DateTime.now(),
      saleId: saleId, // 🔹 Attach it here
  );
  await OfflineGallonQueue.addTransaction(containerTx);
}


    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale queued for sync!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customersAsync = ref.watch(customersProvider);
    ref.watch(productsProvider);
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Switch between New/Existing Customer
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Info',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                      // Existing Customer Section (Required Selection)
                      if (!_isNewCustomer)
                        customersAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
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
                                  label: Text(_existingCustomerName ?? 'Select Existing Customer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[500],
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: Colors.grey),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: () async {
                                    final chosen = await showModalBottomSheet<Map<String, String>>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => _CustomerSearchSheet(customers: mapped),
                                    );
                                    if (chosen != null) {
                                      setState(() {
                                        _existingCustomerId = chosen['id'];
                                        _existingCustomerName = chosen['name'];
                                        _existingCustomerPhone = chosen['phone'];
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                if (_existingCustomerId != null)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_pin),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$_existingCustomerName',
                                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
                      // New Customer Section
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
                          validator: (val) => val == null || val.isEmpty ? 'Enter phone' : null,
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
                          validator: (val) => val == null ? 'Please select a type' : null,
                        ),
                        const SizedBox(height: 16),
                        locationsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
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
                              onLocationChanged: (val) => setState(() => _newCustomerLocation = val),
                              locations: List<Map<String, String>>.from(mappedLocs),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ref.watch(productsProvider).when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, st) => Text('Product Error: $err'),
                        data: (prodList) {
                          final typed = prodList;
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PaymentSection(
                        paymentStatus: _paymentStatus,
                        onPaymentStatusChanged: (val) => setState(() => _paymentStatus = val ?? 'Paid'),
                        paymentOptions: _paymentOptions,
                      ),
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
// Bottom Sheet for Customer Search
// ---------------------------------------------------------------
class _CustomerSearchSheet extends StatefulWidget {
  final List<Map<String, String>> customers;
  const _CustomerSearchSheet({required this.customers});

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
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
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
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
