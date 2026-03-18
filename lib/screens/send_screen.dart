import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/config/dex_config.dart';
import '../core/theme/reef_theme_colors.dart';
import '../core/theme/styles.dart';
import '../l10n/app_localizations.dart';
import '../models/token.dart';
import '../models/transaction_preview.dart';
import '../providers/service_providers.dart';
import '../providers/wallet_provider.dart';
import '../utils/address_utils.dart';
import '../utils/address_validator.dart';
import '../utils/amount_utils.dart';
import '../widgets/blurable_content.dart';
import '../widgets/common/token_avatar.dart';
import '../widgets/send/send_amount_slider.dart';
import '../widgets/send/send_transaction_status_card.dart';
import 'transaction_confirmation_screen.dart';

enum SendFlowStatus {
  noAddress,
  noAmount,
  amountTooHigh,
  addressInvalid,
  ready,
  sending,
  sentToNetwork,
  error,
}

class SendScreen extends ConsumerStatefulWidget {
  final Token token;
  final String? prefilledAddress;

  const SendScreen({super.key, required this.token, this.prefilledAddress});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _recipientFocus = FocusNode();
  final FocusNode _amountFocus = FocusNode();

  bool _isRecipientEditing = false;
  bool _isAmountEditing = false;
  bool _isValidAddress = false;
  bool _isSubmitting = false;
  double _rating = 0;
  double _availableTokenBalance = 0;
  String? _txHash;
  String? _errorMessage;
  SendFlowStatus _status = SendFlowStatus.noAddress;

  ReefThemeColors get _colors => context.reefColors;
  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  bool get _isNativeToken {
    return widget.token.address == 'native';
  }

  double get _tokenBalance => _availableTokenBalance;

  double get _maxTransferAmount {
    final reserveForFee = _isNativeToken ? 3.0 : 0.0;
    return math.max(0, _tokenBalance - reserveForFee);
  }

  int get _maxFractionDigits {
    final decimals = widget.token.decimals;
    if (decimals <= 0) return 0;
    if (decimals > 18) return 18;
    return decimals;
  }

  @override
  void initState() {
    super.initState();
    _availableTokenBalance = AmountUtils.parseNumeric(widget.token.balance);
    _recipientController.text = widget.prefilledAddress?.trim() ?? '';
    _recipientFocus.addListener(() {
      if (!mounted) return;
      setState(() => _isRecipientEditing = _recipientFocus.hasFocus);
    });
    _amountFocus.addListener(() {
      if (!mounted) return;
      setState(() => _isAmountEditing = _amountFocus.hasFocus);
    });
    Future.microtask(() async {
      await _refreshLiveBalance();
      await _revalidate();
    });
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _recipientFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _revalidate() async {
    final address = _recipientController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = AmountUtils.parseNumeric(amountText);
    final hasAmountFormatIssue = _hasAmountFormatIssue(amountText);
    final validAddress = AddressValidator.isValidEvmAddress(address);

    SendFlowStatus next;
    if (address.isEmpty) {
      next = SendFlowStatus.noAddress;
    } else if (!validAddress) {
      next = SendFlowStatus.addressInvalid;
    } else if (amountText.isEmpty || amount <= 0 || hasAmountFormatIssue) {
      next = SendFlowStatus.noAmount;
    } else if (amount > _maxTransferAmount) {
      next = SendFlowStatus.amountTooHigh;
    } else {
      next = SendFlowStatus.ready;
    }

    final nextRating = _maxTransferAmount <= 0
        ? 0.0
        : (amount / _maxTransferAmount).clamp(0.0, 1.0);

    if (!mounted) return;
    setState(() {
      _isValidAddress = address.isNotEmpty && validAddress;
      _status = _isSubmitting ? SendFlowStatus.sending : next;
      _rating = nextRating;
    });
  }

  Future<void> _refreshLiveBalance() async {
    final activeAccount = ref.read(walletProvider).activeAccount;
    if (activeAccount == null) return;

    try {
      final web3Service = ref.read(web3ServiceProvider);
      final liveBalanceText = _isNativeToken
          ? await web3Service.getBalance(activeAccount.address)
          : await web3Service.getERC20Balance(
              activeAccount.address,
              widget.token.address,
              decimalsHint: widget.token.decimals,
            );
      final liveBalance = AmountUtils.parseNumeric(liveBalanceText);
      if (!mounted) return;
      setState(() {
        _availableTokenBalance = liveBalance;
      });
    } catch (error) {
      print(
        '[send][refresh_balance_error] token=${widget.token.symbol} error=$error',
      );
    }
  }

  String _sliderAmount(double rating) {
    final raw = _maxTransferAmount * rating;
    if (raw <= 0) return '';
    return AmountUtils.formatInputAmount(raw, decimals: 6);
  }

  bool _hasAmountFormatIssue(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    if (text == '.') return true;
    final dotCount = '.'.allMatches(text).length;
    if (dotCount > 1) return true;
    final match = RegExp(r'^\d+(\.\d+)?$').hasMatch(text);
    if (!match) return true;
    if (!text.contains('.')) return false;
    final fraction = text.split('.').last;
    return fraction.length > _maxFractionDigits;
  }

  String? _amountValidationMessage() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    if (text == '.') return 'Invalid amount format';

    final dotCount = '.'.allMatches(text).length;
    if (dotCount > 1) return 'Invalid amount format';

    final numeric = AmountUtils.parseNumeric(text, fallback: double.nan);
    if (numeric.isNaN) return 'Invalid amount format';

    if (text.contains('.')) {
      final fraction = text.split('.').last;
      if (fraction.length > _maxFractionDigits) {
        return 'Maximum $_maxFractionDigits decimal places allowed';
      }
    }

    if (numeric <= 0) return 'Amount must be greater than 0';
    if (numeric > _maxTransferAmount) return 'Amount exceeds available balance';
    return null;
  }

