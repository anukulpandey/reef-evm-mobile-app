import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/theme/reef_theme_colors.dart';
import '../../core/theme/styles.dart';
import '../../providers/settings_provider.dart';

void showSlippageSelectionSheet({
  required BuildContext context,
  required WidgetRef ref,
}) {
  var selected = ref.read(settingsProvider).defaultSlippagePercent;
  const presets = <double>[0.1, 0.5, 0.8, 1.0, 2.0, 5.0];

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final colors = context.reefColors;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colors.accentStrong.withOpacity(isDark ? 0.22 : 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.26)
                      : const Color(0x200F0028),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.borderColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const Gap(18),
                  Text(
                    'Default Swap Slippage',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: Styles.fsSectionTitle,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    'Pick the slippage tolerance we should prefill whenever you open the swap flow.',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: Styles.fsBody,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const Gap(18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: presets.map((option) {
                      final selectedOption =
                          option.toStringAsFixed(1) ==
                          selected.toStringAsFixed(1);
                      return ChoiceChip(
                        label: Text('${option.toStringAsFixed(1)}%'),
                        selected: selectedOption,
                        onSelected: (_) => setState(() => selected = option),
                        labelStyle: TextStyle(
                          color: selectedOption
                              ? Colors.white
                              : colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: Styles.fsBody,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: selectedOption
                                ? colors.accentStrong
                                : colors.inputBorder,
                          ),
                        ),
                        selectedColor: colors.accentStrong,
                        backgroundColor: isDark
                            ? colors.inputFill
                            : Colors.white.withOpacity(0.85),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const Gap(18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.pageBackground.withOpacity(0.3)
                          : Colors.white.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: colors.accentStrong,
                          size: 20,
                        ),
                        const Gap(10),
                        Expanded(
                          child: Text(
                            'Current default: ${selected.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: Styles.fsBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await ref
                            .read(settingsProvider.notifier)
                            .setDefaultSlippagePercent(selected);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accentStrong,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Use This Default',
                        style: TextStyle(
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
    },
  );
}
