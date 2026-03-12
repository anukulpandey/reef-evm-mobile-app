import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/service_providers.dart';
import 'main_navigation_screen.dart';
import '../core/theme/styles.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isAuthenticated = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authService = ref.read(authServiceProvider);
    final isAuth = await authService.authenticate();

    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Styles.splashBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: Styles.purpleColor)),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: Styles.splashBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/images/intro.gif", height: 128, width: 128),
              const Gap(24),
              const Text("App is Locked", style: TextStyle(fontSize: 24, color: Styles.textColor, fontWeight: FontWeight.bold)),
              const Gap(24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Styles.secondaryAccentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                onPressed: _checkAuth,
                child: const Text("Unlock", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    }

    return const MainNavigationScreen();
  }
}
