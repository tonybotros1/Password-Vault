import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../models/vault_entry.dart';
import '../../utils/password_generator.dart';
import '../widgets/shared_widgets.dart';

class EntryEditorDialog extends StatefulWidget {
  const EntryEditorDialog({super.key, this.entry});

  final VaultEntry? entry;

  static Future<VaultEntry?> show(BuildContext context, {VaultEntry? entry}) {
    return showDialog<VaultEntry>(
      context: context,
      builder: (_) => EntryEditorDialog(entry: entry),
    );
  }

  @override
  State<EntryEditorDialog> createState() => _EntryEditorDialogState();
}

class _EntryEditorDialogState extends State<EntryEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _websiteController;
  late final TextEditingController _categoryController;
  late final TextEditingController _accountIdController;
  late final TextEditingController _recoveryController;
  late final TextEditingController _twoFactorController;
  late final TextEditingController _tagsController;
  late final TextEditingController _notesController;
  late final List<_EditableCustomField> _customFields;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry ?? VaultEntry.blank();
    _titleController = TextEditingController(text: entry.title);
    _usernameController = TextEditingController(text: entry.username);
    _emailController = TextEditingController(text: entry.email);
    _passwordController = TextEditingController(text: entry.password);
    _websiteController = TextEditingController(text: entry.website);
    _categoryController = TextEditingController(text: entry.category);
    _accountIdController = TextEditingController(text: entry.accountId);
    _recoveryController = TextEditingController(text: entry.recoveryContact);
    _twoFactorController = TextEditingController(text: entry.twoFactorNotes);
    _tagsController = TextEditingController(text: entry.tags);
    _notesController = TextEditingController(text: entry.notes);
    _customFields = entry.customFields
        .map(
          (field) => _EditableCustomField(
            labelController: TextEditingController(text: field.label),
            valueController: TextEditingController(text: field.value),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _categoryController.dispose();
    _accountIdController.dispose();
    _recoveryController.dispose();
    _twoFactorController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    for (final field in _customFields) {
      field.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Service name is required.');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Password is required.');
      return;
    }

    final customFields = <VaultCustomField>[];
    for (final field in _customFields) {
      final label = field.labelController.text.trim();
      final value = field.valueController.text.trim();
      final hasAnyValue = label.isNotEmpty || value.isNotEmpty;
      final isComplete = label.isNotEmpty && value.isNotEmpty;

      if (hasAnyValue && !isComplete) {
        setState(() => _error = 'Custom fields need a name and value.');
        return;
      }

      if (isComplete) {
        customFields.add(VaultCustomField(label: label, value: value));
      }
    }

    final original = widget.entry ?? VaultEntry.blank();
    final savedEntry = original.copyWith(
      title: _titleController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      website: _websiteController.text.trim(),
      category: _categoryController.text.trim(),
      accountId: _accountIdController.text.trim(),
      recoveryContact: _recoveryController.text.trim(),
      twoFactorNotes: _twoFactorController.text.trim(),
      tags: _tagsController.text.trim(),
      notes: _notesController.text.trim(),
      customFields: customFields,
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(savedEntry);
  }

  void _generatePassword() {
    final password = PasswordGenerator.generate();
    setState(() {
      _passwordController.text = password;
      _showPassword = true;
      _error = null;
    });
  }

  void _addCustomField() {
    setState(() {
      _customFields.add(
        _EditableCustomField(
          labelController: TextEditingController(),
          valueController: TextEditingController(),
        ),
      );
      _error = null;
    });
  }

  void _removeCustomField(int index) {
    setState(() {
      final field = _customFields.removeAt(index);
      field.dispose();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Password' : 'Add Password'),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EditorGrid(
                children: [
                  TextInput(label: 'Service', controller: _titleController),
                  TextInput(label: 'Website', controller: _websiteController),
                  TextInput(label: 'Username', controller: _usernameController),
                  TextInput(label: 'Email', controller: _emailController),
                  TextInput(label: 'Category', controller: _categoryController),
                  TextInput(
                    label: 'Account ID',
                    controller: _accountIdController,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: SizedBox(
                    width: 128,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Tooltip(
                          message: 'Generate password',
                          child: IconButton(
                            onPressed: _generatePassword,
                            icon: const Icon(Icons.auto_awesome_outlined),
                          ),
                        ),
                        Tooltip(
                          message: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                          child: IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              EditorGrid(
                children: [
                  TextInput(
                    label: 'Recovery Email or Phone',
                    controller: _recoveryController,
                  ),
                  TextInput(label: 'Tags', controller: _tagsController),
                ],
              ),
              const SizedBox(height: 14),
              TextInput(
                label: 'Two-Factor Notes',
                controller: _twoFactorController,
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              TextInput(
                label: 'Notes',
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Custom Fields',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _addCustomField,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Field'),
                  ),
                ],
              ),
              if (_customFields.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (var index = 0; index < _customFields.length; index++) ...[
                  _CustomFieldEditorRow(
                    field: _customFields[index],
                    onRemove: () => _removeCustomField(index),
                  ),
                  if (index != _customFields.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

class _CustomFieldEditorRow extends StatelessWidget {
  const _CustomFieldEditorRow({required this.field, required this.onRemove});

  final _EditableCustomField field;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextInput(
            label: 'Field Name',
            controller: field.labelController,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextInput(label: 'Value', controller: field.valueController),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Remove field',
          child: IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.danger,
          ),
        ),
      ],
    );
  }
}

class _EditableCustomField {
  const _EditableCustomField({
    required this.labelController,
    required this.valueController,
  });

  final TextEditingController labelController;
  final TextEditingController valueController;

  void dispose() {
    labelController.dispose();
    valueController.dispose();
  }
}
