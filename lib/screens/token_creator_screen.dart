import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/theme/reef_theme_colors.dart';
import '../models/created_token_entry.dart';
import '../models/token_creation_result.dart';
import '../models/token_creator_request.dart';
import '../models/transaction_preview.dart';
import '../providers/pool_provider.dart';
import '../providers/service_providers.dart';
import '../providers/wallet_provider.dart';
import '../services/explorer_service.dart';
import '../utils/address_utils.dart';
import '../utils/amount_utils.dart';
import '../widgets/common/token_avatar.dart';
import '../widgets/pools/create_pool_sheet.dart';
import 'transaction_confirmation_screen.dart';

class TokenCreatorScreen extends ConsumerStatefulWidget {
  const TokenCreatorScreen({super.key});

  @override
  ConsumerState<TokenCreatorScreen> createState() => _TokenCreatorScreenState();
}

class _TokenCreatorScreenState extends ConsumerState<TokenCreatorScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _symbolController = TextEditingController();
  final TextEditingController _supplyController = TextEditingController();
  final TextEditingController _iconUrlController = TextEditingController();

  bool _burnable = true;
  bool _mintable = true;
  bool _isCreating = false;
  int _selectedTabIndex = 0;
  _CreatorResultState? _resultState;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleFieldChanged);
    _symbolController.addListener(_handleFieldChanged);
    _supplyController.addListener(_handleFieldChanged);
    _iconUrlController.addListener(_handleFieldChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleFieldChanged);
    _symbolController.removeListener(_handleFieldChanged);
    _supplyController.removeListener(_handleFieldChanged);
    _iconUrlController.removeListener(_handleFieldChanged);
    _nameController.dispose();
    _symbolController.dispose();
    _supplyController.dispose();
    _iconUrlController.dispose();
    super.dispose();
  }

  void _handleFieldChanged() {
    if (!mounted) return;
    setState(() {});
  }

  TokenCreatorRequest get _request => TokenCreatorRequest(
    name: _nameController.text,
    symbol: _symbolController.text,
    initialSupply: _supplyController.text,
    burnable: _burnable,
    mintable: _mintable,
    iconUrl: _iconUrlController.text,
  );

  String? get _validationText {
    final service = ref.read(tokenCreatorServiceProvider);
    return service.validate(_request);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final walletState = ref.watch(walletProvider);
    final screenBackground = Theme.of(context).brightness == Brightness.dark
        ? colors.deepBackground
        : colors.appBackground;

    return Scaffold(
      backgroundColor: screenBackground,
      appBar: AppBar(
        backgroundColor: screenBackground,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text(
          'Create Token',
          style: GoogleFonts.spaceGrotesk(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _resultState == null
              ? _buildTabbedCreatorView(context, colors, walletState)
              : _buildResultView(context, colors, walletState),
        ),
      ),
    );
  }

  Widget _buildTabbedCreatorView(
    BuildContext context,
    ReefThemeColors colors,
    WalletState walletState,
  ) {
    return SingleChildScrollView(
      key: ValueKey<String>('creator_tabs_$_selectedTabIndex'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCreatorTabs(colors),
          const Gap(18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _selectedTabIndex == 0
                ? _buildCreateTab(colors, walletState)
                : _buildMyTokensTab(colors, walletState),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateTab(ReefThemeColors colors, WalletState walletState) {
    final validationText = _validationText;
    final hasActiveAccount = walletState.activeAccount != null;

    return Column(
      key: const ValueKey<String>('creator_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIntro(colors),
        const Gap(20),
        _sectionCard(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading(
                title: 'Token details',
                subtitle:
                    'Use the same creator flow from Reefswap to deploy a token on Reef.',
                colors: colors,
              ),
              const Gap(18),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildInputField(
                      controller: _nameController,
                      label: 'Token name',
                      hint: 'My Token',
                      colors: colors,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _buildInputField(
                      controller: _symbolController,
                      label: 'Token symbol',
                      hint: 'MYTKN',
                      colors: colors,
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                ],
              ),
              const Gap(14),
              _buildInputField(
                controller: _supplyController,
                label: 'Initial supply',
                hint: '0',
                colors: colors,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
              const Gap(14),
              _buildInputField(
                controller: _iconUrlController,
                label: 'Token logo URL',
                hint: 'https://… (optional)',
                colors: colors,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
              ),
              const Gap(16),
              Row(
                children: [
                  Expanded(
                    child: _buildBooleanToggle(
                      label: 'Burnable',
                      value: _burnable,
                      colors: colors,
                      onChanged: (next) {
                        setState(() => _burnable = next);
                      },
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _buildBooleanToggle(
                      label: 'Mintable',
                      value: _mintable,
                      colors: colors,
                      onChanged: (next) {
                        setState(() => _mintable = next);
                      },
                    ),
                  ),
                ],
              ),
              if (validationText != null) ...[
                const Gap(14),
                _inlineNotice(
                  colors: colors,
                  icon: Icons.info_outline_rounded,
                  text: validationText,
                ),
              ] else if (!hasActiveAccount) ...[
                const Gap(14),
                _inlineNotice(
                  colors: colors,
                  icon: Icons.wallet_outlined,
                  text: 'Select or create an account before deploying a token.',
                ),
              ],
            ],
          ),
        ),
        const Gap(18),
        _buildPreviewCard(colors),
        const Gap(18),
        SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.accent, colors.accentStrong],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: colors.accentStrong.withOpacity(0.24),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                  spreadRadius: -12,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed:
                  (!hasActiveAccount || validationText != null || _isCreating)
                  ? null
                  : _openConfirmSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create Token',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorTabs(ReefThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _creatorTabButton(
              label: 'Create',
              icon: Icons.auto_awesome_rounded,
              selected: _selectedTabIndex == 0,
              colors: colors,
              onTap: () => setState(() => _selectedTabIndex = 0),
            ),
          ),
          const Gap(8),
          Expanded(
            child: _creatorTabButton(
              label: 'My Tokens',
              icon: Icons.token_rounded,
              selected: _selectedTabIndex == 1,
              colors: colors,
              onTap: () => setState(() => _selectedTabIndex = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _creatorTabButton({
    required String label,
    required IconData icon,
    required bool selected,
    required ReefThemeColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? LinearGradient(colors: [colors.accent, colors.accentStrong])
              : null,
          color: selected ? null : colors.cardBackgroundSecondary,
          border: Border.all(
            color: selected
                ? Colors.transparent
                : colors.borderColor.withOpacity(0.8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : colors.textSecondary,
              size: 18,
            ),
            const Gap(8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTokensTab(ReefThemeColors colors, WalletState walletState) {
    final activeAddress = walletState.activeAccount?.address;
    if (activeAddress == null || activeAddress.trim().isEmpty) {
      return _sectionCard(
        key: const ValueKey<String>('creator_my_tokens_empty_account'),
        colors: colors,
        child: _emptyMyTokensState(
          colors: colors,
          title: 'No active account',
          subtitle:
              'Select an account to see the tokens created by this wallet.',
          icon: Icons.wallet_outlined,
        ),
      );
    }

    final registry = ref.read(createdTokenRegistryServiceProvider);
    return FutureBuilder<List<CreatedTokenEntry>>(
      key: ValueKey<String>('creator_my_tokens_$activeAddress'),
      future: registry.getEntriesCreatedBy(activeAddress),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _sectionCard(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeading(
                  title: 'My tokens',
                  subtitle: 'Loading your locally created token history…',
                  colors: colors,
                ),
                const Gap(18),
                Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: colors.accentStrong,
                  ),
                ),
              ],
            ),
          );
        }

        final entries = snapshot.data ?? const <CreatedTokenEntry>[];
        if (entries.isEmpty) {
          return _sectionCard(
            colors: colors,
            child: _emptyMyTokensState(
              colors: colors,
              title: 'No tokens created yet',
              subtitle:
                  'Deploy a token from the Create tab and it will appear here for this wallet.',
              icon: Icons.auto_awesome_rounded,
            ),
          );
        }

        return Column(
          key: const ValueKey<String>('creator_my_tokens_filled'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeading(
                    title: 'My tokens',
                    subtitle:
                        '${entries.length} token${entries.length == 1 ? '' : 's'} created by ${AddressUtils.shorten(activeAddress)} on this device.',
                    colors: colors,
                  ),
                  const Gap(16),
                  _inlineNotice(
                    colors: colors,
                    icon: Icons.devices_rounded,
                    text:
                        'This list comes from the local creator registry, so it shows tokens created from this wallet on this device even before explorer indexing catches up.',
                  ),
                ],
              ),
            ),
            const Gap(16),
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _createdTokenCard(colors: colors, entry: entry),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyMyTokensState({
    required ReefThemeColors colors,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [colors.accent, colors.accentStrong],
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const Gap(16),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
        const Gap(8),
        Text(
          subtitle,
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _createdTokenCard({
    required ReefThemeColors colors,
    required CreatedTokenEntry entry,
  }) {
    final token = entry.token;
    final createdLabel = entry.createdAt == null
        ? 'Created locally'
        : 'Created ${DateFormat('MMM d, y • h:mm a').format(entry.createdAt!.toLocal())}';

    return _sectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TokenAvatar(
                size: 54,
                iconUrl: token.iconUrl,
                fallbackSeed: token.address,
                resolveFallbackIcon: true,
                useDeterministicFallback: true,
                avatarBackgroundColor: colors.appBackground,
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      token.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      token.symbol,
                      style: TextStyle(
                        color: colors.accentStrong,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      createdLabel,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AmountUtils.formatCompactToken(token.balance),
                    style: GoogleFonts.spaceGrotesk(
                      color: colors.accentStrong,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    'initial',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.cardBackgroundSecondary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.borderColor.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contract address',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(6),
                Text(
                  token.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Gap(14),
          Row(
            children: [
              Expanded(
                child: _resultActionButton(
                  colors: colors,
                  text: 'Copy Address',
                  onPressed: () =>
                      _copyText(token.address, 'Contract address copied.'),
                ),
              ),
              const Gap(10),
              Expanded(
                child: _resultActionButton(
                  colors: colors,
                  text: 'Create Pool',
                  filled: true,
                  onPressed: () => _openCreatePoolSheet(token.address),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(
    BuildContext context,
    ReefThemeColors colors,
    WalletState walletState,
  ) {
    final resultState = _resultState!;
    final token = resultState.result?.token;

    return SingleChildScrollView(
      key: const ValueKey<String>('creator_result'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: colors.borderColor),
            ),
            child: Column(
              children: [
                if (resultState.isPending)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: colors.accentStrong,
                    ),
                  )
                else
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: resultState.isError
                          ? colors.danger.withOpacity(0.12)
                          : colors.success.withOpacity(0.14),
                    ),
                    child: Icon(
                      resultState.isError
                          ? Icons.error_outline_rounded
                          : Icons.check_rounded,
                      color: resultState.isError
                          ? colors.danger
                          : colors.success,
                      size: 34,
                    ),
                  ),
                const Gap(18),
                Text(
                  resultState.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                    height: 1,
                  ),
                ),
                const Gap(10),
                Text(
                  resultState.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (token != null) ...[
                  const Gap(22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.cardBackgroundSecondary,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      children: [
                        TokenAvatar(
                          size: 58,
                          iconUrl: token.iconUrl,
                          fallbackSeed: token.address,
                          resolveFallbackIcon: true,
                          useDeterministicFallback: true,
                          avatarBackgroundColor: colors.appBackground,
                        ),
                        const Gap(14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                token.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                token.symbol,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const Gap(10),
                              Text(
                                token.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (resultState.txHash != null) ...[
                  const Gap(14),
                  _detailLine(
                    label: 'Transaction',
                    value: resultState.txHash!,
                    colors: colors,
                  ),
                ],
                if (resultState.contractAddress != null) ...[
                  const Gap(10),
                  _detailLine(
                    label: 'Contract',
                    value: resultState.contractAddress!,
                    colors: colors,
                  ),
                ],
              ],
            ),
          ),
          const Gap(18),
          if (!resultState.isPending) ...[
            if (!resultState.isError && token != null) ...[
              _resultActionButton(
                colors: colors,
                text: 'Copy Contract Address',
                onPressed: () =>
                    _copyText(token.address, 'Contract address copied.'),
              ),
              const Gap(10),
              _resultActionButton(
                colors: colors,
                text: 'Copy Explorer Link',
                onPressed: () => _copyText(
                  _buildExplorerUrl(
                    ref.read(explorerServiceProvider),
                    token.address,
                  ),
                  'Explorer link copied.',
                ),
              ),
              const Gap(10),
              _resultActionButton(
                colors: colors,
                text: 'Create a Pool',
                filled: true,
                onPressed: walletState.portfolioTokens.length < 2
                    ? null
                    : () => _openCreatePoolSheet(token.address),
              ),
              const Gap(10),
            ],
            _resultActionButton(
              colors: colors,
              text: 'Create Another Token',
              onPressed: _resetCreator,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntro(ReefThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [colors.accent, colors.accentStrong],
                  ).createShader(bounds),
                  child: Text(
                    'Create your token',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 32,
                      height: 0.96,
                    ),
                  ),
                ),
                const Gap(10),
                Text(
                  'Use Reef chain to deploy a token, then immediately flow into pool creation.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Gap(18),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                colors: [
                  colors.accent.withOpacity(0.18),
                  colors.accentStrong.withOpacity(0.26),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: colors.borderColor),
            ),
            child: Center(
              child: TokenAvatar(
                size: 48,
                iconUrl: _request.normalizedIconUrl,
                fallbackSeed: _request.normalizedSymbol.isEmpty
                    ? 'TOKEN'
                    : _request.normalizedSymbol,
                resolveFallbackIcon: true,
                useDeterministicFallback: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(ReefThemeColors colors) {
    final request = _request;
    final symbol = request.normalizedSymbol.isEmpty
        ? 'TOKEN'
        : request.normalizedSymbol;
    final supply = request.initialSupply.trim();

    return _sectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            title: 'Token Preview',
            subtitle: 'This follows the same preview-first flow as Reefswap.',
            colors: colors,
          ),
          const Gap(16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.cardBackgroundSecondary,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.borderColor.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                TokenAvatar(
                  size: 52,
                  iconUrl: request.normalizedIconUrl,
                  fallbackSeed: symbol,
                  resolveFallbackIcon: true,
                  useDeterministicFallback: true,
                  avatarBackgroundColor: colors.appBackground,
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.normalizedName.isEmpty
                            ? 'Your Token'
                            : request.normalizedName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        symbol,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (supply.isNotEmpty)
                  Text(
                    AmountUtils.formatCompactToken(supply),
                    style: GoogleFonts.spaceGrotesk(
                      color: colors.accentStrong,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                  ),
              ],
            ),
          ),
          const Gap(16),
          _featureCard(
            colors: colors,
            enabled: request.burnable,
            title: request.burnable ? 'Burnable' : 'Not Burnable',
            description: request.burnable
                ? 'Existing tokens can be destroyed to decrease the total supply.'
                : 'Existing tokens cannot be destroyed to decrease the total supply.',
          ),
          const Gap(10),
          _featureCard(
            colors: colors,
            enabled: request.mintable,
            title: request.mintable ? 'Mintable' : 'Not Mintable',
            description: request.mintable
                ? 'New tokens can be created and added to the total supply.'
                : 'New tokens cannot be created and added to the total supply.',
          ),
        ],
      ),
    );
  }

  Widget _featureCard({
    required ReefThemeColors colors,
    required bool enabled,
    required String title,
    required String description,
  }) {
    final accentColor = enabled ? colors.success : colors.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderColor.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.16),
            ),
            child: Icon(
              enabled ? Icons.check_rounded : Icons.close_rounded,
              color: accentColor,
              size: 18,
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Gap(4),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ReefThemeColors colors,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isCreating,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: colors.textMuted,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: colors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.accentStrong, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildBooleanToggle({
    required String label,
    required bool value,
    required ReefThemeColors colors,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderColor.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: _toggleChoice(
                  label: 'Yes',
                  selected: value,
                  colors: colors,
                  onTap: () => onChanged(true),
                ),
              ),
              const Gap(8),
              Expanded(
                child: _toggleChoice(
                  label: 'No',
                  selected: !value,
                  colors: colors,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleChoice({
    required String label,
    required bool selected,
    required ReefThemeColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isCreating ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.accentStrong : colors.appBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.accentStrong : colors.borderColor,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _inlineNotice({
    required ReefThemeColors colors,
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.accentStrong, size: 18),
          const Gap(8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    Key? key,
    required ReefThemeColors colors,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.borderColor),
      ),
      child: child,
    );
  }

  Widget _sectionHeading({
    required String title,
    required String subtitle,
    required ReefThemeColors colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 28,
            height: 1,
          ),
        ),
        const Gap(6),
        Text(
          subtitle,
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _detailLine({
    required String label,
    required String value,
    required ReefThemeColors colors,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(6),
          SelectableText(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultActionButton({
    required ReefThemeColors colors,
    required String text,
    required VoidCallback? onPressed,
    bool filled = false,
  }) {
    final child = SizedBox(
      width: double.infinity,
      child: filled
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.accent, colors.accentStrong],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                foregroundColor: colors.textPrimary,
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
    );
    return child;
  }

  Future<void> _openConfirmSheet() async {
    final validationText = _validationText;
    if (validationText != null) {
      _showSnack(validationText);
      return;
    }

    final request = _request;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = context.reefColors;
        final symbol = request.normalizedSymbol.isEmpty
            ? 'TOKEN'
            : request.normalizedSymbol;
        final supply = request.initialSupply.trim();
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: colors.pageBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom + 18,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.borderColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const Gap(18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm your token',
                              style: GoogleFonts.spaceGrotesk(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 28,
                              ),
                            ),
                            const Gap(6),
                            Text(
                              'Review the metadata and token properties before deployment.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      IconButton(
                        onPressed: _isCreating
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: colors.cardBackgroundSecondary,
                        ),
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Gap(18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.cardBackgroundSecondary,
                          colors.cardBackground,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: colors.borderColor.withOpacity(0.75),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.appBackground,
                                border: Border.all(color: colors.borderColor),
                              ),
                              child: Center(
                                child: TokenAvatar(
                                  size: 46,
                                  iconUrl: request.normalizedIconUrl,
                                  fallbackSeed: symbol,
                                  resolveFallbackIcon: true,
                                  useDeterministicFallback: true,
                                ),
                              ),
                            ),
                            const Gap(14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request.normalizedName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.spaceGrotesk(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 24,
                                    ),
                                  ),
                                  const Gap(4),
                                  Text(
                                    symbol,
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (supply.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AmountUtils.formatCompactToken(supply),
                                    style: GoogleFonts.spaceGrotesk(
                                      color: colors.accentStrong,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const Gap(2),
                                  Text(
                                    'initial supply',
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const Gap(16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _confirmFlagChip(
                              colors: colors,
                              icon: request.burnable
                                  ? Icons.local_fire_department_rounded
                                  : Icons.block_rounded,
                              label: request.burnable
                                  ? 'Burnable'
                                  : 'Not burnable',
                              accentColor: request.burnable
                                  ? colors.success
                                  : colors.textMuted,
                            ),
                            _confirmFlagChip(
                              colors: colors,
                              icon: request.mintable
                                  ? Icons.add_circle_rounded
                                  : Icons.remove_circle_outline_rounded,
                              label: request.mintable
                                  ? 'Mintable'
                                  : 'Fixed supply',
                              accentColor: request.mintable
                                  ? colors.success
                                  : colors.textMuted,
                            ),
                            _confirmFlagChip(
                              colors: colors,
                              icon: request.normalizedIconUrl == null
                                  ? Icons.auto_awesome_rounded
                                  : Icons.image_rounded,
                              label: request.normalizedIconUrl == null
                                  ? 'Generated logo'
                                  : 'Custom logo',
                              accentColor: colors.accentStrong,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(18),
                  _confirmSummaryItem(
                    colors: colors,
                    label: 'Token name',
                    value: request.normalizedName,
                  ),
                  _confirmSummaryItem(
                    colors: colors,
                    label: 'Token symbol',
                    value: symbol,
                  ),
                  _confirmSummaryItem(
                    colors: colors,
                    label: 'Initial supply',
                    value: request.initialSupply,
                  ),
                  const Gap(18),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.accent, colors.accentStrong],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accentStrong.withOpacity(0.22),
                            blurRadius: 16,
                            offset: const Offset(0, 10),
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isCreating
                            ? null
                            : () async {
                                Navigator.of(context).pop();
                                await _startCreation();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Create Token',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _confirmSummaryItem({
    required ReefThemeColors colors,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: colors.cardBackgroundSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderColor.withOpacity(0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmFlagChip({
    required ReefThemeColors colors,
    required IconData icon,
    required String label,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.borderColor.withOpacity(0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accentColor),
          const Gap(8),
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startCreation() async {
    if (_isCreating) return;
    final account = ref.read(walletProvider).activeAccount;
    if (account == null) {
      _showSnack('Select or create an account before deploying a token.');
      return;
    }

    final request = _request;
    final validationText = ref
        .read(tokenCreatorServiceProvider)
        .validate(request);
    if (validationText != null) {
      _showSnack(validationText);
      return;
    }

    final creatorService = ref.read(tokenCreatorServiceProvider);
    final web3Service = ref.read(web3ServiceProvider);
    TokenCreationSubmission? submission;

    setState(() => _isCreating = true);
    try {
      final preview = await creatorService.buildPreview(
        account: account,
        request: request,
        web3Service: web3Service,
      );
      if (!mounted) return;

      final approval = await Navigator.of(context)
          .push<TransactionApprovalResult>(
            MaterialPageRoute(
              builder: (_) => TransactionConfirmationScreen(
                preview: preview,
                approveButtonText: 'Approve & Create',
                rejectButtonText: 'Reject',
                onApprove: () async {
                  submission = await creatorService.submitCreation(
                    account: account,
                    request: request,
                    web3Service: web3Service,
                  );
                  return submission!.txHash;
                },
              ),
            ),
          );
      if (!mounted) return;
      if (approval == null || !approval.approved || submission == null) {
        setState(() => _isCreating = false);
        return;
      }

      final txHash = submission!.txHash;
      setState(() {
        _isCreating = false;
        _resultState = _CreatorResultState(
          title: 'Deploying token',
          message:
              'Transaction submitted (${_shortHash(txHash)}). Waiting for confirmation.',
          txHash: txHash,
          isPending: true,
        );
      });

      final result = await creatorService.completeCreation(
        submission: submission!,
        web3Service: web3Service,
      );
      await ref.read(walletProvider.notifier).refreshPortfolio();
      ref.invalidate(poolsProvider);
      if (!mounted) return;

      final fallbackSuffix = result.usedFallback
          ? ' Mint/burn toggles are unavailable on this local node bytecode.'
          : '';
      setState(() {
        _resultState = _CreatorResultState(
          title: 'Token created',
          message:
              'Success, ${result.token.name} (${result.token.symbol}) deployed with initial supply ${request.initialSupply}.$fallbackSuffix',
          txHash: result.txHash,
          contractAddress: result.contractAddress,
          result: result,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _resultState = _CreatorResultState(
          title: 'Error creating token',
          message: error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      });
    }
  }

  Future<void> _openCreatePoolSheet(String preferredTokenAddress) async {
    await ref.read(walletProvider.notifier).refreshPortfolio();
    if (!mounted) return;
    final walletState = ref.read(walletProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePoolSheet(
        portfolioTokens: walletState.portfolioTokens,
        preferredTokenAddress: preferredTokenAddress,
        onPoolCreated: () {
          ref.invalidate(poolsProvider);
        },
      ),
    );
  }

  void _resetCreator() {
    _nameController.clear();
    _symbolController.clear();
    _supplyController.clear();
    _iconUrlController.clear();
    setState(() {
      _selectedTabIndex = 0;
      _burnable = true;
      _mintable = true;
      _isCreating = false;
      _resultState = null;
    });
  }

  Future<void> _copyText(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showSnack(message);
  }

  String _buildExplorerUrl(ExplorerService explorerService, String address) {
    final base = explorerService.explorerBaseUrl.replaceFirst(
      RegExp(r'/$'),
      '',
    );
    return '$base/token/$address';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _shortHash(String value) {
    if (value.length <= 14) return value;
    return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
  }
}

class _CreatorResultState {
  const _CreatorResultState({
    required this.title,
    required this.message,
    this.txHash,
    this.contractAddress,
    this.result,
    this.isPending = false,
    this.isError = false,
  });

  final String title;
  final String message;
  final String? txHash;
  final String? contractAddress;
  final TokenCreationResult? result;
  final bool isPending;
  final bool isError;
}
