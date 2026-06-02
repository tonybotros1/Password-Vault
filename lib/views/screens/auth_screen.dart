import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../controllers/vault_controller.dart';
import '../widgets/shared_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.hasVault,
    required this.onCreate,
    required this.onUnlock,
    required this.onImportBackup,
  });

  final bool hasVault;
  final Future<void> Function(String masterPassword) onCreate;
  final Future<void> Function(String masterPassword) onUnlock;
  final Future<void> Function() onImportBackup;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _masterPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isCreating = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isCreating = !widget.hasVault;
  }

  @override
  void dispose() {
    _masterPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final masterPassword = _masterPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (_isCreating && masterPassword != confirmPassword) {
      setState(() => _error = 'The master passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_isCreating) {
        await widget.onCreate(masterPassword);
      } else {
        await widget.onUnlock(masterPassword);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = vaultErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCreating
        ? 'Create Password Vault'
        : 'Unlock Password Vault';
    final actionLabel = _isCreating ? 'Create Vault' : 'Unlock';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const VaultMark(size: 52),
                const SizedBox(height: 22),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 22),
                PasswordInput(
                  controller: _masterPasswordController,
                  label: 'Master Password',
                  onSubmitted: (_) => _submit(),
                ),
                if (_isCreating) ...[
                  const SizedBox(height: 14),
                  PasswordInput(
                    controller: _confirmPasswordController,
                    label: 'Confirm Master Password',
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isCreating ? Icons.lock_outline : Icons.lock_open,
                        ),
                  label: Text(actionLabel),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          widget.onImportBackup();
                        },
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Import Encrypted Backup'),
                ),
                if (widget.hasVault)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _isCreating = !_isCreating;
                            _error = null;
                          }),
                    child: Text(
                      _isCreating ? 'Use Existing Vault' : 'Create New Vault',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
