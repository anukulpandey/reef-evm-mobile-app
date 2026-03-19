import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'wallet_screen.dart';
import 'pools_screen.dart';
import 'token_creator_screen.dart';
import 'settings_screen.dart';
import '../core/theme/reef_theme_colors.dart';
import '../l10n/app_localizations.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<SettingsState>(settingsProvider, (previous, next) {
      final wasEnabled = previous?.developerModeEnabled ?? false;
      final isEnabled = next.developerModeEnabled;
      if (wasEnabled == isEnabled) return;

      final notifier = ref.read(navigationTabProvider.notifier);
      final currentIndex = ref.read(navigationTabProvider);

      if (!wasEnabled && isEnabled && currentIndex >= 3) {
        notifier.setIndex(currentIndex + 1);
        return;
      }

      if (wasEnabled && !isEnabled && currentIndex > 3) {
        notifier.setIndex(currentIndex - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final currentIndex = ref.watch(navigationTabProvider);
    final colors = context.reefColors;
    final developerModeEnabled = settings.developerModeEnabled;
    final screens = <Widget>[
      const HomeScreen(),
      const WalletScreen(),
      const PoolsScreen(),
      if (developerModeEnabled) const TokenCreatorScreen(),
      const SettingsScreen(),
    ];
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        label: l10n.home,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: l10n.wallet,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.cached),
        label: l10n.pools,
      ),
      if (developerModeEnabled)
        const BottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome_rounded),
          label: 'Create Token',
        ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.settings_outlined),
        label: l10n.settings,
      ),
    ];
    final safeIndex = currentIndex >= screens.length
        ? screens.length - 1
        : currentIndex;

    if (safeIndex != currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(navigationTabProvider.notifier).setIndex(safeIndex);
      });
    }

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (index) =>
            ref.read(navigationTabProvider.notifier).setIndex(index),
        backgroundColor: colors.navBackground,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.navUnselected,
        type: BottomNavigationBarType.fixed,
        items: items,
      ),
    );
  }
}
