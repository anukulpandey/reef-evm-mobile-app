import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/common/square_checkbox.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/change_password_modal.dart';
import '../widgets/settings/language_selection_sheet.dart';
import '../widgets/settings/rpc_edit_dialog.dart';
import '../core/theme/styles.dart';

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
                  icon: Icons.home_rounded,
                  title: l10n.goHomeOnSwitch,
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
                  trailing: _SettingsCheckbox(
                    value: settings.biometricsEnabled,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setBiometrics(value);
                    },
                  ),
                ),
                _settingsRow(
                  icon: Icons.lock_rounded,
                  title: l10n.changePassword,
                  onTap: () => showChangePasswordModal(context),
                ),
                _settingsRow(
                  icon: Icons.public_rounded,
                  title: l10n.selectLanguage,
                  onTap: () => showLanguageSelectionSheet(
                    context: context,
                    ref: ref,
                    l10n: l10n,
                  ),
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
                  _developerPanel(context, ref, settings.rpcUrl, l10n),
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

  static Widget _developerPanel(
    BuildContext context,
    WidgetRef ref,
    String rpcUrl,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.only(left: 46, right: 12, bottom: 12, top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDE8F8), Color(0xFFE4DCF3)],
        ),
        border: Border.all(color: const Color(0xFFBEB4D6), width: 1),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A47286E),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: Color(0xFF7A3CC5), size: 18),
              const Gap(6),
              Text(
                l10n.rpcEndpoint,
                style: const TextStyle(
                  color: Color(0xFF2A2338),
                  fontWeight: FontWeight.w900,
                  fontSize: Styles.fsBodyStrong,
                ),
              ),
            ],
          ),
          const Gap(10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC9C1DB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    rpcUrl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF4A4260),
                      fontWeight: FontWeight.w700,
                      fontSize: Styles.fsBody,
                    ),
                  ),
                ),
                const Gap(8),
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: rpcUrl));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.copied)));
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.copy_rounded,
                      color: Color(0xFF7A3CC5),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => showRpcEditDialog(
                  context: context,
                  ref: ref,
                  currentRpc: rpcUrl,
                  l10n: l10n,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B34BD),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(
                  l10n.editRpc,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
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
    return SquareCheckbox(
      value: value,
      onChanged: onChanged,
      size: 30,
      borderColor: const Color(0xFF9AA2BC),
      checkColor: const Color(0xFFB9359A),
      fillColor: Colors.white,
      borderWidth: 2,
      borderRadius: 4,
    );
  }
}
