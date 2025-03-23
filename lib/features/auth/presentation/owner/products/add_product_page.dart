import 'package:alruba_waterapp/providers/products_provider.dart';
import 'package:alruba_waterapp/repositories/product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddProductPage extends ConsumerStatefulWidget {
  const AddProductPage({super.key});

  @override
  ConsumerState<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends ConsumerState<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _homePriceController = TextEditingController();
  final _marketPriceController = TextEditingController();
  final _productionCostController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleAddProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final homePrice = double.parse(_homePriceController.text.trim());
      final marketPrice = double.parse(_marketPriceController.text.trim());
      final productionCost = double.parse(_productionCostController.text.trim());

      final repo = ref.read(productRepositoryProvider);
      await repo.addProduct(
        name: name,
        homePrice: homePrice,
        marketPrice: marketPrice,
        productionCost: productionCost,
      );

      // Trigger a UI refresh
      ref.invalidate(productsProvider);

      if (!mounted) return;
      Navigator.pop(context); // close the bottom sheet or page
    } catch (e) {
      debugPrint('Error adding product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 24,
              bottom: mq.viewInsets.bottom + 24,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    'Add Product',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (val) => val!.isEmpty ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _homePriceController,
                    decoration: const InputDecoration(labelText: 'Home Price'),
                    keyboardType: TextInputType.number,
                    validator: (val) => double.tryParse(val ?? '') == null
                        ? 'Enter valid price'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _marketPriceController,
                    decoration: const InputDecoration(labelText: 'Market Price'),
                    keyboardType: TextInputType.number,
                    validator: (val) => double.tryParse(val ?? '') == null
                        ? 'Enter valid price'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _productionCostController,
                    decoration: const InputDecoration(labelText: 'Production Cost'),
                    keyboardType: TextInputType.number,
                    validator: (val) => double.tryParse(val ?? '') == null
                        ? 'Enter valid cost'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleAddProduct,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Add Product'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
