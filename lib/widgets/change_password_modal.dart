import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return Center(
      child: SingleChildScrollView(
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF3E0070),
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
                            color: Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            color: Colors.black87,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(14),
                  if (_hasPassword) ...[
                    _label(l10n.enterAppPassword),
                    const Gap(8),
                    _PasswordInput(controller: _currentPasswordController),
                    const Gap(12),
                  ],
                  _label(l10n.newPassword.toUpperCase()),
                  const Gap(8),
                  _PasswordInput(
                    controller: _newPasswordController,
                    showErrorBorder: _newPasswordError,
                  ),
                  if (_newPasswordError) ...[
                    const Gap(8),
                    _errorRow('Password is too short'),
                  ],
                  if (_newPassword.isNotEmpty && !_newPasswordError) ...[
                    const Gap(16),
                    _label(l10n.repeatPasswordForVerification),
                    const Gap(8),
                    _PasswordInput(
                      controller: _confirmPasswordController,
                      showErrorBorder: _confirmPasswordError,
                    ),
                    if (_confirmPasswordError) ...[
                      const Gap(8),
                      _errorRow(l10n.passwordMismatch),
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
                        shadowColor: const Color(0x559D6CFF),
                        elevation: 5,
                        disabledBackgroundColor: const Color(0xFF9D6CFF),
                        backgroundColor: Styles.secondaryAccentColor,
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

  static Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: Styles.textLightColor,
      ),
    );
  }

  static Widget _errorRow(String message) {
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
            style: const TextStyle(color: Color(0xFFB9C1D8), fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _PasswordInput extends StatelessWidget {
  const _PasswordInput({
    required this.controller,
    this.showErrorBorder = false,
  });

  final TextEditingController controller;
  final bool showErrorBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: showErrorBorder ? Styles.errorColor : const Color(0x20000000),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        style: const TextStyle(
          fontSize: 16,
          color: Styles.textColor,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration.collapsed(hintText: ''),
      ),
    );
  }
}
