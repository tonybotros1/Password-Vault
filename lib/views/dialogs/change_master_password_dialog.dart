import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../widgets/shared_widgets.dart';

class ChangeMasterPasswordDialog extends StatefulWidget {
  const ChangeMasterPasswordDialog({super.key});

  static Future<PasswordChange?> show(BuildContext context) {
    return showDialog<PasswordChange>(
      context: context,
      builder: (_) => const ChangeMasterPasswordDialog(),
    );
  }

  @override
  State<ChangeMasterPasswordDialog> createState() =>
      _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState
    extends State<ChangeMasterPasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    if (next.length < 10) {
      setState(() => _error = 'Use at least 10 characters.');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'The new master passwords do not match.');
      return;
    }

    Navigator.of(
      context,
    ).pop(PasswordChange(currentPassword: current, newPassword: next));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Master Password'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PasswordInput(
              controller: _currentController,
              label: 'Current Master Password',
            ),
            const SizedBox(height: 12),
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
        FilledButton(onPressed: _submit, child: const Text('Change')),
      ],
    );
  }
}

class PasswordChange {
  const PasswordChange({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;
}
