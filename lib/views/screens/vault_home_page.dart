import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_colors.dart';
import '../../controllers/vault_controller.dart';
import '../../models/vault_entry.dart';
import '../../services/chrome_password_import.dart';
import '../../services/email_recovery_service.dart';
import '../../services/vault_store.dart';
import '../dialogs/change_master_password_dialog.dart';
import '../dialogs/confirm_dialog.dart';
import '../dialogs/entry_editor_dialog.dart';
import '../dialogs/email_recovery_dialogs.dart';
import '../dialogs/password_prompt_dialog.dart';
import 'auth_screen.dart';
import 'vault_dashboard.dart';

class VaultHomePage extends StatefulWidget {
  const VaultHomePage({super.key, required this.store, this.recoveryService});

  final VaultStore store;
  final EmailRecoveryService? recoveryService;

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> {
  late final VaultController _controller;
  StreamSubscription<EmailRecoveryAuthEvent>? _recoverySubscription;
  bool _handlingRecoverySession = false;

  @override
  void initState() {
    super.initState();
    _controller = VaultController(store: widget.store);
    final recoveryService = widget.recoveryService;
    if (recoveryService != null) {
      _recoverySubscription = recoveryService.authEvents.listen(
        _queueRecoveryEvent,
      );
    }
    _initialize();
  }

  @override
  void dispose() {
    _recoverySubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _controller.loadVaultState();
    final identity = widget.recoveryService?.currentIdentity;
    if (identity != null) {
      _queueRecoveryEvent(
        EmailRecoveryAuthEvent(
          identity: identity,
          isPasswordRecovery: _controller.recoveryInfo != null,
        ),
      );
    }
  }

  void _queueRecoveryEvent(EmailRecoveryAuthEvent event) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleRecoveryEvent(event);
    });
  }

  Future<void> _handleRecoveryEvent(EmailRecoveryAuthEvent event) async {
    if (!mounted || _controller.checking || _handlingRecoverySession) {
      return;
    }

    final recoveryInfo = _controller.recoveryInfo;
    if (recoveryInfo == null) {
      if (_controller.isUnlocked) {
        await _finishConnectingRecoveryEmail(event.identity);
      } else {
        _showMessage(
          'Email verified. Unlock the vault to finish connecting recovery.',
        );
      }
      return;
    }

    if (event.identity.userId != recoveryInfo.userId) {
      await widget.recoveryService?.signOut();
      if (mounted) {
        _showMessage('This email link does not match the connected vault.');
      }
      return;
    }

    await _resetMasterPasswordFromEmail(event.identity);
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

    final identity = widget.recoveryService?.currentIdentity;
    if (identity != null && _controller.recoveryInfo == null) {
      _queueRecoveryEvent(
        EmailRecoveryAuthEvent(identity: identity, isPasswordRecovery: false),
      );
    }
  }

  Future<void> _connectRecoveryEmail() async {
    final recoveryService = widget.recoveryService;
    if (recoveryService == null) {
      _showMessage(
        'Email recovery needs Supabase configuration in this Windows build.',
      );
      return;
    }
    final existingRecovery = _controller.recoveryInfo;
    if (existingRecovery != null) {
      _showMessage('Recovery is connected to ${existingRecovery.email}.');
      return;
    }

    final email = await RecoveryEmailDialog.show(context);
    if (email == null || !mounted) {
      return;
    }

    try {
      await recoveryService.beginEmailLink(email);
      if (!mounted) {
        return;
      }
      _showMessage(
        'Verification email sent. Keep this app open and click the link.',
      );
      final identity = recoveryService.currentIdentity;
      if (identity != null) {
        _queueRecoveryEvent(
          EmailRecoveryAuthEvent(identity: identity, isPasswordRecovery: false),
        );
      }
    } on Object catch (error) {
      _showMessage(emailRecoveryErrorMessage(error));
    }
  }

  Future<void> _finishConnectingRecoveryEmail(RecoveryIdentity identity) async {
    final recoveryService = widget.recoveryService;
    if (recoveryService == null || _handlingRecoverySession) {
      return;
    }

    _handlingRecoverySession = true;
    try {
      final recoveryKey = widget.store.createRecoveryKey();
      await recoveryService.saveRecoveryKey(
        userId: identity.userId,
        recoveryKey: recoveryKey,
      );
      await _controller.enableEmailRecovery(
        email: identity.email,
        userId: identity.userId,
        recoveryKey: recoveryKey,
      );
      await recoveryService.signOut();
      if (mounted) {
        _showMessage('Recovery email connected and verified.');
      }
    } on Object catch (error) {
      if (mounted) {
        _showMessage(emailRecoveryErrorMessage(error));
      }
    } finally {
      _handlingRecoverySession = false;
    }
  }

  Future<void> _requestMasterPasswordReset() async {
    final recoveryService = widget.recoveryService;
    final recoveryInfo = _controller.recoveryInfo;
    if (recoveryService == null) {
      _showMessage('Email recovery is not configured in this Windows build.');
      return;
    }
    if (recoveryInfo == null) {
      _showMessage('No recovery email is connected to this vault.');
      return;
    }

    try {
      await recoveryService.requestPasswordReset(recoveryInfo.email);
      if (mounted) {
        _showMessage(
          'Recovery link sent to ${recoveryInfo.email}. Click it to continue.',
        );
      }
    } on Object catch (error) {
      _showMessage(emailRecoveryErrorMessage(error));
    }
  }

  Future<void> _resetMasterPasswordFromEmail(RecoveryIdentity identity) async {
    final recoveryService = widget.recoveryService;
    if (recoveryService == null || _handlingRecoverySession) {
      return;
    }

    _handlingRecoverySession = true;
    try {
      final recoveryKey = await recoveryService.loadRecoveryKey(
        identity.userId,
      );
      if (!mounted) {
        return;
      }
      final newMasterPassword = await ResetMasterPasswordDialog.show(context);
      if (newMasterPassword == null) {
        await recoveryService.signOut();
        return;
      }

      await _controller.recoverMasterPassword(
        userId: identity.userId,
        recoveryKey: recoveryKey,
        newMasterPassword: newMasterPassword,
      );
      try {
        await recoveryService.completeRecoverySession();
      } on Object {
        await recoveryService.signOut();
      }
      if (mounted) {
        _showMessage('Master password reset. Your vault is unlocked.');
      }
    } on Object catch (error) {
      if (mounted) {
        final message =
            error is VaultAuthException || error is VaultStoreException
            ? vaultErrorMessage(error)
            : emailRecoveryErrorMessage(error);
        _showMessage(message);
      }
    } finally {
      _handlingRecoverySession = false;
    }
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

  Future<void> _importFromChrome() async {
    try {
      await const ChromePasswordManagerLauncher().open();
    } on Object catch (error) {
      _showMessage(vaultErrorMessage(error));
      return;
    }

    if (!mounted) {
      return;
    }

    final selectExport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import from Google Chrome'),
        content: const Text(
          'In Chrome, select Download file under Export passwords. '
          'Return here when the CSV has downloaded. The CSV is not encrypted, '
          'so delete it after the import succeeds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Select CSV'),
          ),
        ],
      ),
    );
    if (selectExport != true || !mounted) {
      return;
    }

    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Chrome passwords', extensions: ['csv']),
      ],
    );
    if (file == null || !mounted) {
      return;
    }

    try {
      final result = await _controller.importChromePasswords(file.path);
      if (!mounted) {
        return;
      }
      _showMessage(_chromeImportMessage(result));
    } on Object catch (error) {
      _showMessage(vaultErrorMessage(error));
    }
  }

  String _chromeImportMessage(ChromePasswordImportResult result) {
    final details = <String>[];
    if (result.skippedDuplicates > 0) {
      details.add('${result.skippedDuplicates} duplicate(s) skipped');
    }
    if (result.skippedInvalidRows > 0) {
      details.add('${result.skippedInvalidRows} invalid row(s) skipped');
    }

    final summary = '${result.imported} password(s) imported';
    if (details.isEmpty) {
      return '$summary. Delete the unencrypted CSV.';
    }
    return '$summary; ${details.join(', ')}. Delete the unencrypted CSV.';
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
            recoveryEmail: _controller.recoveryInfo?.email,
            onForgotPassword: _requestMasterPasswordReset,
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
          onImportFromChrome: () {
            _importFromChrome();
          },
          recoveryEmail: _controller.recoveryInfo?.email,
          onLinkRecoveryEmail: () {
            _connectRecoveryEmail();
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
