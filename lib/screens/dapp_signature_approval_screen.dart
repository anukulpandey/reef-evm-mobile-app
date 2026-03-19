import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/reef_theme_colors.dart';
import '../providers/service_providers.dart';

class DappSignatureApprovalScreen extends ConsumerStatefulWidget {
  const DappSignatureApprovalScreen({
    super.key,
    required this.origin,
    required this.method,
    required this.payloadTitle,
    required this.payloadPreview,
    this.approveButtonText = 'Approve & Sign',
  });

  final String origin;
  final String method;
  final String payloadTitle;
  final String payloadPreview;
  final String approveButtonText;

  @override
  ConsumerState<DappSignatureApprovalScreen> createState() =>
      _DappSignatureApprovalScreenState();
}

class _DappSignatureApprovalScreenState
    extends ConsumerState<DappSignatureApprovalScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _hasPassword = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadPasswordState();
  }

  Future<void> _loadPasswordState() async {
    final hasPassword = await ref.read(authServiceProvider).hasAppPassword();
    if (!mounted) return;
    setState(() => _hasPassword = hasPassword);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    if (_isSubmitting) return;

    final auth = ref.read(authServiceProvider);
    var password = _passwordController.text.trim();

    if (!_hasPassword) {
      final createdPassword = await _showSetPasswordDialog();
      if (!mounted) return;
      if (createdPassword == null || createdPassword.trim().isEmpty) {
        setState(() {
          _errorText = 'You must set an app password before signing.';
        });
        return;
      }
      password = createdPassword.trim();
      _passwordController.text = password;
      setState(() {
        _hasPassword = true;
        _errorText = null;
      });
    }

    if (password.isEmpty) {
      _passwordFocusNode.requestFocus();
      setState(() {
        _errorText = 'Enter wallet password to continue.';
      });
      return;
    }

    final passwordOk = await auth.verifyAppPassword(password);
    if (!mounted) return;
    if (!passwordOk) {
      setState(() {
        _errorText = 'Invalid wallet password. Please try again.';
      });
      return;
    }

    final biometricOk = await auth.authenticateForTransaction(
      localizedReason: 'Authenticate to sign this request',
    );
    if (!mounted) return;
    if (!biometricOk) {
      setState(() {
        _errorText = 'Biometric authentication failed. Please try again.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<String?> _showSetPasswordDialog() async {
    final auth = ref.read(authServiceProvider);
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          final colors = dialogContext.reefColors;
          String? dialogError;
          bool saving = false;

          return StatefulBuilder(
            builder: (context, setState) {
              Future<void> submit() async {
                final newPassword = newPasswordController.text.trim();
                final confirmPassword = confirmPasswordController.text.trim();

                if (newPassword.isEmpty || confirmPassword.isEmpty) {
                  setState(() {
                    dialogError = 'Enter and confirm your app password.';
                  });
                  return;
                }
                if (newPassword.length < 6) {
                  setState(() {
                    dialogError = 'Password must be at least 6 characters.';
                  });
                  return;
                }
                if (newPassword != confirmPassword) {
                  setState(() {
                    dialogError = 'Passwords do not match.';
                  });
                  return;
                }

                setState(() {
                  saving = true;
                  dialogError = null;
                });
                try {
                  await auth.setAppPassword(newPassword);
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(newPassword);
                } catch (_) {
                  if (!dialogContext.mounted) return;
                  setState(() {
                    saving = false;
                    dialogError = 'Unable to save password. Please try again.';
                  });
                }
              }

              return AlertDialog(
                backgroundColor: colors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  'Set App Password',
                  style: GoogleFonts.poppins(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You must set an app password before signing.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      const Gap(12),
                      _dialogPasswordField(
                        controller: newPasswordController,
                        label: 'New Password',
                        hint: 'Enter new password',
                        colors: colors,
                      ),
                      const Gap(10),
                      _dialogPasswordField(
                        controller: confirmPasswordController,
                        label: 'Confirm Password',
                        hint: 'Confirm password',
                        colors: colors,
                      ),
                      if (dialogError != null) ...[
                        const Gap(10),
                        Text(
                          dialogError!,
                          style: TextStyle(
                            color: colors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: saving ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accentStrong,
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Set Password'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final screenBackground = isDarkTheme
        ? const Color(0xFF1E0B3B)
        : const Color(0xFFE6E1EF);
    final appBarBackground = isDarkTheme
        ? const Color(0xFF5A23A5)
        : Colors.deepPurple.shade700;

    return Scaffold(
      backgroundColor: screenBackground,
      appBar: AppBar(
        backgroundColor: appBarBackground,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          'Sign Request',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 21,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Signature request',
                            style: GoogleFonts.spaceGrotesk(
                              color: colors.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Gap(8),
                          Text(
                            'Review what the dapp wants you to sign before approving.',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 17,
                              height: 1.35,
                            ),
                          ),
                          const Gap(16),
                          _detailTile(
                            label: 'Origin',
                            value: widget.origin,
                            colors: colors,
                          ),
                          const Gap(10),
                          _detailTile(
                            label: 'Method',
                            value: widget.method,
                            colors: colors,
                          ),
                          const Gap(10),
                          _detailTile(
                            label: widget.payloadTitle,
                            value: widget.payloadPreview,
                            colors: colors,
                            monospace: true,
                          ),
                        ],
                      ),
                    ),
                    const Gap(20),
                  ],
                ),
              ),
            ),
            _buildStickyActionArea(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyActionArea(ReefThemeColors colors) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        decoration: BoxDecoration(
          color: colors.appBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 22,
              offset: const Offset(0, -8),
              spreadRadius: -18,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sectionCard(
                colors: colors,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet password',
                      style: GoogleFonts.spaceGrotesk(
                        color: colors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      _hasPassword
                          ? 'Password and biometric approval are required to sign.'
                          : 'Set your app password before approving this signature.',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 17,
                        height: 1.35,
                      ),
                    ),
                    const Gap(14),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.cardBackgroundSecondary,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: colors.inputBorder,
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: _obscurePassword,
                        enableSuggestions: false,
                        autocorrect: false,
                        style: GoogleFonts.spaceGrotesk(
                          color: colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter wallet password',
                          hintStyle: TextStyle(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: colors.textMuted,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          if (_errorText == null) return;
                          setState(() {
                            _errorText = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorText != null) ...[
                const Gap(12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.danger.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.danger.withOpacity(0.55)),
                  ),
                  child: Text(
                    _errorText!,
                    style: TextStyle(
                      color: colors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(62),
                        side: BorderSide(color: colors.inputBorder, width: 1.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Reject',
                        style: GoogleFonts.spaceGrotesk(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [colors.accent, colors.accentStrong],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accentStrong.withOpacity(0.28),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _approve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(62),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                widget.approveButtonText,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
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
  }

  static Widget _sectionCard({
    required ReefThemeColors colors,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.borderColor),
      ),
      child: child,
    );
  }

  static Widget _detailTile({
    required String label,
    required String value,
    required ReefThemeColors colors,
    bool monospace = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const Gap(8),
          Text(
            value,
            style:
                (monospace
                        ? GoogleFonts.robotoMono()
                        : GoogleFonts.spaceGrotesk())
                    .copyWith(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
          ),
        ],
      ),
    );
  }

  static Widget _dialogPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ReefThemeColors colors,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: colors.textMuted),
        filled: true,
        fillColor: colors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.accentStrong),
        ),
      ),
    );
  }
}
