import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../widgets/shared_widgets.dart';

class RecoveryEmailDialog extends StatefulWidget {
  const RecoveryEmailDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const RecoveryEmailDialog(),
    );
  }

  @override
  State<RecoveryEmailDialog> createState() => _RecoveryEmailDialogState();
}

class _RecoveryEmailDialogState extends State<RecoveryEmailDialog> {
  final _emailController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim().toLowerCase();
    final looksValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!looksValid) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect Recovery Email'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'A verification link will be sent to this address. Keep the app '
              'open, then click the link to finish connecting recovery.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Recovery Email'),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send Link')),
      ],
    );
  }
}

class ResetMasterPasswordDialog extends StatefulWidget {
  const ResetMasterPasswordDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ResetMasterPasswordDialog(),
    );
  }

  @override
  State<ResetMasterPasswordDialog> createState() =>
      _ResetMasterPasswordDialogState();
}

class _ResetMasterPasswordDialogState extends State<ResetMasterPasswordDialog> {
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final next = _newController.text;
    if (next.trim().length < 10) {
      setState(() => _error = 'Use at least 10 characters.');
      return;
    }
    if (next != _confirmController.text) {
      setState(() => _error = 'The new master passwords do not match.');
      return;
    }
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Master Password'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your recovery email is verified. Choose a new master password.',
              ),
            ),
            const SizedBox(height: 16),
            PasswordInput(
              controller: _newController,
              label: 'New Master Password',
            ),
            const SizedBox(height: 12),
            PasswordInput(
              controller: _confirmController,
              label: 'Confirm New Master Password',
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Reset Password')),
      ],
    );
  }
}
