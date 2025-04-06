import 'package:alruba_waterapp/models/product.dart';
import 'package:alruba_waterapp/providers/products_provider.dart';
import 'package:alruba_waterapp/repositories/product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class EditProductPage extends ConsumerStatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  ConsumerState<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends ConsumerState<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _homePriceController;
  late TextEditingController _marketPriceController;
  late TextEditingController _productionCostController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _homePriceController =
        TextEditingController(text: widget.product.homePrice.toString());
    _marketPriceController =
        TextEditingController(text: widget.product.marketPrice.toString());
    _productionCostController =
        TextEditingController(text: widget.product.productionCost.toString());
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final updatedName = _nameController.text.trim();
      final homePrice = double.parse(_homePriceController.text.trim());
      final marketPrice = double.parse(_marketPriceController.text.trim());
      final productionCost = double.parse(_productionCostController.text.trim());

      final repo = ref.read(productRepositoryProvider);
      await repo.updateProduct(
        productId: widget.product.id,
        name: updatedName,
        homePrice: homePrice,
        marketPrice: marketPrice,
        productionCost: productionCost,
      );

      ref.invalidate(productsProvider);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error updating product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating product: $e')),
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
                    'Edit Product',
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
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Home Price'),
                    validator: (val) => double.tryParse(val ?? '') == null
                        ? 'Enter a valid price'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _marketPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Market Price'),
                    validator: (val) => double.tryParse(val ?? '') == null
                        ? 'Enter a valid price'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _productionCostController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Production Cost'),
                    validator: (val) => double.tryParse(val ?? '') == null
                        ? 'Enter a valid cost'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleUpdate,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Update Product'),
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
