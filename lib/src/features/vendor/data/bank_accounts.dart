import 'dart:math';

/// Normalized bank account for vendor portal (stored under `bank_json`).
/// Mirrors `p4u-new-vendor-web/lib/vendor/bankAccounts.ts`.

const _accountTypes = {'savings', 'current'};

String newBankAccountId() {
  final r = Random();
  final hex = List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
  return 'acc-${DateTime.now().millisecondsSinceEpoch}-$hex';
}

/// Parse legacy flat `bankJson` or `{ version: 1, accounts: [...] }`.
List<Map<String, dynamic>> parseBankAccounts(dynamic bankJson) {
  if (bankJson == null || bankJson is! Map) return [];
  final o = Map<String, dynamic>.from(bankJson);

  final accounts = o['accounts'];
  if (accounts is List) {
    final mapped = accounts
        .whereType<Map>()
        .map((a) => _normalizeAccountRow(Map<String, dynamic>.from(a)))
        .toList();
    return _ensureSinglePrimary(mapped);
  }

  final legacyBank = _str(o['bankName'] ?? o['bank_name']);
  final legacyAcct = _str(o['accountNumber'] ?? o['account_number']);
  final legacyHolder = _str(o['accountHolderName'] ??
      o['accountHolder'] ??
      o['account_holder_name'] ??
      o['account_holder']);
  final legacyIfsc = _str(o['ifscCode'] ?? o['ifsc'] ?? o['ifsc_code']);
  final hasLegacy = legacyBank.isNotEmpty ||
      legacyAcct.isNotEmpty ||
      legacyHolder.isNotEmpty ||
      legacyIfsc.isNotEmpty;
  if (!hasLegacy) return [];

  return [
    _normalizeAccountRow({
      'id': 'legacy',
      'bankName': legacyBank,
      'accountHolderName': legacyHolder,
      'accountNumber': legacyAcct,
      'ifscCode': legacyIfsc,
      'accountType': o['accountType'] ?? o['account_type'] ?? 'savings',
      'isPrimary': true,
    }),
  ];
}

Map<String, dynamic> serializeBankAccounts(
    List<Map<String, dynamic>> accounts) {
  final normalized = _ensureSinglePrimary(accounts);
  return {
    'version': 1,
    'accounts': normalized
        .map((a) => {
              'id': a['id'],
              'bankName': a['bankName'],
              'accountHolderName': a['accountHolderName'],
              'accountNumber': a['accountNumber'],
              'ifscCode': a['ifscCode'],
              'accountType': a['accountType'],
              'isPrimary': a['isPrimary'] == true,
            })
        .toList(),
  };
}

/// UI / form maps use snake_case keys for list rows.
Map<String, dynamic> bankAccountToUiRow(Map<String, dynamic> a) => {
      'id': a['id'],
      'bank_name': a['bankName'] ?? '',
      'account_holder': a['accountHolderName'] ?? '',
      'account_holder_name': a['accountHolderName'] ?? '',
      'account_number': a['accountNumber'] ?? '',
      'ifsc_code': a['ifscCode'] ?? '',
      'account_type': a['accountType'] ?? 'savings',
      'is_primary': a['isPrimary'] == true,
    };

Map<String, dynamic> bankAccountFromForm(
  Map<String, dynamic> values, {
  required String id,
  required bool isPrimary,
}) {
  final holder = _str(values['account_holder_name'] ??
      values['account_holder'] ??
      values['bank_holder_name'] ??
      values['accountHolderName']);
  final number = _str(values['account_number'] ??
          values['bank_account_number'] ??
          values['accountNumber'])
      .replaceAll(RegExp(r'\s'), '');
  final ifsc = _str(
          values['ifsc_code'] ?? values['bank_ifsc'] ?? values['ifscCode'])
      .toUpperCase();
  var type = _str(values['account_type'] ?? values['accountType'] ?? 'savings')
      .toLowerCase();
  if (!_accountTypes.contains(type)) type = 'savings';
  return {
    'id': id,
    'bankName':
        _str(values['bank_name'] ?? values['bankName']).trim(),
    'accountHolderName': holder.trim(),
    'accountNumber': number,
    'ifscCode': ifsc,
    'accountType': type,
    'isPrimary': isPrimary,
  };
}

Map<String, dynamic> _normalizeAccountRow(Map<String, dynamic> a) {
  final idRaw = a['id']?.toString().trim() ?? '';
  final id = idRaw.isNotEmpty ? idRaw : newBankAccountId();
  var accountType =
      _str(a['accountType'] ?? a['account_type'] ?? 'savings').toLowerCase();
  if (!_accountTypes.contains(accountType)) accountType = 'savings';
  return {
    'id': id,
    'bankName': _str(a['bankName'] ?? a['bank_name']),
    'accountHolderName': _str(a['accountHolderName'] ??
        a['accountHolder'] ??
        a['account_holder_name'] ??
        a['account_holder']),
    'accountNumber':
        _str(a['accountNumber'] ?? a['account_number']),
    'ifscCode':
        _str(a['ifscCode'] ?? a['ifsc'] ?? a['ifsc_code']).toUpperCase(),
    'accountType': accountType,
    'isPrimary': a['isPrimary'] == true || a['is_primary'] == true,
  };
}

List<Map<String, dynamic>> _ensureSinglePrimary(
    List<Map<String, dynamic>> accounts) {
  if (accounts.isEmpty) return [];
  final primaryIdx = accounts.indexWhere((a) => a['isPrimary'] == true);
  final idx = primaryIdx >= 0 ? primaryIdx : 0;
  return [
    for (var i = 0; i < accounts.length; i++)
      {...accounts[i], 'isPrimary': i == idx},
  ];
}

String _str(dynamic v) => v?.toString().trim() ?? '';
