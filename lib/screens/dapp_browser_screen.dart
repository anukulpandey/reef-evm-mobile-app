import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/theme/reef_theme_colors.dart';
import '../models/account.dart';
import '../models/dapp_transaction_request.dart';
import '../models/transaction_preview.dart';
import '../providers/service_providers.dart';
import '../providers/wallet_provider.dart';
import '../services/dapp_browser_service.dart';
import '../utils/address_utils.dart';
import '../utils/amount_utils.dart';
import 'dapp_signature_approval_screen.dart';
import 'transaction_confirmation_screen.dart';

class DappBrowserScreen extends ConsumerStatefulWidget {
  const DappBrowserScreen({super.key});

  @override
  ConsumerState<DappBrowserScreen> createState() => _DappBrowserScreenState();
}

class _DappBrowserScreenState extends ConsumerState<DappBrowserScreen> {
  static const List<String> _defaultSites = <String>[
    'http://127.0.0.1:8082',
    'https://app.uniswap.org',
    'https://app.1inch.io',
  ];

  final TextEditingController _urlController = TextEditingController();
  InAppWebViewController? _webViewController;
  String? _currentUrl;
  String? _pageTitle;
  bool _isLoading = false;
  double _progress = 0;
  bool _showHome = true;
  List<String> _recentUrls = const <String>[];
  bool _handlingRequest = false;
  ProviderSubscription<WalletState>? _walletSubscription;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadRecentUrls);
    _walletSubscription = ref.listenManual(walletProvider, (previous, next) {
      _pushWalletStateToPage();
    });
  }

  @override
  void dispose() {
    _walletSubscription?.close();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentUrls() async {
    final recents = await ref.read(dappBrowserServiceProvider).getRecentUrls();
    if (!mounted) return;
    setState(() {
      _recentUrls = recents;
    });
  }

  Future<void> _openUrl(String rawUrl) async {
    final browser = ref.read(dappBrowserServiceProvider);
    final normalized = browser.normalizeUserUrl(rawUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      _showToast('Enter a valid dapp URL.');
      return;
    }

    _urlController.text = normalized;
    setState(() {
      _currentUrl = normalized;
      _showHome = false;
      _isLoading = true;
    });
    await browser.addRecentUrl(normalized);
    await _loadRecentUrls();
    if (_webViewController != null) {
      await _webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(normalized)),
      );
    }
  }

  Future<void> _pushWalletStateToPage() async {
    final controller = _webViewController;
    if (controller == null) return;
    final wallet = ref.read(walletProvider);
    final browser = ref.read(dappBrowserServiceProvider);
    final chainId = await ref.read(web3ServiceProvider).getChainId();
    final currentUrl = _currentUrl;
    final currentOrigin = currentUrl == null
        ? ''
        : browser.normalizeOriginFromUrl(currentUrl);
    final approved = currentOrigin.isNotEmpty
        ? await browser.isOriginApproved(currentOrigin)
        : false;
    final accounts = approved && wallet.activeAccount != null
        ? <String>[wallet.activeAccount!.address]
        : <String>[];

    final script =
        '''
      if (window.__reefWalletUpdate) {
        window.__reefWalletUpdate(${jsonEncode(<String, dynamic>{'accounts': accounts, 'chainId': _chainIdToHex(chainId), 'networkVersion': '$chainId'})});
      }
    ''';
    try {
      await controller.evaluateJavascript(source: script);
    } catch (_) {
      // Ignore if page is not ready yet.
    }
  }

  Future<dynamic> _handleBridgeCall(List<dynamic> args) async {
    if (args.isEmpty) {
      return _bridgeError(-32600, 'Malformed bridge request.');
    }
    final payload = args.first;
    Map<String, dynamic> request;
    try {
      if (payload is String) {
        request = jsonDecode(payload) as Map<String, dynamic>;
      } else if (payload is Map) {
        request = Map<String, dynamic>.from(payload as Map);
      } else {
        return _bridgeError(-32600, 'Malformed bridge request.');
      }
    } catch (_) {
      return _bridgeError(-32600, 'Malformed bridge request.');
    }

    final method = (request['method'] ?? '').toString().trim();
    final params = (request['params'] is List)
        ? List<dynamic>.from(request['params'] as List)
        : const <dynamic>[];
    final origin = (request['origin'] ?? '').toString().trim();

    if (method.isEmpty) {
      return _bridgeError(-32600, 'Missing RPC method.');
    }

    final requiresApproval = _approvalMethods.contains(method);
    if (requiresApproval && _handlingRequest) {
      return _bridgeError(-32002, 'Another wallet request is already open.');
    }

    if (requiresApproval) {
      _handlingRequest = true;
    }
    try {
      final result = await _handleDappRequest(
        method: method,
        params: params,
        origin: origin,
      );
      return <String, dynamic>{'result': result};
    } on _DappBridgeException catch (error) {
      return _bridgeError(error.code, error.message, data: error.data);
    } catch (error, stackTrace) {
      print('[dapp_browser][request_error] method=$method error=$error');
      print('[dapp_browser][request_error][stack]=$stackTrace');
      return _bridgeError(-32000, 'Wallet request failed.');
    } finally {
      if (requiresApproval) {
        _handlingRequest = false;
      }
    }
  }

  Future<dynamic> _handleDappRequest({
    required String method,
    required List<dynamic> params,
    required String origin,
  }) async {
    final wallet = ref.read(walletProvider);
    final account = wallet.activeAccount;
    final web3 = ref.read(web3ServiceProvider);
    final browser = ref.read(dappBrowserServiceProvider);
    final currentChainId = await web3.getChainId();
    final normalizedOrigin = browser.normalizeOriginFromUrl(origin);

    switch (method) {
      case 'eth_requestAccounts':
        if (account == null) {
          throw const _DappBridgeException(
            4100,
            'No active account available in the wallet.',
          );
        }
        final approved =
            await browser.isOriginApproved(normalizedOrigin) ||
            await _showConnectApproval(
              origin: normalizedOrigin,
              account: account,
            );
        if (!approved) {
          throw const _DappBridgeException(4001, 'User rejected the request.');
        }
        await browser.approveOrigin(normalizedOrigin);
        await _pushWalletStateToPage();
        return <String>[account.address];
      case 'eth_accounts':
        if (account == null) return const <String>[];
        final approved = await browser.isOriginApproved(normalizedOrigin);
        return approved ? <String>[account.address] : const <String>[];
      case 'eth_chainId':
        return _chainIdToHex(currentChainId);
      case 'net_version':
        return '$currentChainId';
      case 'wallet_switchEthereumChain':
      case 'wallet_addEthereumChain':
        final requestedChainId = _extractChainId(params);
        if (requestedChainId == null) {
          throw const _DappBridgeException(-32602, 'Missing chainId.');
        }
        if (requestedChainId != currentChainId) {
          throw _DappBridgeException(
            4902,
            'Only Reef network is available in this wallet.',
            data: <String, dynamic>{
              'requestedChainId': _chainIdToHex(requestedChainId),
              'walletChainId': _chainIdToHex(currentChainId),
            },
          );
        }
        return null;
      case 'eth_sendTransaction':
        if (account == null) {
          throw const _DappBridgeException(
            4100,
            'No active account available in the wallet.',
          );
        }
        if (!await browser.isOriginApproved(normalizedOrigin)) {
          final approved = await _showConnectApproval(
            origin: normalizedOrigin,
            account: account,
          );
          if (!approved) {
            throw const _DappBridgeException(
              4001,
              'User rejected the request.',
            );
          }
          await browser.approveOrigin(normalizedOrigin);
          await _pushWalletStateToPage();
        }
        if (params.isEmpty || params.first is! Map) {
          throw const _DappBridgeException(
            -32602,
            'Missing transaction payload.',
          );
        }
        final txRequest = DappTransactionRequest.fromRpc(
          Map<String, dynamic>.from(params.first as Map),
        );
        final requestedFrom = txRequest.from?.toLowerCase();
        if (requestedFrom != null &&
            requestedFrom.isNotEmpty &&
            requestedFrom != account.address.toLowerCase()) {
          throw const _DappBridgeException(
            4100,
            'Requested from address does not match the active wallet.',
          );
        }

        final preview = await _buildDappTransactionPreview(
          origin: normalizedOrigin,
          request: txRequest,
        );
        final approval = await Navigator.of(context)
            .push<TransactionApprovalResult>(
              MaterialPageRoute(
                builder: (_) => TransactionConfirmationScreen(
                  preview: preview,
                  approveButtonText: 'Approve & Send',
                  onApprove: () => web3.sendDappTransaction(
                    account: account,
                    request: txRequest,
                  ),
                ),
              ),
            );
        if (approval == null || !approval.approved || approval.txHash == null) {
          throw const _DappBridgeException(4001, 'User rejected the request.');
        }
        return approval.txHash;
      case 'personal_sign':
      case 'eth_sign':
      case 'eth_signtypeddata':
      case 'eth_signtypeddata_v3':
      case 'eth_signtypeddata_v4':
        if (account == null) {
          throw const _DappBridgeException(
            4100,
            'No active account available in the wallet.',
          );
        }
        if (!await browser.isOriginApproved(normalizedOrigin)) {
          final approved = await _showConnectApproval(
            origin: normalizedOrigin,
            account: account,
          );
          if (!approved) {
            throw const _DappBridgeException(
              4001,
              'User rejected the request.',
            );
          }
          await browser.approveOrigin(normalizedOrigin);
          await _pushWalletStateToPage();
        }
        return _handleSignatureRequest(
          method: method,
          params: params,
          origin: normalizedOrigin,
          accountAddress: account.address,
        );
      default:
        if (_passthroughMethods.contains(method)) {
          return web3.rpcRequest(method: method, params: params);
        }
        throw _DappBridgeException(
          4200,
          'The wallet does not support $method yet.',
        );
    }
  }

  Future<String> _handleSignatureRequest({
    required String method,
    required List<dynamic> params,
    required String origin,
    required String accountAddress,
  }) async {
    final account = ref.read(walletProvider).activeAccount!;
    final normalizedMethod = method.toLowerCase();

    String payloadTitle;
    String payloadPreview;
    String signature;

    if (normalizedMethod == 'personal_sign' || normalizedMethod == 'eth_sign') {
      final (messageData, requestedAddress) = _extractSignMessagePayload(
        method: normalizedMethod,
        params: params,
      );
      if (requestedAddress != null &&
          requestedAddress.toLowerCase() != accountAddress.toLowerCase()) {
        throw const _DappBridgeException(
          4100,
          'Requested address does not match the active wallet.',
        );
      }
      payloadTitle = 'Message';
      payloadPreview = _humanizeMessagePayload(messageData);
      final approved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => DappSignatureApprovalScreen(
            origin: origin,
            method: method,
            payloadTitle: payloadTitle,
            payloadPreview: payloadPreview,
          ),
        ),
      );
      if (approved != true) {
        throw const _DappBridgeException(4001, 'User rejected the request.');
      }
      final web3 = ref.read(web3ServiceProvider);
      signature = normalizedMethod == 'personal_sign'
          ? await web3.signPersonalMessage(
              account: account,
              payload: messageData,
            )
          : await web3.signRawMessage(account: account, payload: messageData);
    } else {
      final (jsonData, requestedAddress) = _extractTypedDataPayload(params);
      if (requestedAddress != null &&
          requestedAddress.toLowerCase() != accountAddress.toLowerCase()) {
        throw const _DappBridgeException(
          4100,
          'Requested address does not match the active wallet.',
        );
      }
      payloadTitle = 'Typed data';
      payloadPreview = _prettyJson(jsonData);
      final approved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => DappSignatureApprovalScreen(
            origin: origin,
            method: method,
            payloadTitle: payloadTitle,
            payloadPreview: payloadPreview,
            approveButtonText: 'Approve & Sign',
          ),
        ),
      );
      if (approved != true) {
        throw const _DappBridgeException(4001, 'User rejected the request.');
      }
      signature = await ref
          .read(web3ServiceProvider)
          .signTypedData(account: account, jsonData: jsonData, method: method);
    }

    return signature;
  }

  Future<bool> _showConnectApproval({
    required String origin,
    required Account account,
  }) async {
    final colors = context.reefColors;
    final approved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect dapp',
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(8),
                Text(
                  '$origin wants to connect to your Reef wallet.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                const Gap(16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.cardBackgroundSecondary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Gap(6),
                      Text(
                        AddressUtils.shorten(account.address, prefixLength: 6),
                        style: GoogleFonts.spaceGrotesk(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Reject'),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Connect'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return approved ?? false;
  }

  Future<TransactionPreview> _buildDappTransactionPreview({
    required String origin,
    required DappTransactionRequest request,
  }) async {
    final web3 = ref.read(web3ServiceProvider);
    final chainId = await web3.getChainId();
    final gasPriceWei =
        request.maxFeePerGasWei ??
        request.gasPriceWei ??
        await web3.getGasPriceWei();
    final gasLimit =
        request.gasLimit ??
        await web3.estimateDappTransactionGasLimit(
          fromAddress: ref.read(walletProvider).activeAccount!.address,
          request: request,
        );
    final feeWei = gasPriceWei * BigInt.from(gasLimit);
    final amountDisplay = request.valueWei > BigInt.zero
        ? '${AmountUtils.formatAmountFromRaw(request.valueWei, 18)} REEF'
        : (request.isContractCall ? 'Contract interaction' : '0 REEF');

    return TransactionPreview(
      title: 'Dapp Transaction',
      methodName: request.isContractCall
          ? 'eth_sendTransaction'
          : 'nativeTransfer',
      recipientAddress: request.to ?? 'Contract deployment',
      recipientLabel: 'Recipient',
      amountDisplay: amountDisplay,
      networkName: 'Reef',
      chainId: chainId,
      contractAddress: request.to,
      gasLimit: gasLimit,
      gasPriceWei: gasPriceWei,
      estimatedFeeDisplay:
          '${NumberFormat('0.########').format(feeWei.toDouble() / 1000000000000000000)} REEF',
      calldataHex: request.dataHex,
      fields: <TransactionPreviewField>[
        TransactionPreviewField(label: 'Origin', value: origin),
        if (request.from != null)
          TransactionPreviewField(label: 'From', value: request.from!),
        TransactionPreviewField(
          label: 'To',
          value: request.to ?? 'Contract deployment',
        ),
        TransactionPreviewField(
          label: 'Value (raw)',
          value: request.valueWei.toString(),
        ),
        if (request.nonce != null)
          TransactionPreviewField(label: 'Nonce', value: '${request.nonce}'),
        if (request.chainId != null)
          TransactionPreviewField(
            label: 'Requested Chain',
            value: '${request.chainId}',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        title: Text(
          'DApp Browser',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 21,
          ),
        ),
        actions: [
          if (_currentUrl != null)
            IconButton(
              tooltip: 'Copy URL',
              onPressed: () async {
                final url = _currentUrl;
                if (url == null || url.trim().isEmpty) return;
                await Clipboard.setData(ClipboardData(text: url));
                if (!mounted) return;
                _showToast('URL copied');
              },
              icon: const Icon(Icons.copy_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(colors, wallet),
          if (_showHome)
            Expanded(child: _buildHome(colors))
          else
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(_currentUrl ?? 'about:blank'),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      transparentBackground: false,
                      useShouldOverrideUrlLoading: true,
                      mediaPlaybackRequiresUserGesture: false,
                    ),
                    initialUserScripts: UnmodifiableListView<UserScript>([
                      UserScript(
                        source: _ethereumBridgeScript,
                        injectionTime:
                            UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                    ]),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                      controller.addJavaScriptHandler(
                        handlerName: 'reefWalletBridge',
                        callback: _handleBridgeCall,
                      );
                    },
                    onTitleChanged: (controller, title) {
                      if (!mounted) return;
                      setState(() {
                        _pageTitle = title;
                      });
                    },
                    onLoadStart: (controller, url) {
                      if (!mounted) return;
                      setState(() {
                        _isLoading = true;
                        _currentUrl = url?.toString();
                        _urlController.text = url?.toString() ?? '';
                      });
                    },
                    onLoadStop: (controller, url) async {
                      final text = url?.toString();
                      if (text != null && text.startsWith('http')) {
                        await ref
                            .read(dappBrowserServiceProvider)
                            .addRecentUrl(text);
                        await _loadRecentUrls();
                      }
                      if (!mounted) return;
                      setState(() {
                        _isLoading = false;
                        _currentUrl = text;
                        _urlController.text = text ?? _urlController.text;
                      });
                      await _pushWalletStateToPage();
                    },
                    onProgressChanged: (controller, progress) {
                      if (!mounted) return;
                      setState(() {
                        _progress = progress / 100;
                      });
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                          final url = navigationAction.request.url?.toString();
                          if (url == null) {
                            return NavigationActionPolicy.ALLOW;
                          }
                          if (url.startsWith('http://') ||
                              url.startsWith('https://')) {
                            setState(() {
                              _showHome = false;
                              _currentUrl = url;
                              _urlController.text = url;
                            });
                            return NavigationActionPolicy.ALLOW;
                          }
                          return NavigationActionPolicy.CANCEL;
                        },
                  ),
                  if (_isLoading)
                    Align(
                      alignment: Alignment.topCenter,
                      child: LinearProgressIndicator(
                        value: _progress > 0 && _progress < 1
                            ? _progress
                            : null,
                        minHeight: 3,
                        backgroundColor: colors.borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.accentStrong,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ReefThemeColors colors, wallet) {
    final activeAddress = wallet.activeAccount?.address;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ToolbarButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => _webViewController?.goBack(),
              ),
              const Gap(8),
              _ToolbarButton(
                icon: Icons.arrow_forward_ios_rounded,
                onTap: () => _webViewController?.goForward(),
              ),
              const Gap(8),
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.cardBackgroundSecondary,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Gap(12),
                      Icon(
                        Icons.language_rounded,
                        color: colors.textMuted,
                        size: 20,
                      ),
                      const Gap(10),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter dapp URL',
                            hintStyle: TextStyle(color: colors.textMuted),
                            border: InputBorder.none,
                          ),
                          textInputAction: TextInputAction.go,
                          onSubmitted: _openUrl,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openUrl(_urlController.text),
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          color: colors.accentStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(8),
              _ToolbarButton(
                icon: Icons.refresh_rounded,
                onTap: () => _webViewController?.reload(),
              ),
            ],
          ),
          const Gap(10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.cardBackgroundSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: colors.accentStrong,
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          activeAddress == null
                              ? 'No active wallet'
                              : AddressUtils.shorten(
                                  activeAddress,
                                  prefixLength: 6,
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_pageTitle?.trim().isNotEmpty ?? false) ...[
                const Gap(8),
                Flexible(
                  child: Text(
                    _pageTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHome(ReefThemeColors colors) {
    final launchCards = <String>[
      ..._defaultSites,
      ..._recentUrls.where((url) => !_defaultSites.contains(url)),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wallet-ready browsing',
                style: GoogleFonts.spaceGrotesk(
                  color: colors.textPrimary,
                  fontSize: 34,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(10),
              Text(
                'Open a dapp, connect the active Reef wallet, approve signatures, and send transactions with the same confirmation flow used elsewhere in the app.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const Gap(18),
        Text(
          'Quick launch',
          style: GoogleFonts.spaceGrotesk(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(12),
        for (final site in launchCards.take(8)) ...[
          _QuickLaunchTile(
            url: site,
            colors: colors,
            onTap: () => _openUrl(site),
          ),
          const Gap(10),
        ],
      ],
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _chainIdToHex(int chainId) => '0x${chainId.toRadixString(16)}';

  static int? _extractChainId(List<dynamic> params) {
    if (params.isEmpty || params.first is! Map) return null;
    final raw = (params.first as Map)['chainId'];
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.startsWith('0x') || text.startsWith('0X')) {
      return int.tryParse(text.substring(2), radix: 16);
    }
    return int.tryParse(text);
  }

  static (Uint8List, String?) _extractSignMessagePayload({
    required String method,
    required List<dynamic> params,
  }) {
    if (params.isEmpty) {
      throw const _DappBridgeException(-32602, 'Missing message payload.');
    }
    final first = params.first?.toString() ?? '';
    final second = params.length > 1 ? params[1]?.toString() : null;
    final addressFirst = _looksLikeAddress(first);
    final addressSecond = second != null && _looksLikeAddress(second);

    late final String message;
    String? address;
    if (method == 'personal_sign') {
      if (addressFirst && second != null) {
        address = first;
        message = second;
      } else {
        message = first;
        address = addressSecond ? second : null;
      }
    } else {
      address = first;
      message = second ?? '';
    }

    if (message.isEmpty) {
      throw const _DappBridgeException(-32602, 'Missing message payload.');
    }
    return (_coerceMessageBytes(message), address);
  }

  static (String, String?) _extractTypedDataPayload(List<dynamic> params) {
    if (params.isEmpty) {
      throw const _DappBridgeException(-32602, 'Missing typed data payload.');
    }
    final first = params.first?.toString() ?? '';
    final second = params.length > 1 ? params[1]?.toString() : null;
    final addressFirst = _looksLikeAddress(first);
    final addressSecond = second != null && _looksLikeAddress(second);

    if (addressFirst && second != null) {
      return (second, first);
    }
    return (first, addressSecond ? second : null);
  }

  static bool _looksLikeAddress(String raw) {
    final text = raw.trim();
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(text);
  }

  static Uint8List _coerceMessageBytes(String raw) {
    final text = raw.trim();
    if (RegExp(r'^0x[a-fA-F0-9]+$').hasMatch(text)) {
      final normalized = text.substring(2);
      final bytes = <int>[];
      for (var index = 0; index < normalized.length; index += 2) {
        final chunk = normalized.substring(index, index + 2);
        bytes.add(int.parse(chunk, radix: 16));
      }
      return Uint8List.fromList(bytes);
    }
    return Uint8List.fromList(utf8.encode(raw));
  }

  static String _humanizeMessagePayload(Uint8List bytes) {
    try {
      final decoded = utf8.decode(bytes);
      final trimmed = decoded.trim();
      if (trimmed.isNotEmpty) return trimmed;
    } catch (_) {
      // Fall back to hex below.
    }
    return '0x${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
  }

  static String _prettyJson(String jsonData) {
    try {
      final decoded = jsonDecode(jsonData);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return jsonData;
    }
  }

  static Map<String, dynamic> _bridgeError(
    int code,
    String message, {
    dynamic data,
  }) {
    return <String, dynamic>{
      'error': <String, dynamic>{
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      },
    };
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    return Material(
      color: colors.cardBackgroundSecondary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: colors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

class _QuickLaunchTile extends StatelessWidget {
  const _QuickLaunchTile({
    required this.url,
    required this.colors,
    required this.onTap,
  });

  final String url;
  final ReefThemeColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host ?? url;
    return Material(
      color: colors.cardBackground,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [colors.accent, colors.accentStrong],
                  ),
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  color: Colors.white,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_outward_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DappBridgeException implements Exception {
  const _DappBridgeException(this.code, this.message, {this.data});

  final int code;
  final String message;
  final dynamic data;
}

const Set<String> _passthroughMethods = <String>{
  'eth_blockNumber',
  'eth_call',
  'eth_estimateGas',
  'eth_feeHistory',
  'eth_gasPrice',
  'eth_getBalance',
  'eth_getBlockByHash',
  'eth_getBlockByNumber',
  'eth_getCode',
  'eth_getLogs',
  'eth_getStorageAt',
  'eth_getTransactionByHash',
  'eth_getTransactionCount',
  'eth_getTransactionReceipt',
  'eth_maxPriorityFeePerGas',
  'net_version',
};

const Set<String> _approvalMethods = <String>{
  'eth_requestAccounts',
  'eth_sendTransaction',
  'personal_sign',
  'eth_sign',
  'eth_signtypeddata',
  'eth_signtypeddata_v3',
  'eth_signtypeddata_v4',
};

const String _ethereumBridgeScript = r'''
(() => {
  if (window.__reefWalletInjected) return;
  window.__reefWalletInjected = true;

  const listeners = {};

  const emit = (event, payload) => {
    (listeners[event] || []).forEach((listener) => {
      try {
        listener(payload);
      } catch (_) {}
    });
  };

  const normalizeResponse = (raw) => {
    if (typeof raw === 'string') {
      try {
        return JSON.parse(raw);
      } catch (_) {
        return { result: raw };
      }
    }
    return raw || {};
  };

  const toError = (error) => {
    const normalized = error || {};
    const err = new Error(normalized.message || 'Wallet request failed');
    err.code = normalized.code ?? -32000;
    if (normalized.data !== undefined) {
      err.data = normalized.data;
    }
    return err;
  };

  const provider = {
    isReefWallet: true,
    isMetaMask: false,
    selectedAddress: null,
    chainId: '0x3673',
    networkVersion: '13939',
    _accounts: [],
    async request({ method, params = [] }) {
      const raw = await window.flutter_inappwebview.callHandler(
        'reefWalletBridge',
        JSON.stringify({
          method,
          params,
          origin: window.location.origin,
          href: window.location.href,
        }),
      );
      const response = normalizeResponse(raw);
      if (response.error) {
        throw toError(response.error);
      }
      return response.result;
    },
    async send(methodOrPayload, paramsOrCallback) {
      if (typeof methodOrPayload === 'string') {
        return this.request({ method: methodOrPayload, params: paramsOrCallback || [] });
      }
      if (typeof paramsOrCallback === 'function') {
        return this.sendAsync(methodOrPayload, paramsOrCallback);
      }
      return this.request({
        method: methodOrPayload.method,
        params: methodOrPayload.params || [],
      });
    },
    sendAsync(payload, callback) {
      this.request({
        method: payload.method,
        params: payload.params || [],
      }).then((result) => {
        callback(null, {
          id: payload.id,
          jsonrpc: '2.0',
          result,
        });
      }).catch((error) => {
        callback(error, null);
      });
    },
    enable() {
      return this.request({ method: 'eth_requestAccounts' });
    },
    on(event, listener) {
      listeners[event] = listeners[event] || [];
      listeners[event].push(listener);
      return this;
    },
    removeListener(event, listener) {
      listeners[event] = (listeners[event] || []).filter(
        (entry) => entry !== listener,
      );
      return this;
    },
    isConnected() {
      return true;
    },
  };

  provider._setAccounts = (accounts) => {
    provider._accounts = Array.isArray(accounts) ? accounts : [];
    provider.selectedAddress = provider._accounts[0] || null;
    emit('accountsChanged', provider._accounts);
  };

  provider._setChainId = (chainId, networkVersion) => {
    provider.chainId = chainId || provider.chainId;
    provider.networkVersion = networkVersion || provider.networkVersion;
    emit('chainChanged', provider.chainId);
  };

  window.__reefWalletUpdate = (state) => {
    provider._setAccounts(state.accounts || []);
    provider._setChainId(state.chainId, state.networkVersion);
  };

  window.ethereum = provider;
  window.dispatchEvent(new Event('ethereum#initialized'));
})();
''';
