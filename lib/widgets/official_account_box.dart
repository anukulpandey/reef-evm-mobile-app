import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/styles.dart';

class AccountBox extends StatelessWidget {
  final String address;
  final String name;
  final String balance;
  final bool selected;
  final VoidCallback onSelected;
  final bool lightTheme;

  const AccountBox({
    Key? key,
    required this.address,
    required this.name,
    required this.balance,
    required this.selected,
    required this.onSelected,
    this.lightTheme = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var gradientColors = lightTheme
        ? [
            const Color.fromARGB(255, 231, 223, 248),
            const Color.fromARGB(194, 200, 220, 250),
          ]
        : [
            const Color.fromARGB(198, 37, 19, 79),
            const Color.fromARGB(53, 110, 27, 117),
          ];

    return InkWell(
      onTap: onSelected,
      child: PhysicalModel(
        borderRadius: BorderRadius.circular(15),
        elevation: 4,
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(0, 0.2),
              end: const Alignment(0.1, 1.3),
              colors: gradientColors,
            ),
            border: Border.all(
              color: Styles.purpleColor,
              width: selected ? 3 : 0,
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
                    padding: const EdgeInsets.only(left: 12, bottom: 5, right: 10, top: 2),
                    decoration: const BoxDecoration(
                      color: Styles.purpleColor,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(15),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Selected',
                      style: TextStyle(
                        color: Styles.whiteColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24.0),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black12,
                      ),
                      child: const Icon(Icons.person, color: Colors.white54, size: 40),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Row(
                                children: [
                                  Image.asset("assets/images/reef.png", width: 18, height: 18),
                                  const Gap(4),
                                  Text(
                                    '$balance REEF',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Gap(6),
                          Container(color: Colors.purpleAccent.shade100.withAlpha(44), height: 1),
                          const Gap(6),
                          Text(
                            'Address: ${address.substring(0, 6)}...${address.substring(address.length - 4)}',
                            style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
