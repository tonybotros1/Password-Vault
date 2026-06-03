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
      isPinned: true,
      customFields: const [
        VaultCustomField(label: 'Backup Code', value: 'A1-B2-C3'),
      ],
    );

    final data = VaultData(entries: [entry]);
    final restored = VaultData.fromJson(data.toJson());

    expect(restored.entries, hasLength(1));
    expect(restored.entries.single.title, 'Email');
    expect(restored.entries.single.password, 'correct horse battery staple');
    expect(restored.entries.single.isPinned, isTrue);
    expect(restored.entries.single.customFields.single.label, 'Backup Code');
    expect(restored.entries.single.matches('authenticator'), isTrue);
    expect(restored.entries.single.matches('a1-b2'), isTrue);
  });

  test('vault data sorts pinned entries first', () {
    final older = DateTime(2026, 6, 1);
    final newer = DateTime(2026, 6, 3);
    final normal = VaultEntry.blank().copyWith(
      id: 'normal',
      title: 'Normal',
      updatedAt: newer,
    );
    final pinned = VaultEntry.blank().copyWith(
      id: 'pinned',
      title: 'Pinned',
      isPinned: true,
      updatedAt: older,
    );

    final data = VaultData(entries: [normal]).upsert(pinned);

    expect(data.entries.first.id, 'pinned');
  });
}
