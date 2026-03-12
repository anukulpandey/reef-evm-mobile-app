import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    final fcmService = FCMService();
    await fcmService.init();
  } catch (e) {
    print(
      "Firebase initialization failed (probably missing google-services.json): \$e",
    );
  }

  runApp(const ProviderScope(child: ReefWalletApp()));
}

class ReefWalletApp extends StatelessWidget {
  const ReefWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reef Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthScreen(),
    );
  }
}
