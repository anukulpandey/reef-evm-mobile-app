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
  final initialName =
      (normalizedCurrent == '<No Name>' || normalizedCurrent == l10n.noName)
      ? ''
      : normalizedCurrent;

  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _RenameAccountDialog(l10n: l10n, initialName: initialName),
  );
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

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ExportPasswordDialog(l10n: l10n, authService: authService),
  );
  return result ?? false;
}

class _RenameAccountDialog extends StatefulWidget {
  final AppLocalizations l10n;
  final String initialName;

  const _RenameAccountDialog({required this.l10n, required this.initialName});

  @override
  State<_RenameAccountDialog> createState() => _RenameAccountDialogState();
}

class _RenameAccountDialogState extends State<_RenameAccountDialog> {
  late final TextEditingController _controller;

  bool get _canSave => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSave) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final palette = _dialogPalette(context);
    return AlertDialog(
      backgroundColor: palette.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        widget.l10n.renameAccountTitle,
        style: TextStyle(
          color: palette.title,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
      ),
      content: TextField(
        controller: _controller,
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
          labelText: widget.l10n.accountNameLabel,
          hintText: widget.l10n.noName,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          style: _dialogActionButtonStyle(),
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.l10n.cancel,
            style: TextStyle(color: palette.actionText),
          ),
        ),
        TextButton(
          style: _dialogActionButtonStyle(),
          onPressed: _canSave ? _submit : null,
          child: Text(
            widget.l10n.save,
            style: TextStyle(
              color: _canSave
                  ? palette.actionText
                  : palette.actionText.withOpacity(0.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExportPasswordDialog extends StatefulWidget {
  final AppLocalizations l10n;
  final AuthService authService;

  const _ExportPasswordDialog({required this.l10n, required this.authService});

  @override
  State<_ExportPasswordDialog> createState() => _ExportPasswordDialogState();
}

class _ExportPasswordDialogState extends State<_ExportPasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _invalidPassword = false;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      if (!mounted) return;
      setState(() => _invalidPassword = true);
      return;
    }

    setState(() => _loading = true);
    final isValid = await widget.authService.verifyAppPassword(input);
    if (!mounted) return;

    if (isValid) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _loading = false;
      _invalidPassword = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = _dialogPalette(context);
    return AlertDialog(
      backgroundColor: palette.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        widget.l10n.exportAccount,
        style: TextStyle(
          color: palette.title,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
      ),
      content: TextField(
        controller: _controller,
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
          labelText: widget.l10n.enterAppPassword,
          errorText: _invalidPassword ? widget.l10n.invalidPassword : null,
        ),
        onChanged: (_) {
          if (!_invalidPassword) return;
          setState(() => _invalidPassword = false);
        },
        onSubmitted: (_) => _loading ? null : _submit(),
      ),
      actions: [
        TextButton(
          style: _dialogActionButtonStyle(),
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: Text(
            widget.l10n.cancel,
            style: TextStyle(
              color: _loading
                  ? palette.actionText.withOpacity(0.45)
                  : palette.actionText,
            ),
          ),
        ),
        TextButton(
          style: _dialogActionButtonStyle(),
          onPressed: _loading ? null : _submit,
          child: Text(
            widget.l10n.exportAccount,
            style: TextStyle(
              color: _loading
                  ? palette.actionText.withOpacity(0.45)
                  : palette.actionText,
            ),
          ),
        ),
      ],
    );
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
