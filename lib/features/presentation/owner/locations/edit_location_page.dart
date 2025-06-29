import 'package:alruba_waterapp/models/location.dart';
import 'package:alruba_waterapp/providers/location_provider.dart';
import 'package:alruba_waterapp/repositories/location_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditLocationPage extends ConsumerStatefulWidget {
  final Location location;
  const EditLocationPage({super.key, required this.location});

  @override
  ConsumerState<EditLocationPage> createState() => _EditLocationPageState();
}

class _EditLocationPageState extends ConsumerState<EditLocationPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.location.name);
  }

  Future<void> _updateLocation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final newName = _nameController.text.trim();

      final repo = ref.read(locationRepositoryProvider);
      await repo.updateLocation(widget.location.id, newName);

      ref.invalidate(locationsProvider);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('حدث خطأ أثناء تعديل الموقع: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
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
                      'تعديل الموقع',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'اسم الموقع'),
                      validator: (value) =>
                          (value == null || value.isEmpty)
                              ? 'يرجى إدخال اسم الموقع'
                              : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updateLocation,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('تحديث الموقع'),
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
