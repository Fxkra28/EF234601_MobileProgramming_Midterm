import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return StreamBuilder<User?>(
      stream: auth.authState,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        return const HomeScreen();
      },
    );
  }
}
