class AddressValidator {
  const AddressValidator._();

  static final RegExp _evmAddressPattern = RegExp(r'^0x[a-fA-F0-9]{40}$');

  static bool isValidEvmAddress(String value) {
    return _evmAddressPattern.hasMatch(value.trim());
  }
}
