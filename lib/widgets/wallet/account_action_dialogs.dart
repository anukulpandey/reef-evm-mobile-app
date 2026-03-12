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
          builder: (context, setState) {
            final canSave = controller.text.trim().isNotEmpty;
            return AlertDialog(
              title: Text(l10n.renameAccountTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Color(0xFF1F1F28)),
                decoration: InputDecoration(
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: canSave
                      ? () =>
                            Navigator.pop(dialogContext, controller.text.trim())
                      : null,
                  child: Text(l10n.save),
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
          builder: (context, setState) {
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
              title: Text(l10n.exportAccount),
              content: TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Color(0xFF1F1F28)),
                decoration: InputDecoration(
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
                  onPressed: loading
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: loading ? null : submit,
                  child: Text(l10n.exportAccount),
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
