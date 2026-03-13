class TransactionUiError {
  const TransactionUiError({required this.title, required this.message});

  final String title;
  final String message;
}

class TransactionErrorMapper {
  static const TransactionUiError defaultUiError = TransactionUiError(
    title: 'Transaction failed',
    message: 'Unable to process the transaction. Please try again.',
  );

  static TransactionUiError fromThrowable(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final normalized = raw.toLowerCase();
    final code = _extractCode(normalized);
    return _mapFromNormalized(normalized, code: code);
  }

  static String fromRpc({
    required int errorCode,
    required String? message,
    Object? data,
    String defaultMessage = 'Transaction rejected by network.',
  }) {
    final combined = <String>[
      if (message != null) message,
      if (data != null) data.toString(),
    ].join(' ').trim().toLowerCase();

    final uiError = _mapFromNormalized(
      combined,
      code: errorCode,
      fallback: TransactionUiError(
        title: 'Transaction failed',
        message: defaultMessage,
      ),
    );
    return uiError.message;
  }

  static TransactionUiError _mapFromNormalized(
    String normalized, {
    int? code,
    TransactionUiError fallback = defaultUiError,
  }) {
    if (normalized.contains('invalid transaction') || code == 1010) {
      return const TransactionUiError(
        title: 'Transaction failed',
        message:
            'Transaction rejected by the network. Please verify the transaction details and try again.',
      );
    }

    if (normalized.contains('invalid transaction parameters') ||
        normalized.contains('gas') ||
        normalized.contains('intrinsic') ||
        normalized.contains('out of gas') ||
        normalized.contains('underpriced') ||
        normalized.contains('fee too low') ||
        code == -32000) {
      return const TransactionUiError(
        title: 'Invalid transaction parameters',
        message:
            'Invalid transaction parameters. Adjust the transaction details and retry.',
      );
    }

    if (normalized.contains('nonce')) {
      return const TransactionUiError(
        title: 'Transaction failed',
        message: 'Transaction nonce is out of sync. Please retry.',
      );
    }

    if (normalized.contains('insufficient') ||
        normalized.contains('cannot pay fees') ||
        normalized.contains('payment')) {
      return const TransactionUiError(
        title: 'Transaction failed',
        message:
            'Insufficient balance to cover the transfer amount and network fee.',
      );
    }

    if (normalized.contains('network') ||
        normalized.contains('connection') ||
        normalized.contains('socket') ||
        normalized.contains('timeout')) {
      return const TransactionUiError(
        title: 'Unable to process the transaction',
        message:
            'Network issue while submitting the transaction. Please try again.',
      );
    }

    if (normalized.contains('user rejected') ||
        normalized.contains('signature denied') ||
        normalized.contains('denied transaction signature') ||
        normalized.contains('cancelled by user') ||
        normalized.contains('canceled by user')) {
      return const TransactionUiError(
        title: 'Transaction rejected',
        message:
            'Transaction was rejected before broadcast. No funds were sent.',
      );
    }

    return fallback;
  }

  static int? _extractCode(String text) {
    final match = RegExp(r'code[^0-9-]*(-?\d+)').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}
