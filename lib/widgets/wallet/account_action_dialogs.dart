import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';

Future<bool> showDeleteAccountConfirmation({
  required BuildContext context,
  required AppLocalizations l10n,
}) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.deleteAccount),
        content: Text(l10n.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteLabel),
          ),
        ],
      );
    },
  );
  return shouldDelete == true;
}

Future<String?> showRenameAccountDialog({
  required BuildContext context,
  required AppLocalizations l10n,
  required String currentName,
}) async {
  final normalizedCurrent = currentName.trim();
  final controller = TextEditingController(
    text: (normalizedCurrent == '<No Name>' || normalizedCurrent == l10n.noName)
        ? ''
        : normalizedCurrent,
  );

  try {
    return await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (localContext, setState) {
            final palette = _dialogPalette(localContext);
            final canSave = controller.text.trim().isNotEmpty;
            return AlertDialog(
              backgroundColor: palette.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                l10n.renameAccountTitle,
                style: TextStyle(
                  color: palette.title,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                cursorColor: palette.accent,
                style: TextStyle(
                  color: palette.inputText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _dialogInputDecoration(
                  palette: palette,
                  labelText: l10n.accountNameLabel,
                  hintText: l10n.noName,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (!canSave) return;
                  Navigator.pop(dialogContext, controller.text.trim());
                },
              ),
              actions: [
                TextButton(
                  style: _dialogActionButtonStyle(),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    l10n.cancel,
                    style: TextStyle(color: palette.actionText),
                  ),
                ),
                TextButton(
                  style: _dialogActionButtonStyle(),
                  onPressed: canSave
                      ? () =>
                            Navigator.pop(dialogContext, controller.text.trim())
                      : null,
                  child: Text(
                    l10n.save,
                    style: TextStyle(
                      color: canSave
                          ? palette.actionText
                          : palette.actionText.withOpacity(0.45),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

Future<bool> confirmExportWithPassword({
  required BuildContext context,
  required AppLocalizations l10n,
  required AuthService authService,
}) async {
  final hasPassword = await authService.hasAppPassword();
  if (!hasPassword) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.setPasswordBeforeExport)));
    return false;
  }

  final controller = TextEditingController();
  try {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        bool invalidPassword = false;
        bool loading = false;

        return StatefulBuilder(
          builder: (localContext, setState) {
            final palette = _dialogPalette(localContext);
            Future<void> submit() async {
              final input = controller.text.trim();
              if (input.isEmpty) {
                setState(() => invalidPassword = true);
                return;
              }
              setState(() => loading = true);
              final isValid = await authService.verifyAppPassword(input);
              if (isValid) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
                return;
              }
              if (!dialogContext.mounted) return;
              setState(() {
                loading = false;
                invalidPassword = true;
              });
            }

            return AlertDialog(
              backgroundColor: palette.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                l10n.exportAccount,
                style: TextStyle(
                  color: palette.title,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                textInputAction: TextInputAction.done,
                cursorColor: palette.accent,
                style: TextStyle(
                  color: palette.inputText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _dialogInputDecoration(
                  palette: palette,
                  labelText: l10n.enterAppPassword,
                  errorText: invalidPassword ? l10n.invalidPassword : null,
                ),
                onChanged: (_) {
                  if (!invalidPassword) return;
                  setState(() => invalidPassword = false);
                },
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  style: _dialogActionButtonStyle(),
                  onPressed: loading
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: Text(
                    l10n.cancel,
                    style: TextStyle(
                      color: loading
                          ? palette.actionText.withOpacity(0.45)
                          : palette.actionText,
                    ),
                  ),
                ),
                TextButton(
                  style: _dialogActionButtonStyle(),
                  onPressed: loading ? null : submit,
                  child: Text(
                    l10n.exportAccount,
                    style: TextStyle(
                      color: loading
                          ? palette.actionText.withOpacity(0.45)
                          : palette.actionText,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  } finally {
    controller.dispose();
  }
}

class _DialogPalette {
  final Color background;
  final Color title;
  final Color inputText;
  final Color inputLabel;
  final Color inputBorder;
  final Color hint;
  final Color actionText;
  final Color accent;

  const _DialogPalette({
    required this.background,
    required this.title,
    required this.inputText,
    required this.inputLabel,
    required this.inputBorder,
    required this.hint,
    required this.actionText,
    required this.accent,
  });
}

_DialogPalette _dialogPalette(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return const _DialogPalette(
      background: Color(0xFF42007A),
      title: Colors.white,
      inputText: Colors.white,
      inputLabel: Color(0xFFB898D9),
      inputBorder: Color(0xFFB355D8),
      hint: Color(0xFF997CB8),
      actionText: Color(0xFFD565E5),
      accent: Color(0xFFD15BE6),
    );
  }

  return const _DialogPalette(
    background: Colors.white,
    title: Color(0xFF22263D),
    inputText: Color(0xFF1F1F28),
    inputLabel: Color(0xFF8087A0),
    inputBorder: Color(0xFFC7CAD8),
    hint: Color(0xFFA2A8BB),
    actionText: Color(0xFF8C2AC9),
    accent: Color(0xFF8C2AC9),
  );
}

InputDecoration _dialogInputDecoration({
  required _DialogPalette palette,
  required String labelText,
  String? hintText,
  String? errorText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    labelStyle: TextStyle(
      color: palette.inputLabel,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(
      color: palette.hint,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: palette.inputBorder, width: 2),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: palette.accent, width: 2),
    ),
  );
}

ButtonStyle _dialogActionButtonStyle() {
  return TextButton.styleFrom(
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );
}
