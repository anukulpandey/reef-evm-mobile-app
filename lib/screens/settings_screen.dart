import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../providers/service_providers.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/official_top_bar.dart';
import '../core/theme/styles.dart';
import 'wallet_connect_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final walletState = ref.watch(walletProvider);
    final developerExpanded = settings.isDeveloperExpanded;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFD9D6E3),
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
                onWalletConnectTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WalletConnectScreen(),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                Text(
                  l10n.settings,
                  style: const TextStyle(
                    fontSize: Styles.fsPageTitle,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B3C44),
                  ),
                ),
                const Gap(14),
                const Divider(color: Color(0xFF8F98B5), thickness: 1.2),
                _settingsRow(
                  icon: Icons.qr_code_2_rounded,
                  title: l10n.walletConnect,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WalletConnectScreen(),
                    ),
                  ),
                ),
                const Divider(color: Color(0xFF8F98B5), thickness: 1.2),
                _settingsRow(
                  icon: Icons.home_rounded,
                  title: l10n.goHomeOnSwitch,
                  trailing: _squareCheckBox(
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
                  trailing: _squareCheckBox(
                    value: settings.biometricsEnabled,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setBiometrics(value);
                    },
                  ),
                ),
                _settingsRow(
                  icon: Icons.lock_rounded,
                  title: l10n.changePassword,
                  onTap: () => _showChangePasswordDialog(context, ref, l10n),
                ),
                _settingsRow(
                  icon: Icons.public_rounded,
                  title: l10n.selectLanguage,
                  onTap: () => _showLanguageModal(context, ref, l10n),
                ),
                const Gap(10),
                const Divider(color: Color(0xFF8F98B5), thickness: 1.2),
                _settingsRow(
                  icon: Icons.code_rounded,
                  title: l10n.developerSettings,
                  trailing: Icon(
                    developerExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 28,
                    color: const Color(0xFF23232D),
                  ),
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setDeveloperExpanded(!developerExpanded);
                  },
                ),
                if (developerExpanded)
                  Container(
                    margin: const EdgeInsets.only(
                      left: 46,
                      right: 12,
                      bottom: 12,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.rpcEndpoint,
                          style: TextStyle(
                            color: Color(0xFF23232D),
                            fontWeight: FontWeight.w800,
                            fontSize: Styles.fsBody,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          settings.rpcUrl,
                          style: const TextStyle(
                            color: Color(0xFF4F556F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            onPressed: () => _showRpcEditDialog(
                              context,
                              ref,
                              settings.rpcUrl,
                              l10n,
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF8F98B5)),
                            ),
                            child: Text(l10n.editRpc),
                          ),
                        ),
                      ],
                    ),
                  ),
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
            Icon(icon, color: const Color(0xFF8D96B0), size: 30),
            const Gap(12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F1E27),
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

  static Widget _squareCheckBox({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: value ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF9AA2BC), width: 2),
        ),
        child: value
            ? const Icon(
                Icons.check_rounded,
                color: Color(0xFFB9359A),
                size: 24,
              )
            : null,
      ),
    );
  }

  static void _showRpcEditDialog(
    BuildContext context,
    WidgetRef ref,
    String currentRpc,
    AppLocalizations l10n,
  ) {
    final controller = TextEditingController(text: currentRpc);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.editRpc),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'http://127.0.0.1:8545'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setRpcUrl(controller.text);
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  static void _showLanguageModal(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final currentCode = ref.read(localeProvider).languageCode;
    final options = <(String, String)>[
      ('en', l10n.languageEnglish),
      ('hi', l10n.languageHindi),
      ('it', l10n.languageItalian),
    ];
    String selected = currentCode;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.selectLanguage,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const Gap(12),
                DropdownButtonFormField<String>(
                  value: selected,
                  items: options
                      .map(
                        (opt) => DropdownMenuItem<String>(
                          value: opt.$1,
                          child: Text(opt.$2),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => selected = value);
                  },
                ),
                const Gap(16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(localeProvider.notifier)
                          .setLanguageCode(selected);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: Text(l10n.changeLanguage),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final password = TextEditingController();
    final confirm = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.setPassword),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.newPassword),
              ),
              const Gap(10),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.confirmPassword),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                final pass = password.text.trim();
                final repeat = confirm.text.trim();
                if (pass.isEmpty || pass != repeat) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.passwordMismatch)),
                  );
                  return;
                }
                await ref.read(authServiceProvider).setAppPassword(pass);
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.passwordSaved)));
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }
}
