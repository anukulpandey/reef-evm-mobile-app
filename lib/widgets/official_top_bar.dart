import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/styles.dart';

Widget topBar(BuildContext context, String? selectedAddress, String? accountName) {
  return Container(
    color: Colors.transparent,
    child: Column(
      children: <Widget>[
        Gap(MediaQuery.of(context).padding.top + 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                // Navigate home
              },
              child: SvgPicture.asset(
                'assets/images/reef-logo-light.svg',
                semanticsLabel: "Reef Chain Logo",
                height: 40,
              ),
            ),
            if (selectedAddress != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _AccountPill(accountName ?? 'Account'),
                    const Gap(8.0),
                    _buildWalletConnectButton(),
                  ],
                ),
              ),
          ],
        ),
        const Gap(16),
      ],
    ),
  );
}

class _AccountPill extends StatelessWidget {
  final String title;
  const _AccountPill(this.title);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.wallet, color: Styles.textColor, size: 18),
      label: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          color: Styles.purpleColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.fade,
        maxLines: 1,
        softWrap: false,
      ),
      backgroundColor: Styles.primaryBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      onPressed: () {},
    );
  }
}

Widget _buildWalletConnectButton() {
  return Material(
    elevation: 4,
    borderRadius: BorderRadius.circular(22.0),
    child: InkWell(
      onTap: () {},
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Styles.whiteColor,
          borderRadius: BorderRadius.circular(22.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: SvgPicture.asset(
            'assets/images/walletconnect.svg',
            width: 20,
          ),
        ),
      ),
    ),
  );
}
