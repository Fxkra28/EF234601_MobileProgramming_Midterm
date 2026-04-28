import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/category_controller.dart';
import 'controllers/task_controller.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'views/splash_gate.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? bootError;
  try {
    debugPrint('[boot] Firebase.initializeApp...');
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('[boot] Firebase OK');

    debugPrint('[boot] initializeDateFormatting...');
    await initializeDateFormatting('en');
    debugPrint('[boot] DateFormatting OK');

    debugPrint('[boot] NotificationService.init...');
    await NotificationService.instance.init();
    NotificationService.instance.attachNavigatorKey(_navigatorKey);
    debugPrint('[boot] Notifications OK');
  } catch (e, st) {
    debugPrint('[boot] FAILED: $e\n$st');
    bootError = '$e';
  }

  if (bootError != null) {
    runApp(_BootErrorApp(message: bootError));
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => CategoryController()),
        ChangeNotifierProxyProvider2<AuthController, CategoryController,
            TaskController>(
          create: (_) => TaskController(),
          update: (_, auth, cats, prev) {
            final ctrl = prev ?? TaskController();
            ctrl.attachCategoryController(cats);
            ctrl.bindUser(auth.currentUser?.uid);
            return ctrl;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ETS#1 Doze Task",
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          primary: const Color(0xFF4A90E2),
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        scaffoldBackgroundColor: const Color(0xFFF5F9FF),
      ),
      home: const SplashGate(),
    );
  }
}

class _BootErrorApp extends StatelessWidget {
  final String message;
  const _BootErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF5F5),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.error_outline,
                    size: 56, color: Colors.redAccent),
                const SizedBox(height: 12),
                const Text(
                  'Startup error',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The app could not finish initializing. Tell Claude this:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
