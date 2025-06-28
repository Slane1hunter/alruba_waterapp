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

  // ---------------------------- Customer Fields ----------------------------
  bool _isNewCustomer = false;
  String? _existingCustomerId;
  String? _existingCustomerName;
  String? _existingCustomerPhone;
  String? _existingCustomerLocation;

  String? _newCustomerName;
  String? _newCustomerPhone;
  String? _newCustomerType;
  String? _newCustomerLocation;
  String? _preciseLocation;
  

  final List<String> _placeholderTypes = ['distributor', 'regular'];

  // ---------------------------- Product & Pricing ----------------------------
  Product? _selectedProduct;
  final TextEditingController _priceController = TextEditingController(text: '0.00');
  final TextEditingController _quantityController = TextEditingController(text: '0');
  double _totalPrice = 0.0;

  // ---------------------------- Payment ----------------------------
  String _paymentStatus = 'Paid';
  List<String> _paymentOptions = ['Paid', 'Unpaid'];

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

  void _updateTotalPrice() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final qty = int.tryParse(_quantityController.text) ?? 0;
    setState(() {
      _totalPrice = price * qty;
    });
  }

  void _autoFillPrice() {
    if (_selectedProduct == null) return;
    final isDist = _isNewCustomer && _newCustomerType == 'distributor';
    final price = isDist ? _selectedProduct!.marketPrice : _selectedProduct!.homePrice;
    _priceController.text = price.toStringAsFixed(2);
    _updateTotalPrice();

    _paymentOptions = _selectedProduct!.isRefillable
        ? ['Paid', 'Unpaid', 'Deposit']
        : ['Paid', 'Unpaid'];
    if (!_paymentOptions.contains(_paymentStatus)) {
      setState(() => _paymentStatus = _paymentOptions.first);
    }
  }

  String _defaultLocationId() => '17c1cb39-7b97-494b-be85-bae7290cd54c';

  Future<void> _submitFormOffline() async {
    // 1) Block if new customer but precise location not ready
    if (_isNewCustomer && _preciseLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait until precise location has finished loading.')),
      );
      return;
    }

    // 2) Standard form validation
    if (!_formKey.currentState!.validate()) return;
    if (!_isNewCustomer &&
        (_existingCustomerId == null || _existingCustomerId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an existing customer.')),
      );
      return;
    }

    _formKey.currentState!.save();

    // 3) Determine locationId
    final locationId = _isNewCustomer
        ? (_newCustomerLocation ?? _defaultLocationId())
        : (_existingCustomerLocation ?? _defaultLocationId());

    // 4) Save new customer locally if needed
    String? customerId;
    if (_isNewCustomer) {
      final newLocalCustomer = Customer(
        name: _newCustomerName ?? 'Unknown Customer',
        phone: _newCustomerPhone ?? '',
        type: _newCustomerType ?? 'regular',
        locationId: locationId,
        preciseLocation: _preciseLocation,
      );
      final customerBox = await Hive.openBox<Customer>('offline_customers');
      await customerBox.add(newLocalCustomer);
      customerId = null;
    } else {
      customerId = _existingCustomerId;
    }

    // 5) Build and queue OfflineSale
    final saleId = const Uuid().v4();
    final offlineSale = OfflineSale(
      isNewCustomer: _isNewCustomer,
      newCustomerPhone: _isNewCustomer ? _newCustomerPhone : null,
      existingCustomerId: customerId,
      customerName: _isNewCustomer ? _newCustomerName : _existingCustomerName,
      customerPhone: _isNewCustomer ? _newCustomerPhone : _existingCustomerPhone,
      productId: _selectedProduct?.id,
      productName: _selectedProduct?.name,
      pricePerUnit: double.tryParse(_priceController.text) ?? 0.0,
      quantity: int.tryParse(_quantityController.text) ?? 0,
      totalPrice: _totalPrice,
      paymentStatus: _paymentStatus,
      createdAt: DateTime.now(),
      soldBy: Supabase.instance.client.auth.currentUser?.id ?? 'unknown',
      locationId: locationId,
      localSaleId: saleId,
    );

    await OfflineSalesQueue.addSale(offlineSale);

    // 6) Queue gallon transaction if refillable
    if (_selectedProduct?.isRefillable == true) {
      final tx = OfflineGallonTransaction(
  localTxId: const Uuid().v4(), // Generate new UUID
  saleLocalId: saleId, // Use the same saleId from OfflineSale
  customerId: customerId ?? 'unknown',
  productId: _selectedProduct!.id,
  quantity: int.tryParse(_quantityController.text) ?? 0,
  transactionType:
      _paymentStatus.toLowerCase() == 'deposit' ? 'deposit' : 'purchase',
  status: _paymentStatus.toLowerCase(),
  amount: _totalPrice,
  createdAt: DateTime.now(),
  saleId: saleId,
);
      await OfflineGallonQueue.addTransaction(tx);
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

    // ➤ Only enable submit if existing customer or precise location ready
    final canSubmit = !_isNewCustomer || (_preciseLocation != null);

    return Scaffold(
      appBar: AppBar(title: const Text('Make a Sale')),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Customer Info Card ─────────────────────────────────────────────
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // New vs Existing switch
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 20),
                          const SizedBox(width: 8),
                          Text('Customer Info', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(_isNewCustomer ? 'New' : 'Existing'),
                          Switch(
                            value: _isNewCustomer,
                            onChanged: (val) {
                              setState(() {
                                _isNewCustomer = val;
                                _existingCustomerId = null;
                                _existingCustomerName = null;
                                _existingCustomerPhone = null;
                                _existingCustomerLocation = null;
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

                      // Existing customer picker
                      if (!_isNewCustomer)
                        customersAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Text('Error: $err'),
                          data: (list) {
                            final mapped = list.map((c) => {
                                  'id': c['id'].toString(),
                                  'name': c['name'].toString(),
                                  'phone': c['phone'].toString(),
                                  'locationId': c['location_id'].toString(),
                                }).toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.people_alt),
                                  label: Text(_existingCustomerName ?? 'Select Existing Customer'),
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
                                        _existingCustomerLocation = chosen['locationId'];
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
                                      children: [
                                        const Icon(Icons.person_pin),
                                        const SizedBox(width: 8),
                                        Text(_existingCustomerName!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 8),
                                        Text('(${_existingCustomerPhone!})', style: theme.textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),

                      // New customer inputs
                      if (_isNewCustomer) ...[
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Full Name (Optional)',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          onSaved: (v) => _newCustomerName = v,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          onSaved: (v) => _newCustomerPhone = v,
                          validator: (v) => v == null || v.isEmpty ? 'Enter phone' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Customer Type',
                            border: OutlineInputBorder(),
                          ),
                          value: _newCustomerType,
                          items: _placeholderTypes
                              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _newCustomerType = v;
                              _autoFillPrice();
                            });
                          },
                          validator: (v) => v == null ? 'Please select a type' : null,
                        ),
                        const SizedBox(height: 16),
                        locationsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Text('Error: $err'),
                          data: (locList) => CustomerLocationDropdown(
                            selectedLocation: _newCustomerLocation,
                            onLocationChanged: (v) => setState(() => _newCustomerLocation = v),
                            locations: locList.map((loc) => {'id': loc.id, 'name': loc.name}).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ExactLocationWidget(
                          onLocationSelected: (val) => setState(() => _preciseLocation = val),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Product & Pricing Card ──────────────────────────────────────────
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.shopping_bag_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text('Product & Pricing', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 16),
                      ref.watch(productsProvider).when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text('Product Error: $err'),
                        data: (prodList) => Column(
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
                              products: prodList,
                            ),
                            const SizedBox(height: 24),
                            PricingSection(
                              priceController: _priceController,
                              quantityController: _quantityController,
                              totalPrice: _totalPrice,
                            ),
                          ],
                        ),  
                      ),  
                    ],  
                  ),  
                ),  
              ),  

              // ── Payment Card ─────────────────────────────────────────────────────  
              Card(  
                elevation: 3,  
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),  
                margin: const EdgeInsets.only(bottom: 16),  
                child: Padding(  
                  padding: const EdgeInsets.all(16),  
                  child: Column(  
                    crossAxisAlignment: CrossAxisAlignment.start,  
                    children: [  
                      Row(children: [  
                        const Icon(Icons.payment_outlined, size: 20),  
                        const SizedBox(width: 8),  
                        Text('Payment Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),  
                      ]),  
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

              // ── Submit Button ───────────────────────────────────────────────────  
              SaleFormSubmitButton(  
                onPressed: canSubmit  
                    ? _submitFormOffline  
                    : () {  
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(  
                          content: Text('Please wait for precise location to finish loading.'),  
                        ));  
                      },  
              ),  
            ],  
          ),  
        ),  
      ),  
    );  
  }  
}  

