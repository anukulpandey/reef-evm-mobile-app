import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/styles.dart';
import '../../services/buy_reef_service.dart';
import '../../screens/buy_reef_screen.dart';

Future<void> showBuyReefOptionsSheet({
  required BuildContext context,
  required String walletAddress,
  required String displayName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _BuyReefOptionsSheet(
      walletAddress: walletAddress,
      displayName: displayName,
    ),
  );
}

class _BuyReefOptionsSheet extends StatelessWidget {
  const _BuyReefOptionsSheet({
    required this.walletAddress,
    required this.displayName,
  });

  final String walletAddress;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F0FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 54,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4C8EB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Gap(18),
            const Text(
              'Choose how you want to buy REEF',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF262141),
              ),
            ),
            const Gap(10),
            const Text(
              'Use the same on-ramp options available in Reef apps.',
              style: TextStyle(
                color: Color(0xFF7A7599),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(20),
            _BuyReefOptionCard(
              chipLabel: 'LetsExchange',
              title: 'Crypto to Reef',
              description:
                  'Swap supported tokens to REEF using the LetsExchange widget.',
              icon: Icons.swap_horiz_rounded,
              onTap: () async {
                Navigator.of(context).pop();
                final launched = await launchUrl(
                  BuyReefService().buildLetsExchangeUri(),
                  mode: LaunchMode.inAppBrowserView,
                );
                if (!launched && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to open LetsExchange right now.'),
                    ),
                  );
                }
              },
            ),
            const Gap(14),
            _BuyReefOptionCard(
              chipLabel: 'Alchemy Pay',
              title: 'Fiat to Reef',
              description:
                  'Buy REEF with card or bank transfer via Alchemy Pay.',
              icon: Icons.credit_card_rounded,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BuyReefScreen(
                      walletAddress: walletAddress,
                      displayName: displayName,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BuyReefOptionCard extends StatelessWidget {
  const _BuyReefOptionCard({
    required this.chipLabel,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String chipLabel;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF1E9FF)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFD8C8EF)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: Styles.buttonGradient,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6E8FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        chipLabel,
                        style: const TextStyle(
                          color: Color(0xFF9A41CE),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Gap(10),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF262141),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF767194),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF9C95BB),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
