import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../core/theme/styles.dart';
import '../l10n/app_localizations.dart';
import '../models/account.dart';
import '../providers/wallet_provider.dart';
import '../utils/address_utils.dart';
import 'common/address_pattern_avatar.dart';
import 'common/square_checkbox.dart';

enum _ModalView { options, created, details }

class AddAccountModal extends ConsumerStatefulWidget {
  const AddAccountModal({super.key});

  @override
  ConsumerState<AddAccountModal> createState() => _AddAccountModalState();
}

class _AddAccountModalState extends ConsumerState<AddAccountModal> {
  _ModalView _view = _ModalView.options;
  bool _isCreating = false;
  bool _hasSavedPhrase = false;
  bool _biometricEnabled = false;
  String? _errorText;
  String? _detailsErrorText;
  Account? _createdAccount;
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _accountNameController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.9;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Styles.primaryBackgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _view == _ModalView.options
            ? _buildOptionsView(context)
            : (_view == _ModalView.created
                  ? _buildCreatedView(context)
                  : _buildDetailsView(context)),
      ),
    );
  }

  Widget _buildOptionsView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        const Gap(6),
        _buildHeader(title: l10n.addAccountTitle),
        const Gap(14),
        _buildOptionTile(
          title: l10n.createNew,
          icon: Icons.add_circle_outline,
          onTap: _isCreating ? null : _handleCreateNew,
        ),
        _buildOptionTile(
          title: l10n.importRecoveryPhrase,
          icon: Icons.restore,
          onTap: _isCreating ? null : () => _showImportPhraseDialog(context),
        ),
        _buildOptionTile(
          title: l10n.importPrivateKey,
          icon: Icons.vpn_key_rounded,
          onTap: _isCreating
              ? null
              : () => _showImportPrivateKeyDialog(context),
        ),
        if (_errorText != null) ...[
          const Gap(12),
          Text(
            _errorText!,
            style: const TextStyle(
              color: Styles.errorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (_isCreating) ...[const Gap(22), const CircularProgressIndicator()],
      ],
    );
  }

  Widget _buildCreatedView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = _createdAccount!;
    final mnemonic = account.mnemonic.trim();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(6),
          _buildHeader(title: l10n.createNew),
          const Gap(14),
          _buildAccountPreviewCard(
            context: context,
            l10n: l10n,
            account: account,
            displayName: l10n.noName,
          ),
          const Gap(18),
          Text(
            l10n.generatedRecoveryPhrase,
            style: TextStyle(
              color: Color(0xFF8790AD),
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.6,
            ),
          ),
          const Gap(12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Styles.whiteColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              mnemonic,
              style: const TextStyle(
                color: Styles.primaryAccentColorDark,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                height: 1.35,
              ),
            ),
          ),
          const Gap(12),
          InkWell(
            onTap: () => _copyMnemonicAndContinue(context, mnemonic),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.copy_rounded, size: 18, color: Color(0xFF8F93A8)),
                  Gap(8),
                  Text(
                    l10n.copyToClipboard,
                    style: TextStyle(
                      color: Styles.textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_rounded,
                color: Styles.primaryAccentColorDark,
              ),
              const Gap(10),
              Expanded(
                child: Text(
                  l10n.recoveryPhraseWarning,
                  style: TextStyle(
                    color: Color(0xFF6E6E75),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
          InkWell(
            onTap: () => setState(() => _hasSavedPhrase = !_hasSavedPhrase),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SquareCheckbox(
                  value: _hasSavedPhrase,
                  onChanged: (value) => setState(() => _hasSavedPhrase = value),
                  size: 24,
                  fillColor: Colors.white,
                  borderColor: const Color(0xFFC7C2D7),
                  checkColor: Styles.primaryAccentColorDark,
                  borderWidth: 1.6,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.savedRecoveryPhrase,
                      style: TextStyle(
                        color: Color(0xFF6E6E75),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(14),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _hasSavedPhrase
                    ? Styles.buttonGradient
                    : const LinearGradient(
                        colors: [Color(0xFFC5B8DF), Color(0xFFB8A9D5)],
                      ),
                borderRadius: BorderRadius.circular(40),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: _hasSavedPhrase
                    ? () => setState(() => _view = _ModalView.details)
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.nextStep,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Gap(14),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Gap(16),
        ],
      ),
    );
  }

  Widget _buildDetailsView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enteredName = _accountNameController.text.trim();
    final pass = _passwordController.text.trim();
    final repeatPass = _repeatPasswordController.text.trim();
    final passwordsMatch = pass.isNotEmpty && pass == repeatPass;
    final canAdd = enteredName.isNotEmpty && passwordsMatch;
    final account = _createdAccount!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(6),
          _buildHeader(title: l10n.createNew),
          const Gap(14),
          _buildAccountPreviewCard(
            context: context,
            l10n: l10n,
            account: account,
            displayName: enteredName.isEmpty ? l10n.noName : enteredName,
          ),
          const Gap(16),
          Text(
            l10n.descriptiveAccountName,
            style: TextStyle(
              color: Color(0xFF8790AD),
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.6,
            ),
          ),
          const Gap(8),
          _buildInputField(controller: _accountNameController, hintText: ''),
          const Gap(10),
          InkWell(
            onTap: () => setState(() => _biometricEnabled = !_biometricEnabled),
            child: Row(
              children: [
                SquareCheckbox(
                  value: _biometricEnabled,
                  onChanged: (value) =>
                      setState(() => _biometricEnabled = value),
                  size: 24,
                  fillColor: Colors.white,
                  borderColor: const Color(0xFFC7C2D7),
                  checkColor: Styles.primaryAccentColorDark,
                  borderWidth: 1.6,
                ),
                Text(
                  l10n.enableBiometricAuthentication,
                  style: TextStyle(
                    color: Color(0xFF6E6E75),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Text(
            l10n.passwordForReefApp,
            style: TextStyle(
              color: Color(0xFF8790AD),
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.6,
            ),
          ),
          const Gap(8),
          _buildInputField(
            controller: _passwordController,
            obscureText: true,
            hintText: '',
          ),
          const Gap(12),
          Text(
            l10n.repeatPasswordForVerification,
            style: TextStyle(
              color: Color(0xFF8790AD),
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.6,
            ),
          ),
          const Gap(8),
          _buildInputField(
            controller: _repeatPasswordController,
            obscureText: true,
            hintText: '',
          ),
          if (_detailsErrorText != null) ...[
            const Gap(8),
            Text(
              _detailsErrorText!,
              style: const TextStyle(
                color: Styles.errorColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const Gap(22),
          Row(
            children: [
              SizedBox(
                width: 74,
                height: 74,
                child: ElevatedButton(
                  onPressed: () => setState(() => _view = _ModalView.created),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD3D0DB),
                    elevation: 0,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Styles.textColor,
                    size: 30,
                  ),
                ),
              ),
              const Gap(10),
              Expanded(
                child: SizedBox(
                  height: 74,
                  child: ElevatedButton(
                    onPressed: canAdd
                        ? () async {
                            final enteredName = _accountNameController.text
                                .trim();
                            if (enteredName.isEmpty) {
                              setState(() {
                                _detailsErrorText = 'Account name is required.';
                              });
                              return;
                            }

                            final saved = await ref
                                .read(walletProvider.notifier)
                                .saveCreatedAccount(
                                  draftAccount: account,
                                  name: enteredName,
                                );
                            if (!saved) {
                              if (!mounted) return;
                              final providerError = ref
                                  .read(walletProvider)
                                  .error;
                              setState(() {
                                _detailsErrorText =
                                    providerError ??
                                    'Failed to save account. Please try again.';
                              });
                              return;
                            }
                            setState(() => _detailsErrorText = null);
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAdd
                          ? Styles.secondaryAccentColor
                          : const Color(0xFFD3D0DB),
                      disabledBackgroundColor: const Color(0xFFD3D0DB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    child: Text(
                      l10n.addAccount,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
        ],
      ),
    );
  }

  Widget _buildAccountPreviewCard({
    required BuildContext context,
    required AppLocalizations l10n,
    required Account account,
    required String displayName,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Styles.whiteColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          AddressPatternAvatar(
            seed: account.address,
            size: 92,
            innerSize: 70,
            dotSize: 12,
            dotCount: 25,
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Styles.textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const Gap(4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l10n.addressLabel}: ${AddressUtils.shorten(account.address, prefixLength: 4, suffixLength: 3)}',
                        style: const TextStyle(
                          color: Color(0xFF6E6E75),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: Color(0xFF7C7B83),
                      ),
                      onPressed: () => _copyText(
                        context,
                        account.address,
                        l10n.addressCopied,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      cursorColor: Styles.secondaryAccentColor,
      style: const TextStyle(
        color: Styles.textColor,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      onChanged: (_) {
        setState(() {
          _detailsErrorText = null;
        });
      },
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Styles.textLightColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE1DFE7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE1DFE7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Styles.secondaryAccentColor),
        ),
      ),
    );
  }

  Widget _buildHeader({required String title}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Styles.primaryAccentColorDark,
          child: Image.asset('assets/images/reef.png', width: 24, height: 24),
        ),
        const Gap(12),
        Text(
          title,
          style: const TextStyle(
            color: Styles.textColor,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white,
          child: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF5E5D66)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required String title,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: Styles.primaryAccentColorDark),
      title: Text(
        title,
        style: const TextStyle(
          color: Styles.textColor,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
    );
  }

  Future<void> _handleCreateNew() async {
    setState(() {
      _isCreating = true;
      _errorText = null;
    });
    final account = await ref.read(walletProvider.notifier).createAccount();
    if (!mounted) return;
    setState(() {
      _isCreating = false;
      if (account == null) {
        _errorText = AppLocalizations.of(context).failedToCreateAccount;
        return;
      }
      _createdAccount = account;
      _view = _ModalView.created;
    });
  }

  void _showImportPhraseDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _showImportDialog(
      context: context,
      title: l10n.importFromPhrase,
      hintText: l10n.enterMnemonicPhrase,
      maxLines: 3,
      onImport: (value, accountName) => ref
          .read(walletProvider.notifier)
          .importMnemonic(value, accountName: accountName),
    );
  }

  void _showImportPrivateKeyDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _showImportDialog(
      context: context,
      title: l10n.importFromPrivateKey,
      hintText: l10n.enterPrivateKey,
      maxLines: 2,
      onImport: (value, accountName) => ref
          .read(walletProvider.notifier)
          .importPrivateKey(value, accountName: accountName),
    );
  }

  void _showImportDialog({
    required BuildContext context,
    required String title,
    required String hintText,
    required int maxLines,
    required Future<void> Function(String value, String accountName) onImport,
  }) {
    final l10n = AppLocalizations.of(context);
    final valueController = TextEditingController();
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        String? dialogErrorText;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (localContext, setState) {
            Future<void> submit() async {
              final value = valueController.text.trim();
              final accountName = nameController.text.trim();
              if (value.isEmpty || accountName.isEmpty) {
                setState(() {
                  dialogErrorText =
                      'Account name and import value are required.';
                });
                return;
              }

              setState(() {
                isSubmitting = true;
                dialogErrorText = null;
              });
              await onImport(value, accountName);
              if (!mounted || !dialogContext.mounted) return;

              final providerError = ref.read(walletProvider).error?.trim();
              if (providerError != null && providerError.isNotEmpty) {
                setState(() {
                  isSubmitting = false;
                  dialogErrorText = providerError;
                });
                return;
              }

              Navigator.pop(dialogContext);
              Navigator.of(context).pop();
            }

            return AlertDialog(
              backgroundColor: Styles.whiteColor,
              title: Text(
                title,
                style: const TextStyle(color: Styles.primaryColor),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    maxLines: 1,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: Styles.textColor),
                    decoration: InputDecoration(
                      labelText: l10n.accountNameLabel,
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Styles.purpleColor),
                      ),
                    ),
                  ),
                  const Gap(10),
                  TextField(
                    controller: valueController,
                    maxLines: maxLines,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: Styles.textColor),
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Styles.purpleColor),
                      ),
                    ),
                  ),
                  if (dialogErrorText != null) ...[
                    const Gap(10),
                    Text(
                      dialogErrorText!,
                      style: const TextStyle(
                        color: Styles.errorColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.importLabel),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      valueController.dispose();
      nameController.dispose();
    });
  }

  Future<void> _copyText(
    BuildContext context,
    String value,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _copyMnemonicAndContinue(
    BuildContext context,
    String mnemonic,
  ) async {
    await _copyText(
      context,
      mnemonic,
      AppLocalizations.of(context).recoveryPhraseCopied,
    );
    if (!mounted) return;
    setState(() {
      _hasSavedPhrase = true;
      _view = _ModalView.details;
      _detailsErrorText = null;
    });
  }
}
