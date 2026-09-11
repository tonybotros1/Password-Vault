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

class VaultRecoveryInfo {
  const VaultRecoveryInfo({required this.email, required this.userId});

  final String email;
  final String userId;
}

class VaultStore {
  VaultStore({this.baseDirectory, this.iterations = defaultIterations});

  static const int currentVersion = 2;
  static const int _legacyVersion = 1;
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

  Future<VaultRecoveryInfo?> getRecoveryInfo() async {
    final file = await _localVaultFile;
    if (!await file.exists()) {
      return null;
    }

    final recovery = _readEnvelope(await file.readAsString()).recovery;
    if (recovery == null) {
      return null;
    }

    return VaultRecoveryInfo(email: recovery.email, userId: recovery.userId);
  }

  List<int> createRecoveryKey() => _randomBytes(32);

  Future<UnlockedVault> create(String masterPassword) async {
    _requireUsablePassword(masterPassword);

    final salt = _randomBytes(24);
    final passwordKey = await _deriveKey(
      masterPassword: masterPassword,
      salt: salt,
      iterations: iterations,
    );
    final secretKey = SecretKey(_randomBytes(32));
    final emptyData = const VaultData();
    final envelope = VaultEnvelope(
      version: currentVersion,
      iterations: iterations,
      salt: base64Encode(salt),
      wrappedVaultKey: await _encryptBytes(
        await secretKey.extractBytes(),
        passwordKey,
      ),
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
    final passwordKey = await _deriveKey(
      masterPassword: newMasterPassword,
      salt: salt,
      iterations: iterations,
    );

    final secretKey = session.envelope.version == _legacyVersion
        ? SecretKey(_randomBytes(32))
        : session.secretKey;

    session.secretKey = secretKey;
    session.envelope = VaultEnvelope(
      version: currentVersion,
      iterations: iterations,
      salt: base64Encode(salt),
      wrappedVaultKey: await _encryptBytes(
        await secretKey.extractBytes(),
        passwordKey,
      ),
      check: await _encryptText(_checkValue, secretKey),
      vault: await _encryptVaultData(session.data, secretKey),
      recovery: session.envelope.recovery,
    );

    await save(session);
  }

  Future<void> enableEmailRecovery({
    required UnlockedVault session,
    required String email,
    required String userId,
    required List<int> recoveryKey,
  }) async {
    if (recoveryKey.length != 32) {
      throw const VaultStoreException('The email recovery key is not valid.');
    }

    final previousEnvelope = session.envelope;
    final vaultKey = previousEnvelope.version == _legacyVersion
        ? SecretKey(_randomBytes(32))
        : session.secretKey;
    final passwordWrappedKey = previousEnvelope.version == _legacyVersion
        ? await _encryptBytes(await vaultKey.extractBytes(), session.secretKey)
        : previousEnvelope.wrappedVaultKey!;
    final normalizedEmail = email.trim().toLowerCase();

    session.secretKey = vaultKey;
    session.envelope = VaultEnvelope(
      version: currentVersion,
      iterations: previousEnvelope.iterations,
      salt: previousEnvelope.salt,
      wrappedVaultKey: passwordWrappedKey,
      check: await _encryptText(_checkValue, vaultKey),
      vault: await _encryptVaultData(session.data, vaultKey),
      recovery: VaultRecovery(
        email: normalizedEmail,
        userId: userId,
        wrappedVaultKey: await _encryptBytes(
          await vaultKey.extractBytes(),
          SecretKey(recoveryKey),
        ),
      ),
    );

    await save(session);
  }

  Future<UnlockedVault> recoverWithEmail({
    required String userId,
    required List<int> recoveryKey,
    required String newMasterPassword,
  }) async {
    _requireUsablePassword(newMasterPassword);
    if (recoveryKey.length != 32) {
      throw const VaultAuthException('The email recovery key is not valid.');
    }

    final file = await _localVaultFile;
    if (!await file.exists()) {
      throw const VaultStoreException('No local vault exists yet.');
    }

    final envelope = _readEnvelope(await file.readAsString());
    final recovery = envelope.recovery;
    if (recovery == null || recovery.userId != userId) {
      throw const VaultAuthException(
        'This recovery link does not match this vault.',
      );
    }

    try {
      final vaultKeyBytes = await _decryptPayload(
        recovery.wrappedVaultKey,
        SecretKey(recoveryKey),
      );
      if (vaultKeyBytes.length != 32) {
        throw const VaultAuthException('The email recovery key is not valid.');
      }

      final vaultKey = SecretKey(vaultKeyBytes);
      final data = await _decryptVaultData(envelope, vaultKey);
      final salt = _randomBytes(24);
      final passwordKey = await _deriveKey(
        masterPassword: newMasterPassword,
        salt: salt,
        iterations: iterations,
      );
      final updatedEnvelope = VaultEnvelope(
        version: currentVersion,
        iterations: iterations,
        salt: base64Encode(salt),
        wrappedVaultKey: await _encryptBytes(vaultKeyBytes, passwordKey),
        check: await _encryptText(_checkValue, vaultKey),
        vault: await _encryptVaultData(data, vaultKey),
        recovery: recovery,
      );
      final session = UnlockedVault(
        envelope: updatedEnvelope,
        secretKey: vaultKey,
        data: data,
      );
      await save(session);
      return session;
    } on VaultAuthException {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const VaultAuthException('The email recovery key is not valid.');
    } on FormatException {
      throw const VaultStoreException('The vault file is damaged.');
    }
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
      final passwordKey = await _deriveKey(
        masterPassword: masterPassword,
        salt: base64Decode(envelope.salt),
        iterations: envelope.iterations,
      );

      final SecretKey secretKey;
      if (envelope.version == _legacyVersion) {
        secretKey = passwordKey;
      } else {
        final wrappedVaultKey = envelope.wrappedVaultKey;
        if (wrappedVaultKey == null) {
          throw const VaultStoreException('The vault key is missing.');
        }
        final keyBytes = await _decryptPayload(wrappedVaultKey, passwordKey);
        if (keyBytes.length != 32) {
          throw const VaultAuthException('The master password is incorrect.');
        }
        secretKey = SecretKey(keyBytes);
      }

      final data = await _decryptVaultData(envelope, secretKey);

      return UnlockedVault(
        envelope: envelope,
        secretKey: secretKey,
        data: data,
      );
    } on VaultAuthException {
      rethrow;
    } on FormatException {
      throw const VaultStoreException('The vault file is damaged.');
    } on SecretBoxAuthenticationError {
      throw const VaultAuthException('The master password is incorrect.');
    }
  }

