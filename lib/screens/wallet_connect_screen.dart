import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/app_localizations.dart';

class WalletConnectScreen extends StatefulWidget {
  const WalletConnectScreen({super.key});

  @override
  State<WalletConnectScreen> createState() => _WalletConnectScreenState();
}

class _WalletConnectScreenState extends State<WalletConnectScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = false;
  String? _scannedUri;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _toggleScan() async {
    if (_isScanning) {
      await _scannerController.stop();
      setState(() => _isScanning = false);
      return;
    }

    setState(() {
      _scannedUri = null;
      _isScanning = true;
    });
    await _scannerController.start();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      if (!raw.toLowerCase().startsWith('wc:')) continue;
      _scannerController.stop();
      setState(() {
        _scannedUri = raw;
        _isScanning = false;
      });
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletConnect)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.noWalletConnectYet, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _toggleScan,
              child: Text(_isScanning ? l10n.stopScan : l10n.scanQr),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: Colors.black12,
                  child: _isScanning
                      ? MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            if (_scannedUri != null) ...[
              const SizedBox(height: 14),
              Text(
                '${l10n.scannedUri}:',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              SelectableText(_scannedUri!),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final uri = _scannedUri;
                  if (uri == null) return;
                  await Clipboard.setData(ClipboardData(text: uri));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.copied)));
                },
                child: Text(l10n.copied),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
