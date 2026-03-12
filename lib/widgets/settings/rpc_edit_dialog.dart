import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/theme/styles.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';

void showRpcEditDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentRpc,
  required AppLocalizations l10n,
}) {
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
                              side: const BorderSide(color: Color(0xFF9A79D6)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
