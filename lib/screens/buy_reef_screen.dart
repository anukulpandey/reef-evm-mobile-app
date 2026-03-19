import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/styles.dart';
import '../services/buy_reef_service.dart';
import '../utils/address_utils.dart';

class BuyReefScreen extends StatefulWidget {
  const BuyReefScreen({
    super.key,
    required this.walletAddress,
    required this.displayName,
  });

  final String walletAddress;
  final String displayName;

  @override
  State<BuyReefScreen> createState() => _BuyReefScreenState();
}

class _BuyReefScreenState extends State<BuyReefScreen> {
  static const double _minAmountUsd = 15;
  static const double _maxAmountUsd = 2000;

  final TextEditingController _amountController = TextEditingController(
    text: '100',
  );
  final BuyReefService _buyReefService = BuyReefService();

  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _startPurchase() async {
    final parsedAmount = double.tryParse(_amountController.text.trim());
    if (parsedAmount == null ||
        parsedAmount < _minAmountUsd ||
        parsedAmount > _maxAmountUsd) {
      setState(() {
        _errorText =
            'Amount must be between \$${_minAmountUsd.toInt()} and \$${_maxAmountUsd.toInt()}.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final buyUri = await _buyReefService.fetchAlchemyPayUri(
        walletAddress: widget.walletAddress,
        fiatAmountUsd: parsedAmount,
      );

      final launched = await launchUrl(
        buyUri,
        mode: LaunchMode.inAppBrowserView,
      );

      if (!launched && mounted) {
        setState(() {
          _errorText = 'Unable to open the buy flow right now.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles.greyColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B32C6),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Buy Reef',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_buildHeroCard(), const Gap(16), _buildFormCard()],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDF2FF), Color(0xFFF0E9FF)],
        ),
        border: Border.all(color: const Color(0xFFD9C8F2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Top up your Reef wallet',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB9359A),
                    height: 1.05,
                  ),
                ),
                Gap(14),
                Text(
                  'Buy REEF with card or bank transfer through the same Alchemy Pay flow used in Reef apps.',
                  style: TextStyle(
                    color: Color(0xFF4A466B),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFFEBCBFF), Color(0xFFF8F1FF)],
              ),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/reef.png',
                width: 44,
                height: 44,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4FF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD9C8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alchemy Pay',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF262141),
            ),
          ),
          const Gap(8),
          const Text(
            'Choose an amount in USD and continue with the selected wallet address.',
            style: TextStyle(
              color: Color(0xFF7A7599),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const Gap(20),
          _buildLabel('Amount (USD)'),
          const Gap(8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              color: Color(0xFF262141),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            decoration: _inputDecoration(hintText: '100', prefixText: '\$ '),
          ),
          const Gap(18),
          _buildLabel('Selected address'),
          const Gap(8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFD3C8EA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.displayName,
                  style: const TextStyle(
                    color: Color(0xFF262141),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(6),
                Text(
                  AddressUtils.shorten(widget.walletAddress, prefixLength: 6),
                  style: const TextStyle(
                    color: Color(0xFF7A7599),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Gap(14),
          const Text(
            'Supported purchase range: \$15 - \$2000',
            style: TextStyle(
              color: Color(0xFF8A84AA),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_errorText != null) ...[
            const Gap(14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFF9FA8)),
              ),
              child: Text(
                _errorText!,
                style: const TextStyle(
                  color: Color(0xFFD14B58),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Gap(22),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: Styles.buttonGradient,
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _startPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Purchase',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF8A84AA),
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      hintStyle: const TextStyle(
        color: Color(0xFFAAA3C4),
        fontWeight: FontWeight.w600,
      ),
      prefixStyle: const TextStyle(
        color: Color(0xFF262141),
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFD3C8EA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFD3C8EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFF8D39D0), width: 1.8),
      ),
    );
  }
}
