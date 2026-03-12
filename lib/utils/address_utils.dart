class AddressUtils {
  const AddressUtils._();

  static String shorten(
    String value, {
    int prefixLength = 6,
    int suffixLength = 4,
  }) {
    final trimmed = value.trim();
    final minLength = prefixLength + suffixLength + 1;
    if (trimmed.length < minLength) return trimmed;
    return '${trimmed.substring(0, prefixLength)}...${trimmed.substring(trimmed.length - suffixLength)}';
  }
}
