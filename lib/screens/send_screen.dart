import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/styles.dart';
import '../l10n/app_localizations.dart';
import '../models/token.dart';
import '../providers/service_providers.dart';
import '../providers/wallet_provider.dart';
import '../utils/token_icon_resolver.dart';

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
  String? _txHash;
  String? _errorMessage;
  SendFlowStatus _status = SendFlowStatus.noAddress;

  bool get _isNativeToken {
    final symbol = widget.token.symbol.toUpperCase();
    return widget.token.address == 'native' ||
        symbol == 'REEF' ||
        symbol == 'WREEF';
  }

  double get _tokenBalance =>
      double.tryParse(widget.token.balance.replaceAll(',', '')) ?? 0;

  double get _maxTransferAmount {
    final reserveForFee = _isNativeToken ? 3.0 : 0.0;
    return math.max(0, _tokenBalance - reserveForFee);
  }

  @override
  void initState() {
    super.initState();
    _recipientController.text = widget.prefilledAddress?.trim() ?? '';
    _recipientFocus.addListener(() {
      if (!mounted) return;
      setState(() => _isRecipientEditing = _recipientFocus.hasFocus);
    });
    _amountFocus.addListener(() {
      if (!mounted) return;
      setState(() => _isAmountEditing = _amountFocus.hasFocus);
    });
    _revalidate();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _recipientFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  bool _isValidEvmAddress(String value) {
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value);
  }

  Future<void> _revalidate() async {
    final address = _recipientController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0;
    final validAddress = _isValidEvmAddress(address);

    SendFlowStatus next;
    if (address.isEmpty) {
      next = SendFlowStatus.noAddress;
    } else if (!validAddress) {
      next = SendFlowStatus.addressInvalid;
    } else if (amountText.isEmpty || amount <= 0) {
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

  String _sliderAmount(double rating) {
    final raw = _maxTransferAmount * rating;
    if (raw <= 0) return '';
    return raw
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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
      backgroundColor: Styles.primaryBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).selectAccount,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Styles.textColor,
                  ),
                ),
                const Gap(10),
                for (final account in accounts)
                  FutureBuilder<String?>(
                    future: walletService.getAccountName(account),
                    builder: (context, snapshot) {
                      final label = (snapshot.data ?? '').trim();
                      final display = label.isEmpty
                          ? _shortAddress(account)
                          : label;
                      return ListTile(
                        onTap: () => Navigator.of(context).pop(account),
                        leading: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Styles.primaryAccentColor,
                        ),
                        title: Text(
                          display,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Styles.textColor,
                          ),
                        ),
                        subtitle: Text(
                          _shortAddress(account),
                          style: const TextStyle(color: Styles.textLightColor),
                        ),
                      );
                    },
                  ),
                const Gap(8),
              ],
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
    final l10n = AppLocalizations.of(context);
    if (_status != SendFlowStatus.ready || _isSubmitting) return;

    final to = _recipientController.text.trim();
    final amount = _amountController.text.trim();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _status = SendFlowStatus.sending;
    });

    try {
      final hash = await ref
          .read(walletProvider.notifier)
          .transferToken(token: widget.token, to: to, amount: amount);
      if (!mounted) return;
      setState(() {
        _txHash = hash;
        _isSubmitting = false;
        _status = SendFlowStatus.sentToNetwork;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = '${l10n.transferFailed}: $e';
        _status = SendFlowStatus.error;
      });
      await _revalidate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feedback = _buildFeedbackUI(context);

    return Scaffold(
      backgroundColor: Styles.primaryBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Styles.primaryBackgroundColor,
        foregroundColor: Styles.textColor,
        title: Text(
          l10n.sendToken,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20),
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
                    color: Styles.primaryBackgroundColor,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
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
                      ..._buildSliderWidgets(),
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
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: _isRecipientEditing
              ? Border.all(color: const Color(0xffa328ab))
              : Border.all(color: const Color(0x00d7d1e9)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (_isRecipientEditing)
              const BoxShadow(
                blurRadius: 15,
                spreadRadius: -8,
                offset: Offset(0, 10),
                color: Color(0x40a328ab),
              ),
          ],
          color: _isRecipientEditing
              ? const Color(0xffeeebf6)
              : const Color(0xffE7E2F2),
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
                      ? Styles.textLightColor
                      : Styles.textColor,
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
                      ? Styles.textLightColor
                      : Styles.textColor,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  border: InputBorder.none,
                  hintText: l10n.recipientAddress,
                  hintStyle: const TextStyle(color: Styles.textLightColor),
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
                child: const Icon(
                  Icons.qr_code_scanner_sharp,
                  color: Styles.textColor,
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
                  _shortAddress(_recipientController.text.trim()),
                  style: const TextStyle(
                    color: Styles.textLightColor,
                    fontSize: 12,
                  ),
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
              ? Border.all(color: const Color(0xffa328ab))
              : Border.all(color: const Color(0x00d7d1e9)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (_isAmountEditing)
              const BoxShadow(
                blurRadius: 15,
                spreadRadius: -8,
                offset: Offset(0, 10),
                color: Color(0x40a328ab),
              ),
          ],
          color: _isAmountEditing
              ? const Color(0xffeeebf6)
              : const Color(0xffE7E2F2),
        ),
        child: Row(
          children: [
            Row(
              children: [
                _buildTokenIcon(widget.token, 48),
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
                            ? Styles.textLightColor
                            : Styles.darkBackgroundColor,
                      ),
                    ),
                    Text(
                      '${_formatAmount(_tokenBalance)} ${widget.token.symbol.toUpperCase()}',
                      style: const TextStyle(
                        color: Styles.textLightColor,
                        fontSize: 12,
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
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                ],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                controller: _amountController,
                onChanged: (_) => _revalidate(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isSubmitting
                      ? Styles.textLightColor
                      : Styles.textColor,
                ),
                decoration: const InputDecoration(
                  constraints: BoxConstraints(maxHeight: 32),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  hintText: '0.0',
                  hintStyle: TextStyle(color: Styles.textLightColor),
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildSliderWidgets() {
    return [
      SliderTheme(
        data: SliderThemeData(
          showValueIndicator: ShowValueIndicator.never,
          overlayShape: SliderComponentShape.noOverlay,
          valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
          valueIndicatorColor: Styles.secondaryAccentColorDark,
          thumbColor: Styles.secondaryAccentColorDark,
          inactiveTickMarkColor: const Color(0xffc0b8dc),
          trackShape: const _GradientRectSliderTrackShape(
            gradient: Styles.buttonGradient,
            darkenInactive: true,
          ),
          activeTickMarkColor: const Color(0xffffffff),
          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
          thumbShape: const _ThumbShape(),
        ),
        child: Slider(
          value: _rating,
          onChanged: _isSubmitting
              ? null
              : (newRating) {
                  final amountText = _sliderAmount(newRating);
                  _amountController.text = amountText;
                  _amountController.selection = TextSelection.collapsed(
                    offset: _amountController.text.length,
                  );
                  setState(() => _rating = newRating);
                  _revalidate();
                },
          inactiveColor: Colors.white24,
          divisions: 100,
          label: '${(_rating * 100).toInt()}%',
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0%',
              style: TextStyle(
                color: Styles.textLightColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            Text(
              '50%',
              style: TextStyle(
                color: Styles.textLightColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            Text(
              '100%',
              style: TextStyle(
                color: Styles.textLightColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
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
                    shadowColor: const Color(0x559d6cff),
                    elevation: 0,
                    backgroundColor: isReady
                        ? const Color(0xffe6e2f1)
                        : Colors.transparent,
                    padding: const EdgeInsets.all(0),
                  ),
                  onPressed: _isSubmitting ? null : _onConfirmSend,
                  child: Ink(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 22,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffe6e2f1),
                      gradient: isReady ? Styles.buttonGradient : null,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Center(
                      child: Text(
                        _sendButtonLabel(l10n),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: !isReady
                              ? const Color(0x65898e9c)
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
                      backgroundColor: Styles.greyColor,
                    ),
                  ],
                ),
        ),
        const Gap(8),
        if (_errorMessage != null && _errorMessage!.trim().isNotEmpty)
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Styles.errorColor,
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
    if (_status != SendFlowStatus.sentToNetwork || _txHash == null) return null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: Styles.primaryAccentColor),
        ),
        child: Stepper(
          currentStep: 1,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    shadowColor: const Color(0x559d6cff),
                    elevation: 5,
                    backgroundColor: Styles.primaryAccentColor,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 32,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Styles.whiteColor,
                    ),
                  ),
                ),
              ),
            );
          },
          steps: [
            Step(
              isActive: true,
              state: StepState.complete,
              title: const Text('Sending transaction'),
              content: Text(
                'Sending transaction to network...',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ),
            Step(
              isActive: true,
              state: StepState.complete,
              title: const Text('Sent to network'),
              content: SelectableText(
                _txHash!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenIcon(Token token, double size) {
    final iconUrl =
        token.iconUrl ??
        TokenIconResolver.resolveTokenIconUrl(
          address: token.address,
          symbol: token.symbol,
        );

    final imageProvider = _resolveImageProvider(iconUrl);
    final svgData = _resolveSvgData(iconUrl);

    if (svgData != null) {
      return ClipOval(
        child: SvgPicture.string(
          svgData,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    if (imageProvider != null) {
      return ClipOval(
        child: Image(
          image: imageProvider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.circle, color: Styles.primaryColor, size: 14),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: const Icon(Icons.circle, color: Styles.primaryColor, size: 14),
    );
  }

  static ImageProvider? _resolveImageProvider(String? iconUrl) {
    if (iconUrl == null || iconUrl.trim().isEmpty) return null;
    final normalized = iconUrl.trim();
    final dataUri = _tryParseDataUri(normalized);
    if (dataUri != null) {
      if (dataUri.mimeType.contains('svg')) return null;
      final bytes = dataUri.contentAsBytes();
      if (bytes.isEmpty) return null;
      return MemoryImage(bytes);
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    return NetworkImage(normalized);
  }

  static String? _resolveSvgData(String? iconUrl) {
    if (iconUrl == null || iconUrl.trim().isEmpty) return null;
    final uriData = _tryParseDataUri(iconUrl.trim());
    if (uriData == null || !uriData.mimeType.contains('svg')) return null;
    final bytes = uriData.contentAsBytes();
    if (bytes.isEmpty) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  static UriData? _tryParseDataUri(String value) {
    if (!value.startsWith('data:')) return null;
    try {
      return UriData.parse(value);
    } catch (_) {
      return null;
    }
  }

  static String _shortAddress(String value) {
    if (value.length < 10) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
  }

  static String _formatAmount(double value) {
    return value
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _GradientRectSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  final LinearGradient gradient;
  final bool darkenInactive;

  const _GradientRectSliderTrackShape({
    this.gradient = const LinearGradient(
      colors: [Colors.lightBlue, Colors.blue],
    ),
    this.darkenInactive = true,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activeTrackColorTween = ColorTween(
      begin: sliderTheme.disabledActiveTrackColor,
      end: sliderTheme.activeTrackColor,
    );
    final inactiveTrackColorTween = darkenInactive
        ? ColorTween(
            begin: sliderTheme.disabledInactiveTrackColor,
            end: sliderTheme.inactiveTrackColor,
          )
        : activeTrackColorTween;

    final activePaint = Paint()
      ..shader = gradient.createShader(trackRect)
      ..color =
          activeTrackColorTween.evaluate(enableAnimation) ?? Colors.transparent;
    final inactivePaint = Paint()
      ..shader = gradient.createShader(trackRect)
      ..color =
          inactiveTrackColorTween.evaluate(enableAnimation) ??
          Colors.transparent;

    final leftTrackPaint = textDirection == TextDirection.ltr
        ? activePaint
        : inactivePaint;
    final rightTrackPaint = textDirection == TextDirection.ltr
        ? inactivePaint
        : activePaint;

    final trackRadius = Radius.circular(trackRect.height / 2);
    final activeTrackRadius = Radius.circular(trackRect.height / 2 + 1);

    context.canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        trackRect.left,
        trackRect.top,
        thumbCenter.dx,
        trackRect.bottom,
        topLeft: textDirection == TextDirection.ltr
            ? activeTrackRadius
            : trackRadius,
        bottomLeft: textDirection == TextDirection.ltr
            ? activeTrackRadius
            : trackRadius,
      ),
      leftTrackPaint,
    );

    context.canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        thumbCenter.dx,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
        topRight: textDirection == TextDirection.rtl
            ? activeTrackRadius
            : trackRadius,
        bottomRight: textDirection == TextDirection.rtl
            ? activeTrackRadius
            : trackRadius,
      ),
      rightTrackPaint,
    );
  }
}

class _ThumbShape extends RoundSliderThumbShape {
  final _indicatorShape = const PaddleSliderValueIndicatorShape();

  const _ThumbShape();

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    super.paint(
      context,
      center,
      activationAnimation: activationAnimation,
      enableAnimation: enableAnimation,
      sliderTheme: sliderTheme,
      value: value,
      textScaleFactor: textScaleFactor,
      sizeWithOverflow: sizeWithOverflow,
      isDiscrete: isDiscrete,
      labelPainter: labelPainter,
      parentBox: parentBox,
      textDirection: textDirection,
    );

    _indicatorShape.paint(
      context,
      center,
      activationAnimation: const AlwaysStoppedAnimation(1),
      enableAnimation: enableAnimation,
      labelPainter: labelPainter,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      value: value,
      textScaleFactor: 0.8,
      sizeWithOverflow: sizeWithOverflow,
      isDiscrete: isDiscrete,
      textDirection: textDirection,
    );
  }
}
