import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_vault/controllers/vault_controller.dart';
import 'package:password_vault/services/chrome_password_import.dart';
import 'package:password_vault/services/vault_store.dart';

void main() {
  const importer = ChromePasswordCsvImporter();

  test('maps a Chrome password CSV into vault entries', () {
    final result = importer.parse(
      'name,url,username,password,note\r\n'
      'Example,https://example.com,user@example.com,"p,a""ss",A note',
    );

    expect(result.skippedInvalidRows, 0);
    expect(result.entries, hasLength(1));
    expect(result.entries.single.title, 'Example');
    expect(result.entries.single.website, 'https://example.com');
    expect(result.entries.single.username, 'user@example.com');
    expect(result.entries.single.password, 'p,a"ss');
    expect(result.entries.single.notes, 'A note');
    expect(result.entries.single.category, 'Google Chrome');
  });

  test('requires the Chrome CSV columns', () {
    expect(
      () => importer.parse('site,login,secret\nexample.com,user,password'),
      throwsA(isA<ChromePasswordImportException>()),
    );
  });

  test('preserves whitespace that belongs to a password', () {
    final result = importer.parse(
      'name,url,username,password\n'
      'Example,https://example.com,user," secret "',
    );

    expect(result.entries.single.password, ' secret ');
  });

  test('imports atomically and skips exact duplicates', () async {
    final directory = await Directory.systemTemp.createTemp(
      'password-vault-chrome-import-',
    );
    addTearDown(() => directory.delete(recursive: true));

    final csvFile = File('${directory.path}/Chrome Passwords.csv');
    await csvFile.writeAsString(
      'name,url,username,password,note\n'
      'Example,https://example.com,user,secret,',
    );

    final controller = VaultController(
      store: VaultStore(baseDirectory: directory, iterations: 1),
    );
    addTearDown(controller.dispose);
    await controller.createVault('correct horse battery staple');

    final firstImport = await controller.importChromePasswords(csvFile.path);
    final secondImport = await controller.importChromePasswords(csvFile.path);

    expect(firstImport.imported, 1);
    expect(secondImport.imported, 0);
    expect(secondImport.skippedDuplicates, 1);
    expect(controller.allEntryCount, 1);
  });
}
