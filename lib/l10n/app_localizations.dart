import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return localizations ?? AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('it'),
  ];

  String _get(String key) {
    final lang = locale.languageCode.toLowerCase();
    final forLang = _localizedValues[lang] ?? _localizedValues['en']!;
    return forLang[key] ?? _localizedValues['en']![key] ?? key;
  }

  String get home => _get('home');
  String get wallet => _get('wallet');
  String get pools => _get('pools');
  String get settings => _get('settings');
  String get tokens => _get('tokens');
  String get nfts => _get('nfts');
  String get activity => _get('activity');
  String get myAccount => _get('myAccount');
  String get buyReef => _get('buyReef');
  String get add => _get('add');
  String get addAccount => _get('addAccount');
  String get noAccountAvailable => _get('noAccountAvailable');
  String get noTokensFound => _get('noTokensFound');
  String get noNftsFound => _get('noNftsFound');
  String get noTransactionsYet => _get('noTransactionsYet');
  String get balanceTitle => _get('balanceTitle');
  String get priceLabel => _get('priceLabel');
  String get send => _get('send');
  String get transferFailed => _get('transferFailed');
  String get goHomeOnSwitch => _get('goHomeOnSwitch');
  String get biometricAuth => _get('biometricAuth');
  String get changePassword => _get('changePassword');
  String get selectLanguage => _get('selectLanguage');
  String get developerSettings => _get('developerSettings');
  String get editRpc => _get('editRpc');
  String get rpcEndpoint => _get('rpcEndpoint');
  String get cancel => _get('cancel');
  String get save => _get('save');
  String get languageEnglish => _get('languageEnglish');
  String get languageHindi => _get('languageHindi');
  String get languageItalian => _get('languageItalian');
  String get changeLanguage => _get('changeLanguage');
  String get sendToken => _get('sendToken');
  String get recipientAddress => _get('recipientAddress');
  String get amount => _get('amount');
  String get transactionSubmitted => _get('transactionSubmitted');
  String get invalidAddressOrAmount => _get('invalidAddressOrAmount');
  String get scanQr => _get('scanQr');
  String get stopScan => _get('stopScan');
  String get scannedUri => _get('scannedUri');
  String get copied => _get('copied');
  String get setPassword => _get('setPassword');
  String get newPassword => _get('newPassword');
  String get confirmPassword => _get('confirmPassword');
  String get enterAppPassword => _get('enterAppPassword');
  String get invalidPassword => _get('invalidPassword');
  String get passwordMismatch => _get('passwordMismatch');
  String get passwordSaved => _get('passwordSaved');
  String get initialisingApp => _get('initialisingApp');
  String get appLocked => _get('appLocked');
  String get unlock => _get('unlock');
  String get selected => _get('selected');
  String get addressLabel => _get('addressLabel');
  String get selectAccount => _get('selectAccount');
  String get copyEvmAddress => _get('copyEvmAddress');
  String get renameAccount => _get('renameAccount');
  String get renameAccountTitle => _get('renameAccountTitle');
  String get accountNameLabel => _get('accountNameLabel');
  String get availableAccounts => _get('availableAccounts');
  String get accountSelected => _get('accountSelected');
  String get evmAddressCopied => _get('evmAddressCopied');
  String get accountRenamed => _get('accountRenamed');
  String get setPasswordBeforeExport => _get('setPasswordBeforeExport');
  String get sortByBalance => _get('sortByBalance');
  String get defaultOrder => _get('defaultOrder');
  String get balanceHighToLow => _get('balanceHighToLow');
  String get balanceLowToHigh => _get('balanceLowToHigh');
  String get deleteAccount => _get('deleteAccount');
  String get deleteAccountConfirm => _get('deleteAccountConfirm');
  String get deleteLabel => _get('deleteLabel');
  String get exportAccount => _get('exportAccount');
  String get exportMnemonic => _get('exportMnemonic');
  String get exportPrivateKey => _get('exportPrivateKey');
  String get mnemonicCopiedForExport => _get('mnemonicCopiedForExport');
  String get privateKeyCopiedForExport => _get('privateKeyCopiedForExport');
  String get noMnemonicAvailable => _get('noMnemonicAvailable');
  String get tokenPools => _get('tokenPools');
  String get errorPrefix => _get('errorPrefix');
  String get tvlLabel => _get('tvlLabel');
  String get volume24hLabel => _get('volume24hLabel');
  String get addAccountTitle => _get('addAccountTitle');
  String get createNew => _get('createNew');
  String get importRecoveryPhrase => _get('importRecoveryPhrase');
  String get importPrivateKey => _get('importPrivateKey');
  String get failedToCreateAccount => _get('failedToCreateAccount');
  String get generatedRecoveryPhrase => _get('generatedRecoveryPhrase');
  String get copyToClipboard => _get('copyToClipboard');
  String get recoveryPhraseWarning => _get('recoveryPhraseWarning');
  String get savedRecoveryPhrase => _get('savedRecoveryPhrase');
  String get nextStep => _get('nextStep');
  String get descriptiveAccountName => _get('descriptiveAccountName');
  String get enableBiometricAuthentication =>
      _get('enableBiometricAuthentication');
  String get passwordForReefApp => _get('passwordForReefApp');
  String get repeatPasswordForVerification =>
      _get('repeatPasswordForVerification');
  String get importFromPhrase => _get('importFromPhrase');
  String get importFromPrivateKey => _get('importFromPrivateKey');
  String get enterMnemonicPhrase => _get('enterMnemonicPhrase');
  String get enterPrivateKey => _get('enterPrivateKey');
  String get importLabel => _get('importLabel');
  String get addressCopied => _get('addressCopied');
  String get recoveryPhraseCopied => _get('recoveryPhraseCopied');
  String get noName => _get('noName');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const Map<String, Map<String, String>>
