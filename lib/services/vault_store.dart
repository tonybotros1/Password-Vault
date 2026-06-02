import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../models/vault_entry.dart';

class VaultAuthException implements Exception {
  const VaultAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VaultStoreException implements Exception {
  const VaultStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UnlockedVault {
  UnlockedVault({
    required this.envelope,
    required this.secretKey,
    required this.data,
  });

  VaultEnvelope envelope;
  SecretKey secretKey;
  VaultData data;
}

class VaultStore {
  VaultStore({this.baseDirectory, this.iterations = defaultIterations});

  static const int currentVersion = 1;
  static const int defaultIterations = 210000;
  static const String _fileName = 'password_vault.pwvault';
  static const String _checkValue = 'password-vault-master-key-check-v1';

  final Directory? baseDirectory;
  final int iterations;
  final AesGcm _cipher = AesGcm.with256bits();

  Future<bool> hasVault() async {
    final file = await _localVaultFile;
    return file.exists();
  }

  Future<String> get localVaultPath async {
    final file = await _localVaultFile;
    return file.path;
  }

  Future<UnlockedVault> create(String masterPassword) async {
    _requireUsablePassword(masterPassword);

    final salt = _randomBytes(24);
    final secretKey = await _deriveKey(
      masterPassword: masterPassword,
      salt: salt,
      iterations: iterations,
    );
    final emptyData = const VaultData();
    final envelope = VaultEnvelope(
      version: currentVersion,
      iterations: iterations,
      salt: base64Encode(salt),
      check: await _encryptText(_checkValue, secretKey),
      vault: await _encryptVaultData(emptyData, secretKey),
    );
    final session = UnlockedVault(
      envelope: envelope,
      secretKey: secretKey,
      data: emptyData,
    );

    await save(session);

    return session;
  }

  Future<UnlockedVault> unlock(String masterPassword) async {
    final file = await _localVaultFile;
    if (!await file.exists()) {
      throw const VaultStoreException('No local vault exists yet.');
    }

    final envelope = _readEnvelope(await file.readAsString());
    return _unlockEnvelope(envelope, masterPassword);
  }

  Future<UnlockedVault> importBackup({
    required String path,
    required String masterPassword,
  }) async {
    final backupFile = File(path);
    if (!await backupFile.exists()) {
      throw const VaultStoreException(
        'The selected backup file was not found.',
      );
    }

    final envelope = _readEnvelope(await backupFile.readAsString());
    final session = await _unlockEnvelope(envelope, masterPassword);
    final localFile = await _localVaultFile;
    await localFile.writeAsString(jsonEncode(envelope.toJson()), flush: true);

    return session;
  }

  Future<void> save(UnlockedVault session) async {
    session.envelope = session.envelope.copyWith(
      vault: await _encryptVaultData(session.data, session.secretKey),
    );

    final file = await _localVaultFile;
    await file.writeAsString(
      jsonEncode(session.envelope.toJson()),
      flush: true,
    );
  }

  Future<String> exportBackup({
    required UnlockedVault session,
    required String destinationPath,
  }) async {
    await save(session);

    final normalizedPath = destinationPath.endsWith('.pwvault')
        ? destinationPath
        : '$destinationPath.pwvault';
    final localFile = await _localVaultFile;
    final backupFile = File(normalizedPath);
    await backupFile.parent.create(recursive: true);
    await localFile.copy(backupFile.path);

    return backupFile.path;
  }

  Future<bool> verifyPassword(UnlockedVault session, String password) async {
    try {
      await _unlockEnvelope(session.envelope, password);
      return true;
    } on VaultAuthException {
      return false;
    }
  }

  Future<void> changeMasterPassword({
    required UnlockedVault session,
    required String newMasterPassword,
  }) async {
    _requireUsablePassword(newMasterPassword);

    final salt = _randomBytes(24);
    final secretKey = await _deriveKey(
      masterPassword: newMasterPassword,
      salt: salt,
      iterations: iterations,
    );

    session.secretKey = secretKey;
    session.envelope = VaultEnvelope(
      version: currentVersion,
      iterations: iterations,
      salt: base64Encode(salt),
      check: await _encryptText(_checkValue, secretKey),
      vault: await _encryptVaultData(session.data, secretKey),
    );

    await save(session);
  }

  Future<File> get _localVaultFile async {
    final directory = baseDirectory ?? await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return File('${directory.path}/$_fileName');
  }

  Future<UnlockedVault> _unlockEnvelope(
    VaultEnvelope envelope,
    String masterPassword,
  ) async {
    try {
      final secretKey = await _deriveKey(
        masterPassword: masterPassword,
        salt: base64Decode(envelope.salt),
        iterations: envelope.iterations,
      );

      final checkBytes = await _decryptPayload(envelope.check, secretKey);
      if (utf8.decode(checkBytes) != _checkValue) {
        throw const VaultAuthException('The master password is incorrect.');
      }

      final vaultBytes = await _decryptPayload(envelope.vault, secretKey);
      final decoded = jsonDecode(utf8.decode(vaultBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const VaultStoreException('The vault data is not readable.');
      }

      return UnlockedVault(
        envelope: envelope,
        secretKey: secretKey,
        data: VaultData.fromJson(decoded),
      );
    } on VaultAuthException {
      rethrow;
    } on FormatException {
      throw const VaultStoreException('The vault file is damaged.');
    } on SecretBoxAuthenticationError {
      throw const VaultAuthException('The master password is incorrect.');
    }
  }

  Future<SecretKey> _deriveKey({
    required String masterPassword,
    required List<int> salt,
    required int iterations,
  }) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );

    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(masterPassword)),
      nonce: salt,
    );
  }

  Future<EncryptedPayload> _encryptText(
    String text,
    SecretKey secretKey,
  ) async {
    final box = await _cipher.encrypt(
      utf8.encode(text),
      secretKey: secretKey,
      nonce: _randomBytes(12),
    );

    return EncryptedPayload.fromSecretBox(box);
  }

  Future<EncryptedPayload> _encryptVaultData(
    VaultData data,
    SecretKey secretKey,
  ) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(data.toJson())),
      secretKey: secretKey,
      nonce: _randomBytes(12),
    );

    return EncryptedPayload.fromSecretBox(box);
  }

  Future<List<int>> _decryptPayload(
    EncryptedPayload payload,
    SecretKey secretKey,
  ) {
    return _cipher.decrypt(payload.toSecretBox(), secretKey: secretKey);
  }

  VaultEnvelope _readEnvelope(String contents) {
    try {
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic>) {
        throw const VaultStoreException('This is not a Password Vault file.');
      }

      return VaultEnvelope.fromJson(decoded);
    } on FormatException {
      throw const VaultStoreException('This is not a readable vault file.');
    }
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  void _requireUsablePassword(String password) {
    if (password.trim().length < 10) {
      throw const VaultAuthException(
        'Use at least 10 characters for the master password.',
      );
    }
  }
}

