import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/styles.dart';

enum AccountMenuAction { selectAccount, copyEvmAddress, delete, exportAccount }

class AccountBox extends StatelessWidget {
  final String address;
  final String name;
  final String balance;
  final bool selected;
  final VoidCallback onSelected;
  final ValueChanged<AccountMenuAction>? onMenuAction;
  final bool lightTheme;
  final String selectedText;
  final String addressPrefix;
  final String selectAccountText;
  final String copyEvmAddressText;
  final String deleteText;
  final String exportAccountText;

  const AccountBox({
    Key? key,
    required this.address,
    required this.name,
    required this.balance,
    required this.selected,
    required this.onSelected,
    this.onMenuAction,
    this.lightTheme = false,
    this.selectedText = 'Selected',
    this.addressPrefix = 'Address',
    this.selectAccountText = 'Select Account',
    this.copyEvmAddressText = 'Copy EVM Address',
    this.deleteText = 'Delete',
    this.exportAccountText = 'Export Account',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gradientColors = lightTheme
        ? const [Color(0xFFE7DFF8), Color(0xFFC8DCFA)]
        : const [Color(0xFF2D1357), Color(0xFF28124A)];

    return InkWell(
      onTap: onSelected,
      child: PhysicalModel(
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final reservedRight = selected
                ? (compact ? 152.0 : 172.0)
                : (compact ? 44.0 : 52.0);
            final maxBalanceWidth = selected
                ? (compact ? 66.0 : 90.0)
                : (compact ? 86.0 : 116.0);
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                border: Border.all(color: const Color(0xFFB9359A), width: 2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Stack(
                children: [
                  if (selected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.only(
                          left: 14,
                          bottom: 8,
                          right: 14,
                          top: 4,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFB9359A),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Text(
                          selectedText,
                          style: TextStyle(
                            color: Styles.whiteColor,
                            fontWeight: FontWeight.w700,
                            fontSize: Styles.fsCaption,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      selected ? 34 : 18,
                      reservedRight,
                      18,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAddressAvatar(address),
                        const Gap(12),
                        Expanded(
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
                                        fontSize: compact
                                            ? Styles.fsBodyStrong
                                            : Styles.fsCardTitle,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Gap(8),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: maxBalanceWidth,
                                    ),
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
                                              width: 13,
                                              height: 13,
                                            ),
                                            const Gap(4),
                                            Text(
                                              selected
                                                  ? balance
                                                  : '$balance REEF',
                                              overflow: TextOverflow.fade,
                                              softWrap: false,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: compact
                                                    ? Styles.fsCaption
                                                    : Styles.fsBodyStrong,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(8),
                              Container(
                                color: const Color(0x99644E8A),
                                height: 1,
                              ),
                              const Gap(10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$addressPrefix ${_shortAddress(address)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: Styles.fsBody,
                                        color: Color(0xFFA8A1C3),
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
                  ),
                  Positioned(
                    right: 4,
                    top: selected ? 66 : 14,
                    child: PopupMenuButton<AccountMenuAction>(
                      color: Colors.white,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
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
                          value: AccountMenuAction.exportAccount,
                          child: Text(
                            exportAccountText,
                            style: TextStyle(
                              color: Color(0xFF1F1F28),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

  Widget _buildAddressAvatar(String seed) {
    final colors = <Color>[
      const Color(0xFF2D8CFF),
      const Color(0xFF6CCB2F),
      const Color(0xFFD873C0),
      const Color(0xFF8D7BFF),
      const Color(0xFF6EC6DE),
      const Color(0xFFE58DA0),
    ];
    final bytes = seed.codeUnits;
    return Container(
      width: 76,
      height: 76,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF0F2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: 60,
          height: 60,
          child: Wrap(
            spacing: 2,
            runSpacing: 2,
            children: List.generate(25, (index) {
              final v = bytes[(index * 7) % bytes.length];
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[v % colors.length],
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  String _shortAddress(String value) {
    if (value.length < 10) return value;
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }
}