// ── Bottom sheet for selecting existing customer ─────────────────────────────  
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
    final q = _searchCtrl.text.trim().toLowerCase();  
    setState(() {  
      _filteredCustomers = q.isEmpty  
          ? widget.customers  
          : widget.customers.where((c) => c['name']!.toLowerCase().contains(q)).toList();  
    });  
  }  
  
  @override  
  Widget build(BuildContext context) {  
    final theme = Theme.of(context);  
    return DraggableScrollableSheet(  
      initialChildSize: 0.5,  
      minChildSize: 0.3,  
      maxChildSize: 0.9,  
      builder: (ctx, scrollController) {  
        return Container(  
          decoration: BoxDecoration(  
            color: theme.colorScheme.surface,  
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),  
          ),  
          child: Column(  
            children: [  
              const SizedBox(height: 12),  
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),  
              const SizedBox(height: 12),  
              Text('Select a Customer', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),  
              const SizedBox(height: 16),  
              Padding(  
                padding: const EdgeInsets.symmetric(horizontal: 16),  
                child: TextField(  
                  controller: _searchCtrl,  
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search Customer', border: OutlineInputBorder()),  
                ),  
              ),  
              const SizedBox(height: 8),  
              Expanded(  
                child: ListView.builder(  
                  controller: scrollController,  
                  itemCount: _filteredCustomers.length,  
                  itemBuilder: (context, i) {  
                    final cust = _filteredCustomers[i];  
                    return ListTile(  
                      title: Text(cust['name']!),  
                      subtitle: Text(cust['phone']!),  
                      onTap: () => Navigator.pop(context, cust),  
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
