import 'default_token_icon_b64.dart';

class TokenIconResolver {
  static const String _reefIpfsGateway = 'https://reef.infura-ipfs.io/ipfs/';
  static const String _reefAddress =
      '0x0000000000000000000000000000000001000000';
  static const String reefTokenIconUrl =
      'https://s2.coinmarketcap.com/static/img/coins/64x64/6951.png';

  static String resolveTokenIconUrl({
    String? address,
    String? symbol,
    String? iconUrl,
  }) {
    final normalizedSymbol = symbol?.trim().toUpperCase();
    if (normalizedSymbol == 'REEF' || normalizedSymbol == 'WREEF') {
      return reefTokenIconUrl;
    }

    final resolvedIpfsUrl = resolveIpfsUrl(iconUrl);
    if (resolvedIpfsUrl != null) return resolvedIpfsUrl;

    final tokenAddress =
        address ?? (normalizedSymbol == 'REEF' ? _reefAddress : (symbol ?? ''));
    return getIconUrl(tokenAddress);
  }

  static String? resolveIpfsUrl(String? iconUrl) {
    if (iconUrl == null) return null;
    final normalized = iconUrl.trim();
    if (normalized.isEmpty) return null;

    if (normalized.startsWith('ipfs://')) {
      final hash = normalized
          .replaceFirst(RegExp(r'^ipfs://'), '')
          .replaceFirst(RegExp(r'^ipfs/'), '');
      return hash.isEmpty ? null : '$_reefIpfsGateway$hash';
    }

    if (normalized.contains('cloudflare-ipfs.com')) {
      return normalized.replaceAll(
        'cloudflare-ipfs.com',
        'reef.infura-ipfs.io',
      );
    }

    return normalized;
  }

  static String getIconUrl(String tokenAddress) {
    final normalizedTokenAddress = _normalizeAddress(tokenAddress);
    if (normalizedTokenAddress == _normalizeAddress(_reefAddress)) {
      return reefTokenIconUrl;
    }

    final checksum = _getHashSumLastNumber(normalizedTokenAddress);
    final index = (checksum >= 0 && checksum < 10) ? checksum : checksum % 10;
    final iconBase64 = defaultTokenIconBase64[index];
    return 'data:image/svg+xml;base64,$iconBase64';
  }

  static String _normalizeAddress(String? address) {
    return (address ?? '').trim().toLowerCase();
  }

  static int _getHashSumLastNumber(String address) {
    var sum = 0;
    for (final ch in address.split('')) {
      final nr = int.tryParse(ch);
      if (nr != null) sum += nr;
    }
    final sumText = sum.toString();
    return int.tryParse(sumText.substring(sumText.length - 1)) ?? 0;
  }
}
