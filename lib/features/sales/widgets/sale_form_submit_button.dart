import 'package:flutter/material.dart';

class SaleFormSubmitButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SaleFormSubmitButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.add),
      label: const Text('Add Sale'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: onPressed,
    );
  }
}
