import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_vault/models/vault_entry.dart';
import 'package:password_vault/services/vault_store.dart';

void main() {
  test('vault store encrypts, unlocks, and imports backups', () async {
    final primaryDirectory = await Directory.systemTemp.createTemp(
      'password_vault_primary_',
    );
    final importedDirectory = await Directory.systemTemp.createTemp(
      'password_vault_imported_',
    );
    addTearDown(() async {
      await primaryDirectory.delete(recursive: true);
      await importedDirectory.delete(recursive: true);
    });

    final store = VaultStore(baseDirectory: primaryDirectory, iterations: 1000);
    final session = await store.create('master password');
    final entry = VaultEntry.blank().copyWith(
      title: 'Bank',
      username: 'paul',
      password: 'private-password',
      updatedAt: DateTime(2026, 6, 3),
    );

    session.data = session.data.upsert(entry);
    await store.save(session);

    final rawVault = await File(await store.localVaultPath).readAsString();
    expect(rawVault.contains('private-password'), isFalse);

    final unlocked = await store.unlock('master password');
    expect(unlocked.data.entries.single.password, 'private-password');
    expect(
      () => store.unlock('wrong password'),
      throwsA(isA<VaultAuthException>()),
    );

    final backupPath = '${primaryDirectory.path}/backup.pwvault';
    await store.exportBackup(session: unlocked, destinationPath: backupPath);

    final importedStore = VaultStore(
      baseDirectory: importedDirectory,
      iterations: 1000,
    );
    final imported = await importedStore.importBackup(
      path: backupPath,
      masterPassword: 'master password',
    );

    expect(imported.data.entries.single.title, 'Bank');
  });

  test(
    'verified email recovery resets the password without losing data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'password_vault_recovery_',
      );
      addTearDown(() async => directory.delete(recursive: true));

      final store = VaultStore(baseDirectory: directory, iterations: 1000);
      final session = await store.create('original master');
      session.data = session.data.upsert(
        VaultEntry.blank().copyWith(
          title: 'Email account',
          password: 'saved secret',
        ),
      );
      await store.save(session);

      final recoveryKey = List<int>.generate(32, (index) => index);
      await store.enableEmailRecovery(
        session: session,
        email: 'Owner@Example.com',
        userId: 'verified-user-id',
        recoveryKey: recoveryKey,
      );

      final recoveryInfo = await store.getRecoveryInfo();
      expect(recoveryInfo?.email, 'owner@example.com');
      expect(recoveryInfo?.userId, 'verified-user-id');
      expect(
        (await store.unlock('original master')).data.entries,
        hasLength(1),
      );

      final recovered = await store.recoverWithEmail(
        userId: 'verified-user-id',
        recoveryKey: recoveryKey,
        newMasterPassword: 'replacement master',
      );

      expect(recovered.data.entries.single.password, 'saved secret');
      expect(
        () => store.unlock('original master'),
        throwsA(isA<VaultAuthException>()),
      );
      expect(
        (await store.unlock('replacement master')).data.entries.single.title,
        'Email account',
      );
    },
  );

  test('a version 1 vault upgrades to recovery without data loss', () async {
    final directory = await Directory.systemTemp.createTemp(
      'password_vault_legacy_',
    );
    addTearDown(() async => directory.delete(recursive: true));

    const password = 'legacy master';
    const iterations = 1000;
    final salt = List<int>.generate(24, (index) => index + 1);
    final passwordKey = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    final cipher = AesGcm.with256bits();
    final checkBox = await cipher.encrypt(
      utf8.encode('password-vault-master-key-check-v1'),
      secretKey: passwordKey,
      nonce: List<int>.filled(12, 1),
    );
    final legacyData = VaultData(
      entries: [
        VaultEntry.blank().copyWith(
          title: 'Legacy entry',
          password: 'legacy secret',
        ),
      ],
    );
    final vaultBox = await cipher.encrypt(
      utf8.encode(jsonEncode(legacyData.toJson())),
      secretKey: passwordKey,
      nonce: List<int>.filled(12, 2),
    );
    final legacyEnvelope = VaultEnvelope(
      version: 1,
      iterations: iterations,
      salt: base64Encode(salt),
      check: EncryptedPayload.fromSecretBox(checkBox),
      vault: EncryptedPayload.fromSecretBox(vaultBox),
    );
    final store = VaultStore(baseDirectory: directory, iterations: iterations);
    await File(
      await store.localVaultPath,
    ).writeAsString(jsonEncode(legacyEnvelope.toJson()));

    final session = await store.unlock(password);
    expect(session.data.entries.single.password, 'legacy secret');

    await store.enableEmailRecovery(
      session: session,
      email: 'legacy@example.com',
      userId: 'legacy-user',
      recoveryKey: List<int>.filled(32, 7),
    );

    final upgraded = await store.unlock(password);
    expect(upgraded.envelope.version, VaultStore.currentVersion);
    expect(upgraded.data.entries.single.title, 'Legacy entry');
  });
}