_localizedValues = <String, Map<String, String>>{
  'en': <String, String>{
    'home': 'Home',
    'wallet': 'Wallet',
    'pools': 'Pools',
    'settings': 'Settings',
    'tokens': 'Tokens',
    'nfts': 'NFTs',
    'activity': 'Activity',
    'myAccount': 'My Account',
    'buyReef': 'Buy Reef',
    'add': 'Add',
    'addAccount': 'Add Account',
    'noAccountAvailable':
        'No account currently available, create or import an account to view your assets.',
    'noTokensFound': 'No tokens found',
    'noNftsFound': 'No NFTs found',
    'noTransactionsYet': 'No transactions yet',
    'balanceTitle': 'Balance',
    'priceLabel': 'Price: \$0.00',
    'send': 'SEND',
    'transferFailed': 'Transfer failed',
    'goHomeOnSwitch': 'Go to Home on Account Switch',
    'biometricAuth': 'Biometric Authentication',
    'changePassword': 'Change Password',
    'selectLanguage': 'Select Language',
    'developerSettings': 'Developer Settings',
    'editRpc': 'Edit RPC',
    'rpcEndpoint': 'RPC Endpoint',
    'cancel': 'Cancel',
    'save': 'Save',
    'languageEnglish': 'English',
    'languageHindi': 'Hindi',
    'languageItalian': 'Italian',
    'changeLanguage': 'Change Language',
    'sendToken': 'Send Token',
    'recipientAddress': 'Recipient Address',
    'amount': 'Amount',
    'transactionSubmitted': 'Transaction submitted',
    'invalidAddressOrAmount': 'Enter a valid address and amount',
    'scanQr': 'Scan QR',
    'stopScan': 'Stop Scan',
    'scannedUri': 'Scanned URI',
    'copied': 'Copied',
    'setPassword': 'Set App Password',
    'newPassword': 'New Password',
    'confirmPassword': 'Confirm Password',
    'enterAppPassword': 'Enter App Password',
    'invalidPassword': 'Invalid password',
    'passwordMismatch': 'Passwords do not match',
    'passwordSaved': 'Password saved',
    'initialisingApp': 'Initializing app',
    'appLocked': 'App is Locked',
    'unlock': 'Unlock',
    'selected': 'Selected',
    'addressLabel': 'Address',
    'selectAccount': 'Select Account',
    'copyEvmAddress': 'Copy Address',
    'renameAccount': 'Rename Account',
    'renameAccountTitle': 'Rename Account',
    'accountNameLabel': 'Account Name',
    'availableAccounts': 'Available',
    'accountSelected': 'Account selected',
    'evmAddressCopied': 'EVM address copied',
    'accountRenamed': 'Account renamed',
    'setPasswordBeforeExport':
        'Set an app password in Settings before exporting an account.',
    'sortByBalance': 'Sort Accounts',
    'defaultOrder': 'Default Order',
    'balanceHighToLow': 'Balance: High to Low',
    'balanceLowToHigh': 'Balance: Low to High',
    'deleteAccount': 'Delete account',
    'deleteAccountConfirm': 'This will clear the currently active account.',
    'deleteLabel': 'Delete',
    'exportAccount': 'Export Account',
    'exportMnemonic': 'Export Mnemonic',
    'exportPrivateKey': 'Export Private Key',
    'mnemonicCopiedForExport': 'Mnemonic copied for export',
    'privateKeyCopiedForExport': 'Private key copied for export',
    'noMnemonicAvailable': 'No mnemonic found for this account',
    'tokenPools': 'Token Pools',
    'errorPrefix': 'Error',
    'tvlLabel': 'TVL',
    'volume24hLabel': '24h Vol.',
    'addAccountTitle': 'Add Account',
    'createNew': 'Create new',
    'importRecoveryPhrase': 'Import recovery phrase',
    'importPrivateKey': 'Import private key',
    'failedToCreateAccount': 'Failed to create account',
    'generatedRecoveryPhrase': 'GENERATED 12-WORD RECOVERY PHRASE (MNEMONIC):',
    'copyToClipboard': 'Copy to clipboard',
    'recoveryPhraseWarning':
        'Please write down your wallet\'s mnemonic seed and keep it in a safe place. The mnemonic can be used to restore your wallet. Keep it carefully to not lose your assets.',
    'savedRecoveryPhrase':
        'I have saved my recovery phrase (mnemonic/seed) safely.',
    'nextStep': 'Next Step',
    'descriptiveAccountName': 'A DESCRIPTIVE NAME FOR YOUR ACCOUNT',
    'enableBiometricAuthentication': 'Enable Biometric authentication',
    'passwordForReefApp': 'A PASSWORD FOR REEF APP',
    'repeatPasswordForVerification': 'REPEAT PASSWORD FOR VERIFICATION',
    'importFromPhrase': 'Import from Phrase',
    'importFromPrivateKey': 'Import from Private Key',
    'enterMnemonicPhrase': 'Enter mnemonic phrase...',
    'enterPrivateKey': 'Enter private key...',
    'importLabel': 'Import',
    'addressCopied': 'Address copied',
    'recoveryPhraseCopied': 'Recovery phrase copied',
    'noName': '<No Name>',
  },
  'hi': <String, String>{
    'home': 'होम',
    'wallet': 'वॉलेट',
    'pools': 'पूल्स',
    'settings': 'सेटिंग्स',
    'tokens': 'टोकन',
    'nfts': 'NFTs',
    'activity': 'एक्टिविटी',
    'myAccount': 'मेरा अकाउंट',
    'buyReef': 'रीफ खरीदें',
    'add': 'जोड़ें',
    'addAccount': 'अकाउंट जोड़ें',
    'noAccountAvailable':
        'अभी कोई अकाउंट उपलब्ध नहीं है, अपनी संपत्ति देखने के लिए अकाउंट बनाएं या इंपोर्ट करें।',
    'noTokensFound': 'कोई टोकन नहीं मिला',
    'noNftsFound': 'कोई NFT नहीं मिला',
    'noTransactionsYet': 'अभी तक कोई ट्रांजैक्शन नहीं है',
    'balanceTitle': 'बैलेंस',
    'priceLabel': 'कीमत: \$0.00',
    'send': 'भेजें',
    'transferFailed': 'ट्रांसफर विफल',
    'goHomeOnSwitch': 'अकाउंट बदलने पर होम पर जाएं',
    'biometricAuth': 'बायोमेट्रिक प्रमाणीकरण',
    'changePassword': 'पासवर्ड बदलें',
    'selectLanguage': 'भाषा चुनें',
    'developerSettings': 'डेवलपर सेटिंग्स',
    'editRpc': 'RPC बदलें',
    'rpcEndpoint': 'RPC एंडपॉइंट',
    'cancel': 'रद्द करें',
    'save': 'सेव करें',
    'languageEnglish': 'अंग्रेज़ी',
    'languageHindi': 'हिंदी',
    'languageItalian': 'इटैलियन',
    'changeLanguage': 'भाषा बदलें',
    'sendToken': 'टोकन भेजें',
    'recipientAddress': 'प्राप्तकर्ता पता',
    'amount': 'राशि',
    'transactionSubmitted': 'ट्रांजैक्शन भेजा गया',
    'invalidAddressOrAmount': 'सही पता और राशि दर्ज करें',
    'scanQr': 'QR स्कैन करें',
    'stopScan': 'स्कैन रोकें',
    'scannedUri': 'स्कैन किया गया URI',
    'copied': 'कॉपी किया गया',
    'setPassword': 'ऐप पासवर्ड सेट करें',
    'newPassword': 'नया पासवर्ड',
    'confirmPassword': 'पासवर्ड की पुष्टि करें',
    'enterAppPassword': 'ऐप पासवर्ड दर्ज करें',
    'invalidPassword': 'गलत पासवर्ड',
    'passwordMismatch': 'पासवर्ड मेल नहीं खाते',
    'passwordSaved': 'पासवर्ड सेव हो गया',
    'initialisingApp': 'ऐप शुरू हो रहा है',
    'appLocked': 'ऐप लॉक है',
    'unlock': 'अनलॉक',
    'selected': 'चयनित',
    'addressLabel': 'पता',
    'selectAccount': 'अकाउंट चुनें',
    'copyEvmAddress': 'पता कॉपी करें',
    'renameAccount': 'अकाउंट का नाम बदलें',
    'renameAccountTitle': 'अकाउंट का नाम बदलें',
    'accountNameLabel': 'अकाउंट नाम',
    'availableAccounts': 'उपलब्ध',
    'accountSelected': 'अकाउंट चुना गया',
    'evmAddressCopied': 'EVM पता कॉपी हुआ',
    'accountRenamed': 'अकाउंट का नाम बदल गया',
    'setPasswordBeforeExport':
        'अकाउंट एक्सपोर्ट करने से पहले सेटिंग्स में ऐप पासवर्ड सेट करें।',
    'sortByBalance': 'अकाउंट सॉर्ट करें',
    'defaultOrder': 'डिफ़ॉल्ट क्रम',
    'balanceHighToLow': 'बैलेंस: ज़्यादा से कम',
    'balanceLowToHigh': 'बैलेंस: कम से ज़्यादा',
    'deleteAccount': 'अकाउंट हटाएं',
    'deleteAccountConfirm': 'यह वर्तमान सक्रिय अकाउंट को हटा देगा।',
    'deleteLabel': 'हटाएं',
    'exportAccount': 'अकाउंट एक्सपोर्ट करें',
    'exportMnemonic': 'म्नेमोनिक एक्सपोर्ट करें',
    'exportPrivateKey': 'प्राइवेट की एक्सपोर्ट करें',
    'mnemonicCopiedForExport': 'एक्सपोर्ट के लिए म्नेमोनिक कॉपी हुआ',
    'privateKeyCopiedForExport': 'एक्सपोर्ट के लिए प्राइवेट की कॉपी हुई',
    'noMnemonicAvailable': 'इस अकाउंट के लिए म्नेमोनिक उपलब्ध नहीं है',
    'tokenPools': 'टोकन पूल',
    'errorPrefix': 'त्रुटि',
    'tvlLabel': 'TVL',
    'volume24hLabel': '24h वॉल्यूम',
    'addAccountTitle': 'अकाउंट जोड़ें',
    'createNew': 'नया बनाएं',
    'importRecoveryPhrase': 'रिकवरी फ़्रेज़ इंपोर्ट करें',
    'importPrivateKey': 'प्राइवेट की इंपोर्ट करें',
    'failedToCreateAccount': 'अकाउंट बनाना विफल रहा',
    'generatedRecoveryPhrase': 'उत्पन्न 12-शब्द रिकवरी फ़्रेज़ (MNEMONIC):',
    'copyToClipboard': 'क्लिपबोर्ड में कॉपी करें',
    'recoveryPhraseWarning':
        'कृपया अपने वॉलेट का म्नेमोनिक सीड लिखकर सुरक्षित रखें। इसे वॉलेट बहाल करने के लिए उपयोग किया जा सकता है।',
    'savedRecoveryPhrase':
        'मैंने अपना रिकवरी फ़्रेज़ (mnemonic/seed) सुरक्षित रूप से सेव कर लिया है।',
    'nextStep': 'अगला कदम',
    'descriptiveAccountName': 'अपने अकाउंट के लिए एक वर्णनात्मक नाम',
    'enableBiometricAuthentication': 'बायोमेट्रिक प्रमाणीकरण सक्षम करें',
    'passwordForReefApp': 'रीफ ऐप के लिए पासवर्ड',
    'repeatPasswordForVerification': 'सत्यापन के लिए पासवर्ड दोहराएं',
    'importFromPhrase': 'फ़्रेज़ से इंपोर्ट करें',
    'importFromPrivateKey': 'प्राइवेट की से इंपोर्ट करें',
    'enterMnemonicPhrase': 'म्नेमोनिक फ़्रेज़ दर्ज करें...',
    'enterPrivateKey': 'प्राइवेट की दर्ज करें...',
    'importLabel': 'इंपोर्ट',
    'addressCopied': 'पता कॉपी हुआ',
    'recoveryPhraseCopied': 'रिकवरी फ़्रेज़ कॉपी हुआ',
    'noName': '<कोई नाम नहीं>',
  },
  'it': <String, String>{
    'home': 'Home',
    'wallet': 'Portafoglio',
    'pools': 'Pool',
    'settings': 'Impostazioni',
    'tokens': 'Token',
    'nfts': 'NFT',
    'activity': 'Attività',
    'myAccount': 'Il Mio Account',
    'buyReef': 'Compra Reef',
    'add': 'Aggiungi',
    'addAccount': 'Aggiungi Account',
    'noAccountAvailable':
        'Nessun account disponibile, crea o importa un account per vedere i tuoi asset.',
    'noTokensFound': 'Nessun token trovato',
    'noNftsFound': 'Nessun NFT trovato',
    'noTransactionsYet': 'Nessuna transazione ancora',
    'balanceTitle': 'Saldo',
    'priceLabel': 'Prezzo: \$0.00',
    'send': 'INVIA',
    'transferFailed': 'Trasferimento fallito',
    'goHomeOnSwitch': 'Vai alla Home al cambio account',
    'biometricAuth': 'Autenticazione Biomentrica',
    'changePassword': 'Cambia Password',
    'selectLanguage': 'Seleziona Lingua',
    'developerSettings': 'Impostazioni Sviluppatore',
    'editRpc': 'Modifica RPC',
    'rpcEndpoint': 'Endpoint RPC',
    'cancel': 'Annulla',
    'save': 'Salva',
    'languageEnglish': 'Inglese',
    'languageHindi': 'Hindi',
    'languageItalian': 'Italiano',
    'changeLanguage': 'Cambia Lingua',
    'sendToken': 'Invia Token',
    'recipientAddress': 'Indirizzo Destinatario',
    'amount': 'Importo',
    'transactionSubmitted': 'Transazione inviata',
    'invalidAddressOrAmount': 'Inserisci indirizzo e importo validi',
    'scanQr': 'Scansiona QR',
    'stopScan': 'Ferma Scansione',
    'scannedUri': 'URI Scansionato',
    'copied': 'Copiato',
    'setPassword': 'Imposta Password App',
    'newPassword': 'Nuova Password',
    'confirmPassword': 'Conferma Password',
    'enterAppPassword': 'Inserisci Password App',
    'invalidPassword': 'Password non valida',
    'passwordMismatch': 'Le password non coincidono',
    'passwordSaved': 'Password salvata',
    'initialisingApp': 'Inizializzazione app',
    'appLocked': 'App bloccata',
    'unlock': 'Sblocca',
    'selected': 'Selezionato',
    'addressLabel': 'Indirizzo',
    'selectAccount': 'Seleziona Account',
    'copyEvmAddress': 'Copia Indirizzo',
    'renameAccount': 'Rinomina Account',
    'renameAccountTitle': 'Rinomina Account',
    'accountNameLabel': 'Nome Account',
    'availableAccounts': 'Disponibili',
    'accountSelected': 'Account selezionato',
    'evmAddressCopied': 'Indirizzo EVM copiato',
    'accountRenamed': 'Account rinominato',
    'setPasswordBeforeExport':
        'Imposta una password app nelle Impostazioni prima di esportare un account.',
    'sortByBalance': 'Ordina Account',
    'defaultOrder': 'Ordine Predefinito',
    'balanceHighToLow': 'Saldo: Alto-Basso',
    'balanceLowToHigh': 'Saldo: Basso-Alto',
    'deleteAccount': 'Elimina account',
    'deleteAccountConfirm': 'Questo cancellerà l\'account attualmente attivo.',
    'deleteLabel': 'Elimina',
    'exportAccount': 'Esporta Account',
    'exportMnemonic': 'Esporta Mnemonic',
    'exportPrivateKey': 'Esporta Chiave Privata',
    'mnemonicCopiedForExport': 'Mnemonic copiato per l\'esportazione',
    'privateKeyCopiedForExport': 'Chiave privata copiata per l\'esportazione',
    'noMnemonicAvailable': 'Nessun mnemonic disponibile per questo account',
    'tokenPools': 'Pool Token',
    'errorPrefix': 'Errore',
    'tvlLabel': 'TVL',
    'volume24hLabel': 'Vol. 24h',
    'addAccountTitle': 'Aggiungi Account',
    'createNew': 'Crea nuovo',
    'importRecoveryPhrase': 'Importa frase di recupero',
    'importPrivateKey': 'Importa chiave privata',
    'failedToCreateAccount': 'Creazione account non riuscita',
    'generatedRecoveryPhrase':
        'FRASE DI RECUPERO DI 12 PAROLE GENERATA (MNEMONIC):',
    'copyToClipboard': 'Copia negli appunti',
    'recoveryPhraseWarning':
        'Scrivi il seed mnemonico del wallet e conservalo in un posto sicuro. Puoi usarlo per ripristinare il wallet.',
    'savedRecoveryPhrase':
        'Ho salvato in sicurezza la mia recovery phrase (mnemonic/seed).',
    'nextStep': 'Passo successivo',
    'descriptiveAccountName': 'UN NOME DESCRITTIVO PER IL TUO ACCOUNT',
    'enableBiometricAuthentication': 'Abilita autenticazione biometrica',
    'passwordForReefApp': 'UNA PASSWORD PER L\'APP REEF',
    'repeatPasswordForVerification': 'RIPETI LA PASSWORD PER LA VERIFICA',
    'importFromPhrase': 'Importa da frase',
    'importFromPrivateKey': 'Importa da chiave privata',
    'enterMnemonicPhrase': 'Inserisci frase mnemonica...',
    'enterPrivateKey': 'Inserisci chiave privata...',
    'importLabel': 'Importa',
    'addressCopied': 'Indirizzo copiato',
    'recoveryPhraseCopied': 'Recovery phrase copiata',
    'noName': '<Nessun nome>',
  },
};