  List<TextInputFormatter> _amountInputFormatters() {
    return <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      TextInputFormatter.withFunction((oldValue, newValue) {
        final text = newValue.text;
        if (text.isEmpty) return newValue;

        if (text == '.') {
          return const TextEditingValue(
            text: '0.',
            selection: TextSelection.collapsed(offset: 2),
          );
        }

        final dotCount = '.'.allMatches(text).length;
        if (dotCount > 1) return oldValue;

        final regex = RegExp(r'^\d+(\.\d*)?$');
        if (!regex.hasMatch(text)) return oldValue;

        if (text.contains('.')) {
          final fraction = text.split('.').last;
          if (fraction.length > _maxFractionDigits) return oldValue;
        }

        return newValue;
      }),
    ];
  }

  InputDecoration _embeddedFieldDecoration({
    required String hintText,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 2,
    ),
    BoxConstraints? constraints,
  }) {
    return InputDecoration(
      isDense: true,
      filled: false,
      fillColor: Colors.transparent,
      constraints: constraints,
      contentPadding: contentPadding,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      hintText: hintText,
      hintStyle: TextStyle(color: _colors.textMuted),
    );
  }

  Future<void> _fillAddressFromClipboard() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = clipboard?.text?.trim() ?? '';
    if (raw.isEmpty) return;
    _recipientController.text = raw;
    await _revalidate();
  }

  Future<void> _scanAddressViaCamera() async {
    final scannerController = MobileScannerController();
    var didReturn = false;

    final scanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return SizedBox(
          height: 420,
          child: Stack(
            children: [
              MobileScanner(
                controller: scannerController,
                onDetect: (capture) async {
                  if (didReturn) return;
                  final raw = capture.barcodes.isNotEmpty
                      ? capture.barcodes.first.rawValue
                      : null;
                  if (raw == null || raw.trim().isEmpty) return;
                  didReturn = true;
                  await scannerController.stop();
                  if (context.mounted) {
                    Navigator.of(context).pop(raw.trim());
                  }
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () async {
                    await scannerController.stop();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );

    await scannerController.dispose();
    if (!mounted || scanned == null || scanned.trim().isEmpty) return;
    _recipientController.text = scanned.trim();
    await _revalidate();
  }

  Future<void> _openSelectAddressSheet() async {
    final walletService = ref.read(walletServiceProvider);
    final accounts = await walletService.getAccounts();
    if (!mounted || accounts.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.reefColors.pageBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final colors = context.reefColors;
        final maxHeight = MediaQuery.of(context).size.height * 0.72;
        return SafeArea(
          top: false,
          child: SizedBox(
            height: maxHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Text(
                    AppLocalizations.of(context).selectAccount,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: accounts.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        return FutureBuilder<String?>(
                          future: walletService.getAccountName(account),
                          builder: (context, snapshot) {
                            final label = (snapshot.data ?? '').trim();
                            final display = label.isEmpty
                                ? AddressUtils.shorten(account)
                                : label;
                            return ListTile(
                              onTap: () => Navigator.of(context).pop(account),
                              leading: Icon(
                                Icons.account_balance_wallet_rounded,
                                color: colors.accent,
                              ),
                              title: Text(
                                display,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                AddressUtils.shorten(account),
                                style: TextStyle(color: colors.textMuted),
                              ),
                            );
                          },
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                    ),
                  ),
                  const Gap(8),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null || selected.trim().isEmpty) return;
    _recipientController.text = selected.trim();
    await _revalidate();
  }

  Future<void> _onConfirmSend() async {
    if (_status != SendFlowStatus.ready || _isSubmitting) return;

    await _refreshLiveBalance();
    await _revalidate();
    if (!mounted || _status != SendFlowStatus.ready) {
      setState(() {
        _errorMessage = _amountValidationMessage();
      });
      return;
    }

    final to = _recipientController.text.trim();
    final amount = _amountController.text.trim();
    final walletState = ref.read(walletProvider);
    final from = walletState.activeAccount?.address;
    if (from == null || from.trim().isEmpty) {
      setState(() => _errorMessage = 'No active account selected');
      return;
    }

    final preview = await _buildSendPreview(
      fromAddress: from,
      recipientAddress: to,
      amountText: amount,
    );
    if (!mounted) return;

    final result = await Navigator.of(context).push<TransactionApprovalResult>(
      MaterialPageRoute(
        builder: (_) => TransactionConfirmationScreen(
          preview: preview,
          approveButtonText: 'Approve & Send',
          rejectButtonText: 'Reject',
          onApprove: () async {
            if (mounted) {
              setState(() {
                _isSubmitting = true;
                _status = SendFlowStatus.sending;
                _errorMessage = null;
              });
            }
            try {
              return await ref
                  .read(walletProvider.notifier)
                  .transferToken(token: widget.token, to: to, amount: amount);
            } finally {
              if (mounted) {
                setState(() => _isSubmitting = false);
              }
            }
          },
        ),
      ),
    );

    if (!mounted) return;
    if (result == null || !result.approved) {
      setState(() {
        _status = SendFlowStatus.ready;
        _errorMessage = null;
      });
      return;
    }

    if ((result.txHash ?? '').trim().isNotEmpty) {
      setState(() {
        _txHash = result.txHash;
        _status = SendFlowStatus.sentToNetwork;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _status = SendFlowStatus.error;
      _errorMessage = 'Transaction failed';
    });
    await _revalidate();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feedback = _buildFeedbackUI(context);

    return Scaffold(
      backgroundColor: _colors.pageBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _colors.pageBackground,
        foregroundColor: _colors.textPrimary,
        title: Text(
          l10n.sendToken,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: _colors.textPrimary,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child:
              feedback ??
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 10,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: _colors.cardBackground,
                    boxShadow: [
                      BoxShadow(
                        color: _isDarkTheme
                            ? Colors.black.withOpacity(0.24)
                            : const Color(0x22000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      ..._buildInputElements(),
                      const Gap(36),
                      SendAmountSlider(
                        value: _rating,
                        enabled: !_isSubmitting,
                        onChanged: (newRating) {
                          final amountText = _sliderAmount(newRating);
                          _amountController.text = amountText;
                          _amountController.selection = TextSelection.collapsed(
                            offset: _amountController.text.length,
                          );
                          setState(() => _rating = newRating);
                          _revalidate();
                        },
                      ),
                      const Gap(36),
                      _buildSendStatusButton(),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  List<Widget> _buildInputElements() {
    final l10n = AppLocalizations.of(context);
    final showBalance = ref.watch(
      walletProvider.select((state) => state.showBalance),
    );
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: _isRecipientEditing
              ? Border.all(color: _colors.accentStrong, width: 1.3)
              : Border.all(color: _colors.inputBorder.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (_isRecipientEditing)
              BoxShadow(
                blurRadius: 15,
                spreadRadius: -8,
                offset: Offset(0, 10),
                color: _colors.accentStrong.withOpacity(0.28),
              ),
          ],
          color: _isRecipientEditing
              ? _colors.inputFill
              : _colors.cardBackgroundSecondary,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: MaterialButton(
                elevation: 0,
                height: 48,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onPressed: _isSubmitting ? null : _openSelectAddressSheet,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: _isSubmitting
                      ? _colors.textMuted
                      : _colors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: TextFormField(
                focusNode: _recipientFocus,
                readOnly: _isSubmitting,
                controller: _recipientController,
                onChanged: (_) => _revalidate(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isSubmitting
                      ? _colors.textMuted
                      : _colors.textPrimary,
                ),
                decoration: _embeddedFieldDecoration(
                  hintText: l10n.recipientAddress,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: MaterialButton(
                elevation: 0,
                height: 48,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onPressed: _isSubmitting ? null : _scanAddressViaCamera,
                onLongPress: _isSubmitting ? null : _fillAddressFromClipboard,
                child: Icon(
                  Icons.qr_code_scanner_sharp,
                  color: _isSubmitting
                      ? _colors.textMuted
                      : _colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
      const Gap(10),
      if (_isValidAddress)
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Styles.greenColor,
                  size: 16,
                ),
                const Gap(5),
                Text(
                  AddressUtils.shorten(_recipientController.text.trim()),
                  style: TextStyle(color: _colors.textMuted, fontSize: 12),
                ),
              ],
            ),
            const Gap(10),
          ],
        ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: _isAmountEditing
              ? Border.all(color: _colors.accentStrong, width: 1.3)
              : Border.all(color: _colors.inputBorder.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (_isAmountEditing)
              BoxShadow(
                blurRadius: 15,
                spreadRadius: -8,
                offset: Offset(0, 10),
                color: _colors.accentStrong.withOpacity(0.28),
              ),
          ],
          color: _isAmountEditing
              ? _colors.inputFill
              : _colors.cardBackgroundSecondary,
        ),
        child: Row(
          children: [
            Row(
              children: [
                TokenAvatar(
                  size: 48,
                  iconUrl: widget.token.iconUrl,
                  fallbackSeed: widget.token.symbol,
                  resolveFallbackIcon: true,
                ),
                const Gap(13),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.token.symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: _isSubmitting
                            ? _colors.textMuted
                            : _colors.textPrimary,
                      ),
                    ),
                    BlurableContent(
                      showContent: showBalance,
                      child: Text(
                        '${AmountUtils.formatInputAmount(_tokenBalance)} ${widget.token.symbol.toUpperCase()}',
                        style: TextStyle(
                          color: _colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: TextFormField(
                focusNode: _amountFocus,
                readOnly: _isSubmitting,
                inputFormatters: _amountInputFormatters(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                textInputAction: TextInputAction.done,
                controller: _amountController,
                onChanged: (_) => _revalidate(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isSubmitting
                      ? _colors.textMuted
                      : _colors.textPrimary,
                ),
                decoration: _embeddedFieldDecoration(
                  hintText: '0.0',
                  constraints: const BoxConstraints(maxHeight: 32),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
      if (_amountValidationMessage() != null) ...[
        const Gap(8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _amountValidationMessage()!,
            style: const TextStyle(
              color: Styles.errorColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ];
  }

  Widget _buildSendStatusButton() {
    final l10n = AppLocalizations.of(context);
    final isReady = _status == SendFlowStatus.ready;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: _status != SendFlowStatus.sending
              ? ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    shadowColor: _colors.accentStrong.withOpacity(0.32),
                    elevation: 0,
                    backgroundColor: isReady
                        ? _colors.cardBackgroundSecondary
                        : Colors.transparent,
                    padding: const EdgeInsets.all(0),
                  ),
                  onPressed: _onConfirmSend,
                  child: Ink(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 22,
                    ),
                    decoration: BoxDecoration(
                      color: isReady
                          ? _colors.cardBackgroundSecondary
                          : _colors.cardBackgroundSecondary,
                      gradient: isReady ? Styles.buttonGradient : null,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Center(
                      child: Text(
                        _sendButtonLabel(l10n),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: !isReady
                              ? _colors.textMuted.withOpacity(0.72)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Text(l10n.transactionSubmitted),
                    const Gap(12),
                    LinearProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Styles.primaryAccentColor,
                      ),
                      backgroundColor: _colors.cardBackgroundSecondary,
                    ),
                  ],
                ),
        ),
        const Gap(8),
        if (_errorMessage != null && _errorMessage!.trim().isNotEmpty)
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _colors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  String _sendButtonLabel(AppLocalizations l10n) {
    switch (_status) {
      case SendFlowStatus.noAddress:
        return 'Missing destination';
      case SendFlowStatus.noAmount:
        return 'Insert amount';
      case SendFlowStatus.amountTooHigh:
        return 'Amount too high';
      case SendFlowStatus.addressInvalid:
        return l10n.invalidAddressOrAmount;
      case SendFlowStatus.sending:
        return 'Sending';
      case SendFlowStatus.ready:
        return 'Confirm Send';
      case SendFlowStatus.sentToNetwork:
        return 'Sent to network';
      case SendFlowStatus.error:
        return l10n.send;
    }
  }

  Widget? _buildFeedbackUI(BuildContext context) {
    final isSending = _status == SendFlowStatus.sending;
    final isSentToNetwork = _status == SendFlowStatus.sentToNetwork;
    if (!isSending && !isSentToNetwork) return null;

    return SendTransactionStatusCard(
      isSending: isSending,
      isSentToNetwork: isSentToNetwork,
      txHash: _txHash,
      onContinue: () => Navigator.of(context).pop(),
      onCopyHash: () async {
        final hash = _txHash?.trim();
        if (hash == null || hash.isEmpty) return;
        await Clipboard.setData(ClipboardData(text: hash));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction hash copied')),
        );
      },
    );
  }

  Future<TransactionPreview> _buildSendPreview({
    required String fromAddress,
    required String recipientAddress,
    required String amountText,
  }) async {
    final web3 = ref.read(web3ServiceProvider);
    final isNative = _isNativeToken;
    final chainId = await web3.getChainId();
    final gasPriceWei = await web3.getGasPriceWei();
    final amountRaw = web3.parseAmountToRaw(amountText, widget.token.decimals);
    final gasLimit = isNative
        ? await web3.estimateNativeTransferGasLimit(
            fromAddress: fromAddress,
            toAddress: recipientAddress,
            amountWei: amountRaw,
          )
        : web3.erc20TransferGasLimit;
    final feeWei = gasPriceWei * BigInt.from(gasLimit);

    final networkName = _networkNameForChainId(chainId);
    final fields = <TransactionPreviewField>[
      TransactionPreviewField(label: 'From', value: fromAddress),
      TransactionPreviewField(label: 'To', value: recipientAddress),
      TransactionPreviewField(
        label: 'Amount (raw)',
        value: amountRaw.toString(),
      ),
    ];

    if (!isNative) {
      fields.addAll(<TransactionPreviewField>[
        TransactionPreviewField(label: 'Token', value: widget.token.symbol),
        TransactionPreviewField(
          label: 'Decimals',
          value: '${widget.token.decimals}',
        ),
      ]);
    }

    return TransactionPreview(
      title: 'Send Transaction',
      methodName: isNative ? 'nativeTransfer' : 'transfer(address,uint256)',
      recipientAddress: recipientAddress,
      amountDisplay: '$amountText ${widget.token.symbol.toUpperCase()}',
      networkName: networkName,
      chainId: chainId,
      contractAddress: isNative ? null : widget.token.address,
      gasLimit: gasLimit,
      gasPriceWei: gasPriceWei,
      estimatedFeeDisplay: _formatFeeDisplay(feeWei),
      fields: fields,
      calldataHex: isNative ? null : '0xa9059cbb…',
    );
  }

  static String _networkNameForChainId(int chainId) {
    if (chainId == DexConfig.defaultChainId) return 'Reef';
    return switch (chainId) {
      1 => 'Ethereum',
      11155111 => 'Sepolia',
      _ => 'Chain $chainId',
    };
  }

  static String _formatFeeDisplay(BigInt feeWei) {
    final fee = feeWei.toDouble() / 1000000000000000000;
    return '${NumberFormat('0.########').format(fee)} REEF';
  }
}
