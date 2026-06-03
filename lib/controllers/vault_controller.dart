import 'package:flutter/foundation.dart';

import '../models/vault_entry.dart';
import '../services/vault_store.dart';

class VaultController extends ChangeNotifier {
  VaultController({required this.store});

  final VaultStore store;

  UnlockedVault? _session;
  bool _checking = true;
  bool _hasVault = false;
  bool _disposed = false;
  String _query = '';
  String? _selectedEntryId;

  bool get checking => _checking;
  bool get hasVault => _hasVault;
  bool get isUnlocked => _session != null;
  String get query => _query;
  int get allEntryCount => _session?.data.entries.length ?? 0;

  List<VaultEntry> get filteredEntries {
    final session = _session;
    if (session == null) {
      return const [];
    }

    return session.data.entries
        .where((entry) => entry.matches(_query))
        .toList();
  }

  VaultEntry? get selectedEntry {
    final entries = filteredEntries;
    if (entries.isEmpty) {
      return null;
    }

    return entries.firstWhere(
      (entry) => entry.id == _selectedEntryId,
      orElse: () => entries.first,
    );
  }

  Future<void> loadVaultState() async {
    _hasVault = await store.hasVault();
    _checking = false;
    _notify();
  }

  Future<void> createVault(String masterPassword) async {
    _session = await store.create(masterPassword);
    _hasVault = true;
    _selectedEntryId = null;
    _notify();
  }

  Future<void> unlockVault(String masterPassword) async {
    final session = await store.unlock(masterPassword);
    _session = session;
    _selectedEntryId = _firstEntryId(session.data.entries);
    _notify();
  }

  Future<void> importBackup({
    required String path,
    required String masterPassword,
  }) async {
    final session = await store.importBackup(
      path: path,
      masterPassword: masterPassword,
    );
    _session = session;
    _hasVault = true;
    _selectedEntryId = _firstEntryId(session.data.entries);
    _notify();
  }

  Future<String> exportBackup(String destinationPath) async {
    final session = _requireSession();

    return store.exportBackup(
      session: session,
      destinationPath: destinationPath,
    );
  }

  Future<void> saveEntry(VaultEntry entry) async {
    final session = _requireSession();
    session.data = session.data.upsert(entry);
    await store.save(session);
    _selectedEntryId = entry.id;
    _notify();
  }

  Future<void> deleteEntry(VaultEntry entry) async {
    final session = _requireSession();
    session.data = session.data.delete(entry.id);
    await store.save(session);
    _selectedEntryId = _firstEntryId(session.data.entries);
    _notify();
  }

  Future<void> togglePin(VaultEntry entry) async {
    final session = _requireSession();
    final updatedEntry = entry.copyWith(
      isPinned: !entry.isPinned,
      updatedAt: DateTime.now(),
    );

    session.data = session.data.upsert(updatedEntry);
    await store.save(session);
    _selectedEntryId = updatedEntry.id;
    _notify();
  }

  Future<bool> verifyPassword(String password) {
    return store.verifyPassword(_requireSession(), password);
  }

  Future<void> changeMasterPassword(String newMasterPassword) async {
    await store.changeMasterPassword(
      session: _requireSession(),
      newMasterPassword: newMasterPassword,
    );
    _notify();
  }

  void setQuery(String value) {
    _query = value;
    _notify();
  }

  void selectEntry(VaultEntry entry) {
    _selectedEntryId = entry.id;
    _notify();
  }

  void signOut() {
    _session = null;
    _query = '';
    _selectedEntryId = null;
    _notify();
  }

  String backupFileName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');

    return 'password-vault-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}.pwvault';
  }

  UnlockedVault _requireSession() {
    final session = _session;
    if (session == null) {
      throw const VaultStoreException('Unlock the vault first.');
    }

    return session;
  }

  String? _firstEntryId(List<VaultEntry> entries) {
    return entries.isEmpty ? null : entries.first.id;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String vaultErrorMessage(Object error) {
  if (error is VaultAuthException) {
    return error.message;
  }
  if (error is VaultStoreException) {
    return error.message;
  }

  return 'Something went wrong';
}
