import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sliver_tools/sliver_tools.dart';
import '../providers/wallet_provider.dart';
import '../core/theme/styles.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/official_components.dart';
import '../widgets/add_account_modal.dart';
import 'package:flutter/services.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      body: Container(
        color: Styles.primaryBackgroundColor,
        child: Column(
          children: [
            Material(
              elevation: 3,
              shadowColor: Colors.black45,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/reef-header.png"),
                    fit: BoxFit.cover,
                    alignment: Alignment(-0.82, 1.0),
                  ),
                ),
                child: topBar(
                  context,
                  walletState.activeAccount?.address,
                  'Account 1',
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    delegate: _BalanceHeaderDelegate(
                      balance: walletState.balance,
                      showBalance: walletState.showBalance,
                      onToggleVisibility: () => ref.read(walletProvider.notifier).toggleBalanceVisibility(),
                    ),
                  ),
                  SliverPinnedHeader(
                    child: _buildNavSection(),
                  ),
                  if (walletState.activeAccount == null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                      sliver: SliverToBoxAdapter(
                        child: _buildNoAccountState(context),
                      ),
                    )
                  else
                    _buildMainContent(walletState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, left: 12, right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Styles.primaryBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: const HSLColor.fromAHSL(1, 256.3636363636, 0.379310344828, 0.843137254902).toColor(),
            offset: const Offset(10, 10),
            blurRadius: 20,
            spreadRadius: -5,
          ),
          BoxShadow(
            color: const HSLColor.fromAHSL(1, 256.3636363636, 0.379310344828, 1).toColor(),
            offset: const Offset(-10, -10),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, "Tokens"),
            _buildNavItem(1, "NFTs"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label) {
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: isSelected ? Styles.whiteColor : Colors.transparent,
          boxShadow: isSelected
              ? [const BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2.5))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isSelected ? Styles.textColor : Styles.textColor.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildNoAccountState(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.account_balance_wallet_outlined, size: 60, color: Styles.textLightColor),
        const Gap(16),
        const Text(
          "No account currently available, create or import an account to view your assets.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Styles.textLightColor, fontSize: 14),
        ),
        const Gap(24),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(80),
            gradient: Styles.buttonGradient,
            boxShadow: [
              BoxShadow(
                color: Styles.secondaryAccentColorDark.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddAccountModal(),
              );
            },
            child: const Text('Add Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(WalletState state) {
    if (_currentIndex == 0) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18.0),
                child: _buildTokenCard("Ethereum", "Native", state.balance, null),
              );
            },
            childCount: 1,
          ),
        ),
      );
    } else {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40.0),
            child: Text("No NFTs found", style: TextStyle(color: Styles.textLightColor)),
          ),
        ),
      );
    }
  }

  Widget _buildTokenCard(String name, String symbol, String balance, String? iconUrl) {
    return ViewBoxContainer(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Image(image: AssetImage("assets/images/reef.png"), width: 32, height: 32),
                ),
                const Gap(15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.poppins(color: Styles.textColor, fontSize: 18, fontWeight: FontWeight.w700)),
                    const Text("Price: \$0.00", style: TextStyle(color: Styles.textLightColor, fontSize: 14)),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GradientText(
                      '\$$balance',
                      gradient: textGradient(),
                      style: GoogleFonts.poppins(color: Styles.textColor, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    Text('$balance $symbol', style: const TextStyle(color: Styles.textColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const Gap(15),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(80),
                      gradient: Styles.buttonGradient,
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send, color: Colors.white, size: 16),
                      label: const Text("SEND", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {},
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String balance;
  final bool showBalance;
  final VoidCallback onToggleVisibility;

  _BalanceHeaderDelegate({required this.balance, required this.showBalance, required this.onToggleVisibility});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    double opacity = ((shrinkOffset - 180) / 180).abs();
    if (opacity < 0) opacity = 0;
    if (opacity > 1) opacity = 1;

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Balance", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Styles.primaryColor)),
                IconButton(
                  icon: Icon(showBalance ? Icons.remove_red_eye : Icons.visibility_off, color: Styles.textLightColor),
                  onPressed: onToggleVisibility,
                ),
              ],
            ),
            Center(
              child: GradientText(
                showBalance ? '\$$balance' : '******',
                gradient: textGradient(),
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Styles.textColor,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 180;
  @override
  double get minExtent => 0;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
