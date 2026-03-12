import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/change_password_modal.dart';
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
                  onTap: () => showChangePasswordModal(context),
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
                onPressed: () => _showRpcEditDialog(context, ref, rpcUrl, l10n),
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

  static Widget _squareCheckBox({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Checkbox(
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        fillColor: WidgetStateProperty.resolveWith<Color>((_) => Colors.white),
        checkColor: const Color(0xFFB9359A),
        side: const BorderSide(color: Color(0xFF9AA2BC), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
    bool isValidRpc(String value) {
      final text = value.trim();
      if (text.isEmpty) return false;
      final uri = Uri.tryParse(text);
      if (uri == null) return false;
      return (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        String draft = currentRpc;
        bool submitted = false;
        return StatefulBuilder(
          builder: (context, setState) {
            final valid = isValidRpc(draft);
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4B047B), Color(0xFF3B006A)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x401D0038),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.hub_rounded,
                            color: Color(0xFFE5D8FF),
                            size: 20,
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              l10n.editRpc,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 30,
                                height: 1.0,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.pop(dialogContext),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                color: Color(0xFFDCCBFF),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(12),
                      const Text(
                        'RPC URL',
                        style: TextStyle(
                          color: Color(0xFFCDB7F4),
                          fontSize: Styles.fsSmall,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const Gap(6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (submitted && !valid)
                                ? const Color(0xFFFF8FA3)
                                : const Color(0xFFE0D7F4),
                            width: 1.2,
                          ),
                        ),
                        child: TextField(
                          controller: controller,
                          onChanged: (value) {
                            setState(() => draft = value);
                          },
                          style: const TextStyle(
                            color: Color(0xFF2B1C49),
                            fontWeight: FontWeight.w700,
                            fontSize: Styles.fsBodyStrong,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'http://127.0.0.1:8545',
                            hintStyle: TextStyle(
                              color: Color(0xFFA79DBE),
                              fontWeight: FontWeight.w600,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      if (submitted && !valid) ...[
                        const Gap(8),
                        const Text(
                          'Please enter a valid http/https RPC URL',
                          style: TextStyle(
                            color: Color(0xFFFFB7C2),
                            fontSize: Styles.fsSmall,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const Gap(16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE7D8FF),
                                side: const BorderSide(
                                  color: Color(0xFF9A79D6),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                l10n.cancel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final value = controller.text.trim();
                                final isValid = isValidRpc(value);
                                setState(() {
                                  draft = value;
                                  submitted = true;
                                });
                                if (!isValid) return;
                                ref
                                    .read(settingsProvider.notifier)
                                    .setRpcUrl(value);
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('RPC updated successfully'),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB83DAA),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                l10n.save,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) => Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE8F7),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x240F0028),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.selectLanguage,
                  style: const TextStyle(
                    color: Color(0xFF2D2340),
                    fontWeight: FontWeight.w900,
                    fontSize: Styles.fsBodyStrong,
                  ),
                ),
                const Gap(12),
                DropdownButtonFormField<String>(
                  value: selected,
                  dropdownColor: Colors.white,
                  iconEnabledColor: const Color(0xFF6F35C0),
                  style: const TextStyle(
                    color: Color(0xFF2D2340),
                    fontWeight: FontWeight.w700,
                    fontSize: Styles.fsBodyStrong,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFBFB3D9)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFBFB3D9)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF7A3CC5),
                        width: 1.4,
                      ),
                    ),
                  ),
                  items: options
                      .map(
                        (opt) => DropdownMenuItem<String>(
                          value: opt.$1,
                          child: Text(
                            opt.$2,
                            style: const TextStyle(
                              color: Color(0xFF2D2340),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E2AB7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      l10n.changeLanguage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: Styles.fsBodyStrong,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
