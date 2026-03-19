import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../l10n/app_localizations.dart';
import '../models/fiat_currency.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/settings/fiat_currency_selection_sheet.dart';
import '../widgets/settings/slippage_selection_sheet.dart';
import '../widgets/common/square_checkbox.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/change_password_modal.dart';
import '../widgets/settings/language_selection_sheet.dart';
import '../widgets/settings/rpc_edit_dialog.dart';
import 'dapp_browser_screen.dart';
import '../core/theme/styles.dart';
import '../core/theme/reef_theme_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final walletState = ref.watch(walletProvider);
    final developerExpanded = settings.isDeveloperExpanded;
    final l10n = AppLocalizations.of(context);
    final colors = context.reefColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hideBalances = !walletState.showBalance;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: Column(
        children: [
          Material(
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/reef-header.png'),
                  fit: BoxFit.cover,
                  alignment: Alignment(-0.82, 1.0),
                ),
              ),
              child: topBar(
                context,
                walletState.activeAccount?.address,
                walletState.displayAccountName,
                onAccountTap: () =>
                    ref.read(navigationTabProvider.notifier).setIndex(1),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                Text(
                  l10n.settings,
                  style: TextStyle(
                    fontSize: Styles.fsPageTitle,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const Gap(14),
                Divider(color: colors.borderColor, thickness: 1.2),
                _settingsRow(
                  icon: isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  title: 'Dark Mode',
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  trailing: Switch.adaptive(
                    value: settings.darkModeEnabled,
                    onChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                    },
                  ),
                ),
                _settingsRow(
                  icon: Icons.home_rounded,
                  title: l10n.goHomeOnSwitch,
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  trailing: _SettingsCheckbox(
                    value: settings.goHomeEnabled,
                    onChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setGoHomeOnSwitch(value);
                    },
                  ),
                ),
                _settingsRow(
                  icon: Icons.fingerprint_rounded,
                  title: l10n.biometricAuth,
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  trailing: _SettingsCheckbox(
                    value: settings.biometricsEnabled,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setBiometrics(value);
                    },
                  ),
                ),
                _settingsRow(
                  icon: hideBalances
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  title: 'Hide Balances',
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  trailing: _SettingsCheckbox(
                    value: hideBalances,
                    onChanged: (value) {
                      if (value == hideBalances) return;
                      ref
                          .read(walletProvider.notifier)
                          .toggleBalanceVisibility();
                    },
                  ),
                ),
                _settingsRow(
                  icon: Icons.lock_rounded,
                  title: l10n.changePassword,
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  onTap: () => showChangePasswordModal(context),
                ),
                _settingsRow(
                  icon: Icons.public_rounded,
                  title: l10n.selectLanguage,
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  onTap: () => showLanguageSelectionSheet(
                    context: context,
                    ref: ref,
                    l10n: l10n,
                  ),
                ),
                _settingsRow(
                  icon: Icons.currency_exchange_rounded,
                  title: 'Fiat Currency',
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        settings.fiatCurrency.code,
                        style: TextStyle(
                          color: colors.accentStrong,
                          fontWeight: FontWeight.w800,
                          fontSize: Styles.fsBody,
                        ),
                      ),
                      const Gap(4),
                      Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: colors.textMuted,
                        size: 22,
                      ),
                    ],
                  ),
                  onTap: () => showFiatCurrencySelectionSheet(
                    context: context,
                    ref: ref,
                  ),
                ),
                _settingsRow(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Default Swap Slippage',
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${settings.defaultSlippagePercent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: colors.accentStrong,
                          fontWeight: FontWeight.w800,
                          fontSize: Styles.fsBody,
                        ),
                      ),
                      const Gap(4),
                      Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: colors.textMuted,
                        size: 22,
                      ),
                    ],
                  ),
                  onTap: () =>
                      showSlippageSelectionSheet(context: context, ref: ref),
                ),
                _settingsRow(
                  icon: Icons.travel_explore_rounded,
                  title: 'DApp Browser',
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DappBrowserScreen(),
                    ),
                  ),
                ),
                _settingsRow(
                  icon: Icons.refresh_rounded,
                  title: 'Refresh Balances',
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  onTap: () async {
                    await ref.read(walletProvider.notifier).refreshPortfolio();
                    await ref
                        .read(walletProvider.notifier)
                        .refreshAllAccountBalances();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Balances refreshed')),
                    );
                  },
                ),
                _settingsRow(
                  icon: Icons.copy_rounded,
                  title: 'Copy Active Address',
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  onTap: () async {
                    final address = walletState.activeAccount?.address;
                    if (address == null || address.trim().isEmpty) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No active account selected'),
                        ),
                      );
                      return;
                    }
                    await Clipboard.setData(ClipboardData(text: address));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.copied)));
                  },
                ),
                _settingsRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Developer Mode',
                  textColor: colors.textPrimary,
                  iconColor: colors.textMuted,
                  trailing: _SettingsCheckbox(
                    value: settings.developerModeEnabled,
                    onChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setDeveloperMode(value);
                    },
                  ),
                ),
                if (settings.developerModeEnabled) ...[
                  const Gap(10),
                  Divider(color: colors.borderColor, thickness: 1.2),
                  _settingsRow(
                    icon: Icons.code_rounded,
                    title: l10n.developerSettings,
                    textColor: colors.textPrimary,
                    iconColor: colors.textMuted,
                    trailing: Icon(
                      developerExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 28,
                      color: colors.textPrimary,
                    ),
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setDeveloperExpanded(!developerExpanded);
                    },
                  ),
                  if (developerExpanded)
                    _developerPanel(context, ref, settings.rpcUrl, l10n),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _settingsRow({
    required IconData icon,
    required String title,
    required Color textColor,
    required Color iconColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 30),
            const Gap(12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: Styles.fsBodyStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  static Widget _developerPanel(
    BuildContext context,
    WidgetRef ref,
    String rpcUrl,
    AppLocalizations l10n,
  ) {
    final colors = context.reefColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(left: 46, right: 12, bottom: 12, top: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.cardBackground,
            colors.cardBackgroundSecondary.withOpacity(isDark ? 0.96 : 1),
          ],
        ),
        border: Border.all(
          color: colors.accentStrong.withOpacity(isDark ? 0.22 : 0.12),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.24)
                : const Color(0x1447286E),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [colors.accent, colors.accentStrong],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentStrong.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.rpcEndpoint,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: Styles.fsBodyStrong,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      'Configure the node endpoint used for signing and reads.',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: Styles.fsBody - 1,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.pageBackground.withOpacity(0.32)
                  : Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.accentStrong.withOpacity(isDark ? 0.3 : 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current RPC',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: Styles.fsBody - 2,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        rpcUrl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: Styles.fsBodyStrong,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: rpcUrl));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l10n.copied)));
                    },
                    child: Ink(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.accentStrong.withOpacity(
                          isDark ? 0.2 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.accentStrong.withOpacity(
                            isDark ? 0.34 : 0.16,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.copy_rounded,
                        color: colors.accentStrong,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => showRpcEditDialog(
                context: context,
                ref: ref,
                currentRpc: rpcUrl,
                l10n: l10n,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentStrong,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(
                l10n.editRpc,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCheckbox extends StatelessWidget {
  const _SettingsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    return SquareCheckbox(
      value: value,
      onChanged: onChanged,
      size: 30,
      borderColor: colors.inputBorder,
      checkColor: colors.accent,
      fillColor: colors.inputFill,
      borderWidth: 2,
      borderRadius: 4,
    );
  }
}
