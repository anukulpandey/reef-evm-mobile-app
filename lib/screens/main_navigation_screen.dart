import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'wallet_screen.dart';
import 'pools_screen.dart';
import 'settings_screen.dart';
import '../core/theme/styles.dart';
import '../l10n/app_localizations.dart';
import '../providers/navigation_provider.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const WalletScreen(),
    const PoolsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentIndex = ref.watch(navigationTabProvider);
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) =>
            ref.read(navigationTabProvider.notifier).setIndex(index),
        backgroundColor: Styles.whiteColor,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: Styles.purpleColor,
        unselectedItemColor: Colors.black38,
        type: BottomNavigationBarType.fixed,
        items: [
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
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
