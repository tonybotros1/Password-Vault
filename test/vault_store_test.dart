import 'dart:io';

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
}
