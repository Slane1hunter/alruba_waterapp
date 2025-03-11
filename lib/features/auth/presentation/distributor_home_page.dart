import 'package:flutter/material.dart';

class DistributorHome extends StatelessWidget {
  const DistributorHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Distributor Dashboard')),
      body: const Center(child: Text('Distributor View')),
    );
  }
}