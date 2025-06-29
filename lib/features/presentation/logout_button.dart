
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';

class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key, required bool fullWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        // Sign out from Supabase
        await SupabaseService.client.auth.signOut();

        // If you want to navigate the user to a login screen:
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
      ),
      child: const Text('تسجيل الخروج'),
    );
  }
}

