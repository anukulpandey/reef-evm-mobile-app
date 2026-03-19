import 'token.dart';

class CreatedTokenEntry {
  const CreatedTokenEntry({
    required this.token,
    this.creatorAddress,
    this.createdAt,
  });

  final Token token;
  final String? creatorAddress;
  final DateTime? createdAt;

  bool matchesCreator(String? address) {
    final normalizedCreator = creatorAddress?.trim().toLowerCase();
    final normalizedAddress = address?.trim().toLowerCase();
    if (normalizedCreator == null || normalizedCreator.isEmpty) return false;
    if (normalizedAddress == null || normalizedAddress.isEmpty) return false;
    return normalizedCreator == normalizedAddress;
  }
}
