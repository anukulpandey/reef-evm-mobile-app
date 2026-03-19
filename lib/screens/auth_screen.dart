import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  bool _isUnlocking = false;
  bool _obscurePassword = true;
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
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    if (_isChecking) {
      return Scaffold(
        backgroundColor: isDarkTheme
            ? colors.deepBackground
            : Styles.splashBackgroundColor,
        body: _AuthLayout(
          isDarkTheme: isDarkTheme,
          headerChild: const _AuthHeaderBrand(
            title: 'Secure access',
            subtitle: 'Your Reef wallet is protected locally on this device.',
          ),
          panelChild: _AuthPanelCard(
            icon: Icons.shield_rounded,
            eyebrow: 'Preparing wallet',
            title: l10n.initialisingApp,
            description: 'Preparing your wallet securely.',
            footer: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accentStrong),
              ),
            ),
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: isDarkTheme
            ? colors.deepBackground
            : Styles.splashBackgroundColor,
        body: _AuthLayout(
          isDarkTheme: isDarkTheme,
          headerChild: const _AuthHeaderBrand(
            title: 'Wallet Security',
            subtitle: 'Unlock your Reef wallet to continue.',
          ),
          panelChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AuthPanelCard(
                icon: Icons.lock_rounded,
                eyebrow: 'Protected wallet',
                title: l10n.appLocked,
                description: _requiresPassword
                    ? 'Enter your app password to unlock the wallet and continue securely.'
                    : 'Authenticate to unlock your wallet and continue.',
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_requiresPassword) _buildPasswordField(colors: colors),
                    if (_requiresPassword && _passwordError) ...[
                      const Gap(12),
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: colors.danger,
                            size: 18,
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              l10n.invalidPassword,
                              style: TextStyle(
                                color: colors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Gap(22),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: Styles.buttonGradient,
                          boxShadow: [
                            BoxShadow(
                              color: colors.accentStrong.withOpacity(0.28),
                              blurRadius: 20,
                              offset: const Offset(0, 12),
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 16,
                            ),
                          ),
                          onPressed: _isUnlocking ? null : _unlock,
                          child: _isUnlocking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  l10n.unlock,
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDarkTheme
                      ? colors.cardBackground.withOpacity(0.58)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDarkTheme
                        ? colors.borderColor.withOpacity(0.7)
                        : colors.borderColor.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 18,
                      color: colors.accentStrong,
                    ),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        'Your accounts stay encrypted locally and are only unlocked on this device.',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const MainNavigationScreen();
  }

  Widget _buildPasswordField({required ReefThemeColors colors}) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDarkTheme ? colors.cardBackgroundSecondary : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _passwordError ? colors.danger : colors.inputBorder,
          width: _passwordError ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.04,
            ),
            blurRadius: 20,
            offset: const Offset(0, 12),
            spreadRadius: -16,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        enableSuggestions: false,
        autocorrect: false,
        onChanged: (_) {
          if (_passwordError) {
            setState(() => _passwordError = false);
          }
        },
        style: GoogleFonts.spaceGrotesk(
          color: colors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).enterAppPassword,
          hintStyle: TextStyle(
            color: colors.textMuted,
            fontWeight: FontWeight.w500,
          ),
          filled: false,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            color: colors.textMuted,
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
          suffixIcon: IconButton(
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);
    try {
      if (!_requiresPassword) {
        await _checkAuth();
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
    } finally {
      if (mounted) {
        setState(() => _isUnlocking = false);
      }
    }
  }
}

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({
    required this.headerChild,
    required this.panelChild,
    required this.isDarkTheme,
  });

  final Widget headerChild;
  final Widget panelChild;
  final bool isDarkTheme;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 214,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/reef-header.png'),
                      fit: BoxFit.cover,
                      alignment: Alignment(-0.7, 0),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(isDarkTheme ? 0.18 : 0.06),
                        colors.deepBackground.withOpacity(
                          isDarkTheme ? 0.62 : 0.42,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                  child: headerChild,
                ),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDarkTheme ? colors.pageBackground : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(38),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: panelChild,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthHeaderBrand extends StatelessWidget {
  const _AuthHeaderBrand({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SvgPicture.asset(
          'assets/images/reef-logo-light.svg',
          width: 118,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 15),
                  const Gap(8),
                  Text(
                    'Locally secured',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(14),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 31,
                height: 1,
              ),
            ),
            const Gap(8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuthPanelCard extends StatelessWidget {
  const _AuthPanelCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.footer,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: isDarkTheme
            ? colors.cardBackground.withOpacity(0.98)
            : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDarkTheme
              ? colors.borderColor.withOpacity(0.85)
              : colors.borderColor.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkTheme ? 0.24 : 0.07),
            blurRadius: 26,
            offset: const Offset(0, 18),
            spreadRadius: -14,
          ),
          BoxShadow(
            color: colors.accentStrong.withOpacity(isDarkTheme ? 0.06 : 0.03),
            blurRadius: 28,
            offset: const Offset(0, 8),
            spreadRadius: -18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Styles.buttonGradient,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentStrong.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: colors.accentStrong,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Gap(3),
                    Text(
                      title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 31,
                        height: 1,
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(16),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(24),
          footer,
        ],
      ),
    );
  }
}
