import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_vault/models/vault_entry.dart';
import 'package:password_vault/views/screens/vault_dashboard.dart';

void main() {
  testWidgets('sidebar shows notes and website is a clickable link', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime(2026);
    final entry = VaultEntry(
      id: 'entry-1',
      title: 'Example Service',
      username: 'hidden@example.com',
      email: '',
      password: 'secret',
      website: 'https://example.com',
      category: '',
      accountId: '',
      recoveryContact: '',
      twoFactorNotes: '',
      tags: '',
      notes: 'A sidebar note',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VaultDashboard(
          entries: [entry],
          allEntryCount: 1,
          selectedEntry: entry,
          onQueryChanged: (_) {},
          onSelectEntry: (_) {},
          onAddEntry: () {},
          onEditEntry: (_) {},
          onDeleteEntry: (_) {},
          onTogglePin: (_) {},
          onCopyValue: (_, _) async {},
          onExportBackup: () {},
          onImportBackup: () {},
          onImportFromChrome: () {},
          recoveryEmail: null,
          onLinkRecoveryEmail: () {},
          onChangeMasterPassword: () {},
          onSignOut: () {},
        ),
      ),
    );

    expect(find.text('Example Service'), findsNWidgets(2));
    expect(find.text('hidden@example.com'), findsOneWidget);
    expect(find.text('A sidebar note'), findsNWidgets(2));

    final websiteText = find.text('https://example.com');
    expect(websiteText, findsOneWidget);
    final websiteLink = find.ancestor(
      of: websiteText,
      matching: find.byType(InkWell),
    );
    expect(websiteLink, findsOneWidget);
    expect(
      tester.widget<InkWell>(websiteLink).mouseCursor,
      SystemMouseCursors.click,
    );
  });
}
