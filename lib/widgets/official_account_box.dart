import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/styles.dart';
import 'blurable_content.dart';
import '../utils/address_utils.dart';
import 'common/address_pattern_avatar.dart';

enum AccountMenuAction {
  selectAccount,
  copyEvmAddress,
  renameAccount,
  delete,
  exportMnemonic,
  exportPrivateKey,
}

class AccountBox extends StatelessWidget {
  final String address;
  final String name;
  final String balance;
  final bool selected;
  final VoidCallback onSelected;
  final ValueChanged<AccountMenuAction>? onMenuAction;
  final bool lightTheme;
  final bool showBalance;
  final String selectedText;
  final String addressPrefix;
  final String selectAccountText;
  final String copyEvmAddressText;
  final String renameAccountText;
  final String deleteText;
  final String exportMnemonicText;
  final String exportPrivateKeyText;

  const AccountBox({
    Key? key,
    required this.address,
    required this.name,
    required this.balance,
    required this.selected,
    required this.onSelected,
    this.onMenuAction,
    this.lightTheme = false,
    this.showBalance = true,
    this.selectedText = 'Selected',
    this.addressPrefix = 'Address',
    this.selectAccountText = 'Select Account',
    this.copyEvmAddressText = 'Copy Address',
    this.renameAccountText = 'Rename Account',
    this.deleteText = 'Delete',
    this.exportMnemonicText = 'Export Mnemonic',
    this.exportPrivateKeyText = 'Export Private Key',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gradientColors = lightTheme
        ? const [Color(0xFFE7DFF8), Color(0xFFC8DCFA)]
        : const [Color(0xFF2D1357), Color(0xFF28124A)];

    return InkWell(
      onTap: onSelected,
      child: PhysicalModel(
        borderRadius: BorderRadius.circular(15),
        elevation: 4,
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final avatarSize = compact ? 68.0 : 76.0;
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(0, 0.2),
                  end: const Alignment(0.1, 1.3),
                  colors: gradientColors,
                ),
                border: Border.all(
                  color: const Color(0xFFB9359A),
                  width: selected ? 3 : 2,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Stack(
                children: [
                  if (selected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.only(
                          left: 12,
                          bottom: 5,
                          right: 10,
                          top: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFB9359A),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(15),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          selectedText,
                          style: TextStyle(
                            color: Styles.whiteColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: selected ? 24 : 18,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AddressPatternAvatar(
                          seed: address,
                          size: avatarSize,
                          innerSize: compact ? 54 : 60,
                          dotSize: compact ? 9 : 10,
                          dotCount: 25,
                        ),
                        const Gap(10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2, right: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: compact ? 16 : 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Gap(8),
                                    Flexible(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Image.asset(
                                                "assets/images/reef.png",
                                                width: compact ? 14 : 16,
                                                height: compact ? 14 : 16,
                                              ),
                                              const Gap(4),
                                              BlurableContent(
                                                showContent: showBalance,
                                                child: Text(
                                                  '$balance REEF',
                                                  overflow: TextOverflow.fade,
                                                  softWrap: false,
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: compact ? 12 : 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Gap(6),
                                Container(
                                  color: Colors.purpleAccent.shade100.withAlpha(
                                    44,
                                  ),
                                  height: 1,
                                ),
                                const Gap(6),
                                Text.rich(
                                  TextSpan(
                                    text: addressPrefix,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFA8A1C3),
                                    ),
                                    children: <TextSpan>[
                                      TextSpan(
                                        text:
                                            ' ${AddressUtils.shorten(address, prefixLength: 4)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuButton<AccountMenuAction>(
                          color: Colors.white,
                          icon: Icon(
                            Icons.more_vert,
                            color: Colors.grey.shade100,
                            size: 24,
                          ),
                          enableFeedback: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onSelected: (value) => onMenuAction?.call(value),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: AccountMenuAction.selectAccount,
                              child: Text(
                                selectAccountText,
                                style: TextStyle(
                                  color: Color(0xFF1F1F28),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: AccountMenuAction.copyEvmAddress,
                              child: Text(
                                copyEvmAddressText,
                                style: TextStyle(
                                  color: Color(0xFF1F1F28),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: AccountMenuAction.renameAccount,
                              child: Text(
                                renameAccountText,
                                style: TextStyle(
                                  color: Color(0xFF1F1F28),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: AccountMenuAction.delete,
                              child: Text(
                                deleteText,
                                style: TextStyle(
                                  color: Color(0xFF1F1F28),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: AccountMenuAction.exportMnemonic,
                              child: Text(
                                exportMnemonicText,
                                style: TextStyle(
                                  color: Color(0xFF1F1F28),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: AccountMenuAction.exportPrivateKey,
                              child: Text(
                                exportPrivateKeyText,
                                style: TextStyle(
                                  color: Color(0xFF1F1F28),
                                  fontWeight: FontWeight.w700,
                                ),
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
          },
        ),
      ),
    );
  }
}
