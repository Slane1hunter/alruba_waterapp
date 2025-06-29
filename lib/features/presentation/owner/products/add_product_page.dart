import 'package:alruba_waterapp/providers/products_provider.dart';
import 'package:alruba_waterapp/repositories/product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

class ThousandsFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || newValue.text == '-') {
      return newValue;
    }

    final plain = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = plain.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : null;
    final intValue = int.tryParse(integerPart);
    if (intValue == null) return oldValue;
    final formattedInt = _formatter.format(intValue);
    final resultText =
        decimalPart != null ? '$formattedInt.$decimalPart' : formattedInt;
    int selectionIndex = resultText.length -
        (plain.length - newValue.selection.end);

    return TextEditingValue(
      text: resultText,
      selection: TextSelection.collapsed(
        offset: selectionIndex.clamp(0, resultText.length),
      ),
    );
  }
}

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
  bool _isRefillable = false;

  Future<void> _handleAddProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final homePrice =
          double.parse(_homePriceController.text.replaceAll(',', ''));
      final marketPrice =
          double.parse(_marketPriceController.text.replaceAll(',', ''));
      final productionCost =
          double.parse(_productionCostController.text.replaceAll(',', ''));

      final repo = ref.read(productRepositoryProvider);
      await repo.addProduct(
        name: name,
        homePrice: homePrice,
        marketPrice: marketPrice,
        productionCost: productionCost,
        isRefillable: _isRefillable,
      );

      ref.invalidate(productsProvider);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('خطأ أثناء إضافة المنتج: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء إضافة المنتج: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
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
                      'إضافة منتج',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // الاسم
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'الاسم'),
                      validator: (val) =>
                          val!.trim().isEmpty ? 'أدخل الاسم' : null,
                    ),
                    const SizedBox(height: 16),

                    // سعر المنزل
                    TextFormField(
                      controller: _homePriceController,
                      decoration:
                          const InputDecoration(labelText: 'سعر التوصيل للمنزل'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [ThousandsFormatter()],
                      validator: (val) {
                        final cleaned = val?.replaceAll(',', '') ?? '';
                        return double.tryParse(cleaned) == null
                            ? 'أدخل سعراً صالحاً'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // سعر السوق
                    TextFormField(
                      controller: _marketPriceController,
                      decoration:
                          const InputDecoration(labelText: 'سعر السوق'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [ThousandsFormatter()],
                      validator: (val) {
                        final cleaned = val?.replaceAll(',', '') ?? '';
                        return double.tryParse(cleaned) == null
                            ? 'أدخل سعراً صالحاً'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // تكلفة الإنتاج
                    TextFormField(
                      controller: _productionCostController,
                      decoration:
                          const InputDecoration(labelText: 'تكلفة الإنتاج'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [ThousandsFormatter()],
                      validator: (val) {
                        final cleaned = val?.replaceAll(',', '') ?? '';
                        return double.tryParse(cleaned) == null
                            ? 'أدخل تكلفة صالحة'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // قابل لإعادة التعبئة
                    SwitchListTile(
                      title: const Text('قنينة قابلة لإعادة التعبئة'),
                      value: _isRefillable,
                      onChanged: (value) =>
                          setState(() => _isRefillable = value),
                    ),
                    const SizedBox(height: 24),

                    // زر الإرسال
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleAddProduct,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('إضافة المنتج'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
