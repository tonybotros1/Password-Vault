import 'package:flutter_test/flutter_test.dart';
import 'package:password_vault/models/vault_entry.dart';

void main() {
  test('vault data preserves useful password fields', () {
    final now = DateTime(2026, 6, 3, 12);
    final entry = VaultEntry(
      id: 'entry-1',
      title: 'Email',
      username: 'paul',
      email: 'paul@example.com',
      password: 'correct horse battery staple',
      website: 'https://example.com',
      category: 'Personal',
      accountId: '12345',
      recoveryContact: '+971500000000',
      twoFactorNotes: 'Authenticator app',
      tags: 'mail, daily',
      notes: 'Primary email account',
      createdAt: now,
      updatedAt: now,
    );

    final data = VaultData(entries: [entry]);
    final restored = VaultData.fromJson(data.toJson());

    expect(restored.entries, hasLength(1));
    expect(restored.entries.single.title, 'Email');
    expect(restored.entries.single.password, 'correct horse battery staple');
    expect(restored.entries.single.matches('authenticator'), isTrue);
  });
}
