import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/reef_theme_colors.dart';
import '../core/theme/styles.dart';
import '../l10n/app_localizations.dart';
import '../providers/service_providers.dart';

Future<void> showChangePasswordModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ChangePasswordModal(),
  );
}

class _ChangePasswordModal extends ConsumerStatefulWidget {
  const _ChangePasswordModal();

  @override
  ConsumerState<_ChangePasswordModal> createState() =>
      _ChangePasswordModalState();
}

class _ChangePasswordModalState extends ConsumerState<_ChangePasswordModal> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _hasPassword = false;
  bool _newPasswordError = false;
  bool _confirmPasswordError = false;
  bool _saving = false;

  String _newPassword = '';
  String _confirmPassword = '';

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() {
      if (_newPassword == _newPasswordController.text) return;
      setState(() {
        _newPassword = _newPasswordController.text;
        _newPasswordError = _newPassword.isNotEmpty && _newPassword.length < 6;
        _confirmPasswordError =
            _confirmPassword.isNotEmpty && _newPassword != _confirmPassword;
      });
    });
    _confirmPasswordController.addListener(() {
      if (_confirmPassword == _confirmPasswordController.text) return;
      setState(() {
        _confirmPassword = _confirmPasswordController.text;
        _confirmPasswordError =
            _confirmPassword.isNotEmpty && _newPassword != _confirmPassword;
      });
    });
    _loadPasswordState();
  }

  Future<void> _loadPasswordState() async {
    final hasPassword = await ref.read(authServiceProvider).hasAppPassword();
    if (!mounted) return;
    setState(() => _hasPassword = hasPassword);
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving &&
      _newPassword.isNotEmpty &&
      !_newPasswordError &&
      _confirmPassword.isNotEmpty &&
      !_confirmPasswordError;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final auth = ref.read(authServiceProvider);
      if (_hasPassword) {
        final isValid = await auth.verifyAppPassword(
          _currentPasswordController.text.trim(),
        );
        if (!isValid) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).invalidPassword),
            ),
          );
          return;
        }
      }

      await auth.setAppPassword(_newPassword.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).passwordSaved)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.reefColors;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final modalBackground = isDarkTheme
        ? const Color(0xFF3A006A)
        : const Color(0xFFECE7F6);
    final titleColor = isDarkTheme
        ? colors.textPrimary
        : const Color(0xFF313A52);
    return Center(
      child: SingleChildScrollView(
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: modalBackground,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Image(
                        image: AssetImage('assets/images/reef.png'),
                        width: 31,
                        height: 31,
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          l10n.changePassword,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDarkTheme
                                ? colors.cardBackground
                                : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            CupertinoIcons.xmark,
                            color: colors.textSecondary,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(14),
                  if (_hasPassword) ...[
                    _label(context, l10n.enterAppPassword),
                    const Gap(8),
                    _PasswordInput(
                      controller: _currentPasswordController,
                      hintText: l10n.enterAppPassword,
                    ),
                    const Gap(12),
                  ],
                  _label(context, l10n.newPassword.toUpperCase()),
                  const Gap(8),
                  _PasswordInput(
                    controller: _newPasswordController,
                    showErrorBorder: _newPasswordError,
                    hintText: l10n.newPassword,
                  ),
                  if (_newPasswordError) ...[
                    const Gap(8),
                    _errorRow(context, 'Password is too short'),
                  ],
                  if (_newPassword.isNotEmpty && !_newPasswordError) ...[
                    const Gap(16),
                    _label(context, l10n.repeatPasswordForVerification),
                    const Gap(8),
                    _PasswordInput(
                      controller: _confirmPasswordController,
                      showErrorBorder: _confirmPasswordError,
                      hintText: l10n.repeatPasswordForVerification,
                    ),
                    if (_confirmPasswordError) ...[
                      const Gap(8),
                      _errorRow(context, l10n.passwordMismatch),
                    ],
                  ],
                  const Gap(24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        shadowColor: colors.accentStrong.withOpacity(0.35),
                        elevation: 5,
                        disabledBackgroundColor: colors.accentStrong
                            .withOpacity(0.42),
                        backgroundColor: colors.accentStrong,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        l10n.changePassword,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _label(BuildContext context, String text) {
    final colors = context.reefColors;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: isDarkTheme ? colors.textMuted : const Color(0xFF8F95B2),
        letterSpacing: 0.2,
      ),
    );
  }

  static Widget _errorRow(BuildContext context, String message) {
    final colors = context.reefColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          color: Styles.errorColor,
          size: 16,
        ),
        const Gap(8),
        Flexible(
          child: Text(
            message,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _PasswordInput extends StatefulWidget {
  const _PasswordInput({
    required this.controller,
    this.showErrorBorder = false,
    this.hintText = 'Enter password',
  });

  final TextEditingController controller;
  final bool showErrorBorder;
  final String hintText;

  @override
  State<_PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<_PasswordInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkTheme ? colors.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.showErrorBorder
              ? colors.danger
              : (isDarkTheme ? colors.inputBorder : const Color(0xFFCDC3E4)),
          width: 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscure,
        enableSuggestions: false,
        autocorrect: false,
        cursorColor: colors.accentStrong,
        style: TextStyle(
          fontSize: 18,
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          fillColor: Colors.transparent,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: colors.textMuted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          suffixIcon: IconButton(
            splashRadius: 18,
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
              color: colors.textMuted,
              size: 18,
            ),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 34),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }
}
