class Account {
  final String address;
  final String
  privateKey; // Only kept in memory briefly if needed, mostly stored securely
  final String mnemonic; // Only for display on backup

  Account({
    required this.address,
    required this.privateKey,
    this.mnemonic = '',
  });
}
