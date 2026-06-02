import 'package:flutter/material.dart';

import '../widgets/shared_widgets.dart';

class PasswordPromptDialog extends StatefulWidget {
  const PasswordPromptDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
  });

  final String title;
  final String confirmLabel;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) =>
          PasswordPromptDialog(title: title, confirmLabel: confirmLabel),
    );
  }

  @override
  State<PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<PasswordPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: PasswordInput(
          controller: _controller,
          label: 'Backup Master Password',
          onSubmitted: (_) => Navigator.of(context).pop(_controller.text),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
