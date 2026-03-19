import 'dart:convert';

import 'package:http/http.dart' as http;

class BuyReefService {
  static const String _alchemyPayEndpoint =
      'https://api.reefscan.com/alchemy-pay/signature';
  static const String _letsExchangeHost = 'my.letsexchange.io';
  static const String _letsExchangePath = '/v2/widget';
  static const String _letsExchangeAffiliateId = '1564';

  Uri buildLetsExchangeUri() {
    return Uri.https(_letsExchangeHost, _letsExchangePath, {
      'to': 'REEF',
      'coin_to': 'REEF',
      'default_coin_to': 'REEF',
      'cex_default_coin_to': 'REEF',
      'affiliate_id': _letsExchangeAffiliateId,
      'ref_id': _letsExchangeAffiliateId,
    });
  }

  Future<Uri> fetchAlchemyPayUri({
    required String walletAddress,
    required double fiatAmountUsd,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();

    try {
      final uri = Uri.parse(_alchemyPayEndpoint).replace(
        queryParameters: {
          'crypto': 'REEF',
          'fiat': 'USD',
          'fiatAmount': fiatAmountUsd.toStringAsFixed(2),
          'merchantOrderNo':
              '${DateTime.now().millisecondsSinceEpoch}$walletAddress',
          'network': 'REEF',
        },
      );

      final response = await httpClient.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Unable to reach Alchemy Pay right now.');
      }

      final payload = jsonDecode(response.body);
      final dynamic data = payload is Map<String, dynamic>
          ? payload['data']
          : null;
      if (data is String && data.trim().isNotEmpty) {
        return Uri.parse(data);
      }

      throw Exception('Alchemy Pay URL was not returned.');
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