class VaultEnvelope {
  const VaultEnvelope({
    required this.version,
    required this.iterations,
    required this.salt,
    required this.check,
    required this.vault,
  });

  factory VaultEnvelope.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final iterations = json['iterations'];
    final salt = json['salt'];
    final check = json['check'];
    final vault = json['vault'];

    if (version != VaultStore.currentVersion ||
        iterations is! int ||
        salt is! String ||
        check is! Map<String, dynamic> ||
        vault is! Map<String, dynamic>) {
      throw const VaultStoreException('This vault format is not supported.');
    }

    return VaultEnvelope(
      version: version,
      iterations: iterations,
      salt: salt,
      check: EncryptedPayload.fromJson(check),
      vault: EncryptedPayload.fromJson(vault),
    );
  }

  final int version;
  final int iterations;
  final String salt;
  final EncryptedPayload check;
  final EncryptedPayload vault;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'iterations': iterations,
      'salt': salt,
      'check': check.toJson(),
      'vault': vault.toJson(),
    };
  }

  VaultEnvelope copyWith({EncryptedPayload? check, EncryptedPayload? vault}) {
    return VaultEnvelope(
      version: version,
      iterations: iterations,
      salt: salt,
      check: check ?? this.check,
      vault: vault ?? this.vault,
    );
  }
}

class EncryptedPayload {
  const EncryptedPayload({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  factory EncryptedPayload.fromSecretBox(SecretBox box) {
    return EncryptedPayload(
      nonce: base64Encode(box.nonce),
      cipherText: base64Encode(box.cipherText),
      mac: base64Encode(box.mac.bytes),
    );
  }

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) {
    final nonce = json['nonce'];
    final cipherText = json['cipherText'];
    final mac = json['mac'];

    if (nonce is! String || cipherText is! String || mac is! String) {
      throw const VaultStoreException('The encrypted payload is incomplete.');
    }

    return EncryptedPayload(nonce: nonce, cipherText: cipherText, mac: mac);
  }

  final String nonce;
  final String cipherText;
  final String mac;

  Map<String, dynamic> toJson() {
    return {'nonce': nonce, 'cipherText': cipherText, 'mac': mac};
  }

  SecretBox toSecretBox() {
    return SecretBox(
      base64Decode(cipherText),
      nonce: base64Decode(nonce),
      mac: Mac(base64Decode(mac)),
    );
  }
}
