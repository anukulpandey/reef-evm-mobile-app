import 'token.dart';
import 'token_creator_request.dart';

class TokenCreationSubmission {
  const TokenCreationSubmission({
    required this.txHash,
    required this.usedFallback,
    required this.request,
    required this.creatorAddress,
  });

  final String txHash;
  final bool usedFallback;
  final TokenCreatorRequest request;
  final String creatorAddress;
}

class TokenCreationResult {
  const TokenCreationResult({
    required this.txHash,
    required this.contractAddress,
    required this.usedFallback,
    required this.token,
  });

  final String txHash;
  final String contractAddress;
  final bool usedFallback;
  final Token token;
}
