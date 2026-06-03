import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_colors.dart';
import '../../controllers/vault_controller.dart';
import '../../models/vault_entry.dart';
import '../../services/vault_store.dart';
import '../dialogs/change_master_password_dialog.dart';
import '../dialogs/confirm_dialog.dart';
import '../dialogs/entry_editor_dialog.dart';
import '../dialogs/password_prompt_dialog.dart';
import 'auth_screen.dart';
import 'vault_dashboard.dart';

class VaultHomePage extends StatefulWidget {
  const VaultHomePage({super.key, required this.store});

  final VaultStore store;

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> {
  late final VaultController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VaultController(store: widget.store)..loadVaultState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createVault(String masterPassword) async {
    await _controller.createVault(masterPassword);
    if (!mounted) {
      return;
    }
    _showMessage('Vault created');
  }

  Future<void> _unlockVault(String masterPassword) async {
    await _controller.unlockVault(masterPassword);
    if (!mounted) {
      return;
    }
    _showMessage('Unlocked');
  }

  Future<void> _importBackup() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Password Vault backup', extensions: ['pwvault']),
      ],
    );
    if (file == null || !mounted) {
      return;
    }

    final password = await PasswordPromptDialog.show(
      context,
      title: 'Import Encrypted Backup',
      confirmLabel: 'Import',
    );
    if (password == null || password.isEmpty || !mounted) {
      return;
    }

    try {
      await _controller.importBackup(path: file.path, masterPassword: password);
      if (!mounted) {
        return;
      }
      _showMessage('Encrypted backup imported');
    } on Object catch (error) {
      _showMessage(vaultErrorMessage(error));
    }
  }

  Future<void> _exportBackup() async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Password Vault backup', extensions: ['pwvault']),
      ],
      suggestedName: _controller.backupFileName(),
    );
    if (location == null || !mounted) {
      return;
    }

    try {
      final savedPath = await _controller.exportBackup(location.path);
      if (!mounted) {
        return;
      }
      _showMessage('Encrypted backup saved to $savedPath');
    } on Object catch (error) {
      _showMessage(vaultErrorMessage(error));
    }
  }

  Future<void> _deleteEntry(VaultEntry entry) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete ${entry.title}?',
      message: 'This saved password will be removed from the local vault.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _controller.deleteEntry(entry);
    if (!mounted) {
      return;
    }
    _showMessage('Deleted');
  }

  Future<void> _togglePin(VaultEntry entry) async {
    await _controller.togglePin(entry);
    if (!mounted) {
      return;
    }

    _showMessage(entry.isPinned ? 'Unpinned' : 'Pinned');
  }

  Future<void> _showEntryEditor({VaultEntry? entry}) async {
    final savedEntry = await EntryEditorDialog.show(context, entry: entry);
    if (savedEntry == null) {
      return;
    }

    await _controller.saveEntry(savedEntry);
    if (!mounted) {
      return;
    }
    _showMessage('Saved');
  }

  Future<void> _changeMasterPassword() async {
    final change = await ChangeMasterPasswordDialog.show(context);
    if (change == null || !mounted) {
      return;
    }

    try {
      final currentPasswordMatches = await _controller.verifyPassword(
        change.currentPassword,
      );
      if (!currentPasswordMatches) {
        _showMessage('Current master password is incorrect');
        return;
      }

      await _controller.changeMasterPassword(change.newPassword);
      if (!mounted) {
        return;
      }
      _showMessage('Master password changed');
    } on Object catch (error) {
      _showMessage(vaultErrorMessage(error));
    }
  }

  Future<void> _copyValue(String label, String value) async {
    if (value.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    _showMessage('$label copied');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.checking) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }

        if (!_controller.isUnlocked) {
          return AuthScreen(
            hasVault: _controller.hasVault,
            onCreate: _createVault,
            onUnlock: _unlockVault,
            onImportBackup: _importBackup,
          );
        }

        return VaultDashboard(
          entries: _controller.filteredEntries,
          allEntryCount: _controller.allEntryCount,
          selectedEntry: _controller.selectedEntry,
          onQueryChanged: _controller.setQuery,
          onSelectEntry: _controller.selectEntry,
          onAddEntry: () => _showEntryEditor(),
          onEditEntry: (entry) {
            _showEntryEditor(entry: entry);
          },
          onDeleteEntry: (entry) {
            _deleteEntry(entry);
          },
          onTogglePin: (entry) {
            _togglePin(entry);
          },
          onCopyValue: _copyValue,
          onExportBackup: () {
            _exportBackup();
          },
          onImportBackup: () {
            _importBackup();
          },
          onChangeMasterPassword: () {
            _changeMasterPassword();
          },
          onSignOut: _controller.signOut,
        );
      },
    );
  }
}
