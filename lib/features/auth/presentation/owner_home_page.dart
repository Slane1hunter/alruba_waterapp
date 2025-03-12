import 'package:flutter/material.dart';
import 'logout_button.dart';


class OwnerHome extends StatelessWidget {
  const OwnerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: const [
          // Display your LogoutButton in the top-right corner
          LogoutButton(),
        ],
      ),
      body: const Center(child: Text('Owner View')),
    );
  }
}

