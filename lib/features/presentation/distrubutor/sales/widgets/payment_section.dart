import 'package:flutter/material.dart';

class PaymentSection extends StatelessWidget {
  final String paymentStatus;
  final ValueChanged<String?> onPaymentStatusChanged;
  final List<String> paymentOptions;
  final TextEditingController notesController;

  const PaymentSection({
    super.key,
    required this.paymentStatus,
    required this.onPaymentStatusChanged,
    required this.paymentOptions,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Payment Status',
            border: OutlineInputBorder(),
          ),
          value: paymentStatus,
          items: paymentOptions.map((status) {
            return DropdownMenuItem<String>(
              value: status,
              child: Text(status),
            );
          }).toList(),
          onChanged: onPaymentStatusChanged,
          validator: (val) {
            if (val == null) {
              return 'Please select a payment status';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        if (paymentStatus == 'Unpaid')
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Warning: Payment pending',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
