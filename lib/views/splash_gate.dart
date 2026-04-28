import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import 'auth/auth_gate.dart';

class SplashGate extends StatelessWidget {
  const SplashGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return StreamBuilder<User?>(
      stream: auth.authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashView();
        }
        return const AuthGate();
      },
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.task_alt, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              "Fata's Doze Task",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
