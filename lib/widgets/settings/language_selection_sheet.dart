import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/theme/styles.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';

void showLanguageSelectionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required AppLocalizations l10n,
}) {
  final currentCode = ref.read(localeProvider).languageCode;
  final options = <(String, String)>[
    ('en', l10n.languageEnglish),
    ('hi', l10n.languageHindi),
    ('it', l10n.languageItalian),
  ];
  String selectedCode = currentCode;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Container(
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
                  value: selectedCode,
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
                        (option) => DropdownMenuItem<String>(
                          value: option.$1,
                          child: Text(
                            option.$2,
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
                    setState(() => selectedCode = value);
                  },
                ),
                const Gap(16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref
                          .read(localeProvider.notifier)
                          .setLanguageCode(selectedCode);
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
          );
        },
      );
    },
  );
}
