import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/reef_theme_colors.dart';
import '../core/theme/styles.dart';
import '../l10n/app_localizations.dart';
import '../providers/service_providers.dart';
import 'main_navigation_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isAuthenticated = false;
  bool _isChecking = true;
  bool _requiresPassword = false;
  bool _passwordError = false;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final authService = ref.read(authServiceProvider);
    final isAuth = await authService.authenticate();
    final hasPassword = await authService.hasAppPassword();

    if (!mounted) return;
    setState(() {
      _isAuthenticated = isAuth;
      _isChecking = false;
      _requiresPassword = hasPassword;
      _passwordError = false;
      if (isAuth) {
        _passwordController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.reefColors;
    if (_isChecking) {
      return Scaffold(
        backgroundColor: Styles.splashBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/intro.gif', height: 128, width: 128),
              const Gap(24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.initialisingApp,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      color: Styles.textLightColor,
                    ),
                  ),
                  const Gap(8),
                  const SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Styles.textLightColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: Styles.splashBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/intro.gif', height: 128, width: 128),
              const Gap(24),
              Text(
                l10n.appLocked,
                style: const TextStyle(
                  fontSize: 24,
                  color: Styles.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_requiresPassword) ...[
                const Gap(16),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: (_) {
                      if (_passwordError) {
                        setState(() => _passwordError = false);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: l10n.enterAppPassword,
                      hintStyle: TextStyle(color: colors.textMuted),
                      errorText: _passwordError ? l10n.invalidPassword : null,
                      filled: true,
                      fillColor: colors.cardBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: colors.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: colors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: colors.accentStrong,
                          width: 1.4,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Gap(24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient: Styles.buttonGradient,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                  ),
                  onPressed: () async {
                    if (!_requiresPassword) {
                      _checkAuth();
                      return;
                    }

                    final ok = await ref
                        .read(authServiceProvider)
                        .verifyAppPassword(_passwordController.text);
                    if (!mounted) return;
                    if (ok) {
                      setState(() {
                        _isAuthenticated = true;
                        _passwordError = false;
                      });
                      return;
                    }
                    setState(() => _passwordError = true);
                  },
                  child: Text(
                    l10n.unlock,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const MainNavigationScreen();
  }
}