  Future<VaultData> _decryptVaultData(
    VaultEnvelope envelope,
    SecretKey secretKey,
  ) async {
    final checkBytes = await _decryptPayload(envelope.check, secretKey);
    if (utf8.decode(checkBytes) != _checkValue) {
      throw const VaultAuthException('The vault encryption key is incorrect.');
    }

    final vaultBytes = await _decryptPayload(envelope.vault, secretKey);
    final decoded = jsonDecode(utf8.decode(vaultBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const VaultStoreException('The vault data is not readable.');
    }

    return VaultData.fromJson(decoded);
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

  Future<EncryptedPayload> _encryptBytes(
    List<int> bytes,
    SecretKey secretKey,
  ) async {
    final box = await _cipher.encrypt(
      bytes,
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
    this.wrappedVaultKey,
    this.recovery,
  });

  factory VaultEnvelope.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final iterations = json['iterations'];
    final salt = json['salt'];
    final check = json['check'];
    final vault = json['vault'];
    final wrappedVaultKey = json['wrappedVaultKey'];
    final recovery = json['recovery'];

    if ((version != VaultStore._legacyVersion &&
            version != VaultStore.currentVersion) ||
        iterations is! int ||
        salt is! String ||
        check is! Map<String, dynamic> ||
        vault is! Map<String, dynamic> ||
        (version == VaultStore.currentVersion &&
            wrappedVaultKey is! Map<String, dynamic>) ||
        (recovery != null && recovery is! Map<String, dynamic>)) {
      throw const VaultStoreException('This vault format is not supported.');
    }

    return VaultEnvelope(
      version: version,
      iterations: iterations,
      salt: salt,
      check: EncryptedPayload.fromJson(check),
      vault: EncryptedPayload.fromJson(vault),
      wrappedVaultKey: wrappedVaultKey is Map<String, dynamic>
          ? EncryptedPayload.fromJson(wrappedVaultKey)
          : null,
      recovery: recovery is Map<String, dynamic>
          ? VaultRecovery.fromJson(recovery)
          : null,
    );
  }

  final int version;
  final int iterations;
  final String salt;
  final EncryptedPayload check;
  final EncryptedPayload vault;
  final EncryptedPayload? wrappedVaultKey;
  final VaultRecovery? recovery;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'iterations': iterations,
      'salt': salt,
      'check': check.toJson(),
      'vault': vault.toJson(),
      if (wrappedVaultKey != null) 'wrappedVaultKey': wrappedVaultKey!.toJson(),
      if (recovery != null) 'recovery': recovery!.toJson(),
    };
  }

  VaultEnvelope copyWith({EncryptedPayload? check, EncryptedPayload? vault}) {
    return VaultEnvelope(
      version: version,
      iterations: iterations,
      salt: salt,
      check: check ?? this.check,
      vault: vault ?? this.vault,
      wrappedVaultKey: wrappedVaultKey,
      recovery: recovery,
    );
  }
}

class VaultRecovery {
  const VaultRecovery({
    required this.email,
    required this.userId,
    required this.wrappedVaultKey,
  });

  factory VaultRecovery.fromJson(Map<String, dynamic> json) {
    final email = json['email'];
    final userId = json['userId'];
    final wrappedVaultKey = json['wrappedVaultKey'];
    if (email is! String ||
        userId is! String ||
        wrappedVaultKey is! Map<String, dynamic>) {
      throw const VaultStoreException('The email recovery data is incomplete.');
    }

    return VaultRecovery(
      email: email,
      userId: userId,
      wrappedVaultKey: EncryptedPayload.fromJson(wrappedVaultKey),
    );
  }

  final String email;
  final String userId;
  final EncryptedPayload wrappedVaultKey;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'userId': userId,
      'wrappedVaultKey': wrappedVaultKey.toJson(),
    };
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
