import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/task_controller.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A90E2),
              fontSize: 22),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFF4A90E2),
                  child: const Icon(Icons.person,
                      size: 32, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? '—',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _tile(
            context,
            icon: Icons.notifications_active,
            label: 'Test reminder pop-up (10 s)',
            color: const Color(0xFF4A90E2),
            onTap: () async {
              await NotificationService.instance.showTestReminder();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pop-up will appear in 10 seconds.'),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.logout,
            label: 'Sign out',
            color: const Color(0xFF4A90E2),
            onTap: () async {
              final confirm = await _confirm(
                context,
                title: 'Sign out',
                body: 'You can sign back in any time.',
                confirmLabel: 'Sign out',
                destructive: false,
              );
              if (confirm == true) {
                await auth.signOut();
              }
            },
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.delete_forever,
            label: 'Delete account',
            color: Colors.red,
            onTap: () => _deleteAccountFlow(context),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: color)),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: destructive
                ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccountFlow(BuildContext context) async {
    final auth = context.read<AuthController>();
    final tasks = context.read<TaskController>();
    final pwCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This wipes all your tasks, labels, and photos. This cannot be undone.'),
            const SizedBox(height: 12),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final uid = auth.currentUser?.uid;
    try {
      if (uid != null) {
        await FirestoreService.instance.wipeUser(uid);
      }
      await tasks.wipeForLogout();
    } catch (_) {}
    final ok = await auth.deleteAccount(pwCtrl.text);
    if (!context.mounted) return;
    if (!ok && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }
}
