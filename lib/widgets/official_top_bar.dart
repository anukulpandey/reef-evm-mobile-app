import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/styles.dart';
import '../l10n/app_localizations.dart';

Widget topBar(
  BuildContext context,
  String? selectedAddress,
  String? accountName,
) {
  final l10n = AppLocalizations.of(context);
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
                child: _AccountPill(accountName ?? l10n.noName),
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.42,
      ),
      child: ActionChip(
        avatar: const Icon(Icons.wallet, color: Styles.textColor, size: 18),
        label: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: Styles.purpleColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          softWrap: false,
        ),
        backgroundColor: Styles.primaryBackgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onPressed: () {},
      ),
    );
  }
}
