import 'package:alruba_waterapp/providers/location_provider.dart';
import 'package:alruba_waterapp/repositories/location_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddLocationPage extends ConsumerStatefulWidget {
  const AddLocationPage({super.key});

  @override
  ConsumerState<AddLocationPage> createState() => _AddLocationPageState();
}

class _AddLocationPageState extends ConsumerState<AddLocationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addLocation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();

      final repo = ref.read(locationRepositoryProvider);
      await repo.addLocation(name);

      // إعادة تحميل المواقع
      ref.invalidate(locationsProvider);

      if (!mounted) return;
      Navigator.pop(context); // إغلاق الشاشة
    } catch (e) {
      debugPrint('حدث خطأ أثناء إضافة الموقع: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء إضافة الموقع: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Directionality( // لضبط اتجاه النص للعربية
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
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
                      'إضافة موقع جديد',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'اسم الموقع'),
                      validator: (value) =>
                          (value == null || value.isEmpty)
                              ? 'الرجاء إدخال اسم الموقع'
                              : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addLocation,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('إضافة الموقع'),
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
