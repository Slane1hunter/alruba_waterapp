import 'package:flutter/material.dart';

class FinancialErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const FinancialErrorWidget({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 16),
            Text('Failed to load data',
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.red)),
            const SizedBox(height: 8),
            Text(error.toString(), 
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}