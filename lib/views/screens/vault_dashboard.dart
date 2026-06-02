import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../models/vault_entry.dart';
import '../widgets/shared_widgets.dart';

class VaultDashboard extends StatelessWidget {
  const VaultDashboard({
    super.key,
    required this.entries,
    required this.allEntryCount,
    required this.selectedEntry,
    required this.onQueryChanged,
    required this.onSelectEntry,
    required this.onAddEntry,
    required this.onEditEntry,
    required this.onDeleteEntry,
    required this.onCopyValue,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.onChangeMasterPassword,
    required this.onSignOut,
  });

  final List<VaultEntry> entries;
  final int allEntryCount;
  final VaultEntry? selectedEntry;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<VaultEntry> onSelectEntry;
  final VoidCallback onAddEntry;
  final ValueChanged<VaultEntry> onEditEntry;
  final ValueChanged<VaultEntry> onDeleteEntry;
  final Future<void> Function(String label, String value) onCopyValue;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
  final VoidCallback onChangeMasterPassword;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VaultHeader(
                entryCount: allEntryCount,
                onQueryChanged: onQueryChanged,
                onAddEntry: onAddEntry,
                onExportBackup: onExportBackup,
                onImportBackup: onImportBackup,
                onChangeMasterPassword: onChangeMasterPassword,
                onSignOut: onSignOut,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 820) {
                      return Column(
                        children: [
                          SizedBox(
                            height: 270,
                            child: _EntryList(
                              entries: entries,
                              selectedEntry: selectedEntry,
                              onSelectEntry: onSelectEntry,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: _EntryDetails(
                              entry: selectedEntry,
                              onEdit: onEditEntry,
                              onDelete: onDeleteEntry,
                              onCopy: onCopyValue,
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 340,
                          child: _EntryList(
                            entries: entries,
                            selectedEntry: selectedEntry,
                            onSelectEntry: onSelectEntry,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _EntryDetails(
                            entry: selectedEntry,
                            onEdit: onEditEntry,
                            onDelete: onDeleteEntry,
                            onCopy: onCopyValue,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultHeader extends StatelessWidget {
  const _VaultHeader({
    required this.entryCount,
    required this.onQueryChanged,
    required this.onAddEntry,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.onChangeMasterPassword,
    required this.onSignOut,
  });

  final int entryCount;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onAddEntry;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
  final VoidCallback onChangeMasterPassword;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VaultMark(size: 44),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Password Vault',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  '$entryCount saved',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(
          width: 320,
          child: TextField(
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search',
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onAddEntry,
          icon: const Icon(Icons.add),
          label: const Text('Add Password'),
        ),
        HeaderIconButton(
          tooltip: 'Export encrypted backup',
          icon: Icons.ios_share_outlined,
          onPressed: onExportBackup,
        ),
        HeaderIconButton(
          tooltip: 'Import encrypted backup',
          icon: Icons.file_open_outlined,
          onPressed: onImportBackup,
        ),
        HeaderIconButton(
          tooltip: 'Change master password',
          icon: Icons.key_outlined,
          onPressed: onChangeMasterPassword,
        ),
        HeaderIconButton(
          tooltip: 'Lock',
          icon: Icons.lock_outline,
          onPressed: onSignOut,
        ),
      ],
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.entries,
    required this.selectedEntry,
    required this.onSelectEntry,
  });

  final List<VaultEntry> entries;
  final VaultEntry? selectedEntry;
  final ValueChanged<VaultEntry> onSelectEntry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: entries.isEmpty
          ? const Center(
              child: Text(
                'No saved passwords',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _EntryListItem(
                  entry: entry,
                  selected: entry.id == selectedEntry?.id,
                  onTap: () => onSelectEntry(entry),
                );
              },
            ),
    );
  }
}

class _EntryListItem extends StatelessWidget {
  const _EntryListItem({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final VaultEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [entry.username, entry.email, entry.website].firstWhere(
      (value) => value.isNotEmpty,
      orElse: () => 'No username saved',
    );

    return Material(
      color: selected ? AppColors.accentSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title.isEmpty ? 'Untitled' : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (entry.category.isNotEmpty) ...[
                const SizedBox(height: 8),
                MetaPill(label: entry.category),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryDetails extends StatefulWidget {
  const _EntryDetails({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
  });

  final VaultEntry? entry;
  final ValueChanged<VaultEntry> onEdit;
  final ValueChanged<VaultEntry> onDelete;
  final Future<void> Function(String label, String value) onCopy;

  @override
  State<_EntryDetails> createState() => _EntryDetailsState();
}

class _EntryDetailsState extends State<_EntryDetails> {
  bool _passwordVisible = false;

  @override
  void didUpdateWidget(covariant _EntryDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry?.id != widget.entry?.id) {
      _passwordVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: entry == null
          ? const Center(
              child: Text(
                'Select or add a password',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title.isEmpty ? 'Untitled' : entry.title,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (entry.category.isNotEmpty)
                                  MetaPill(label: entry.category),
                                MetaPill(label: _updatedLabel(entry.updatedAt)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      HeaderIconButton(
                        tooltip: 'Edit',
                        icon: Icons.edit_outlined,
                        onPressed: () => widget.onEdit(entry),
                      ),
                      const SizedBox(width: 8),
                      HeaderIconButton(
                        tooltip: 'Delete',
                        icon: Icons.delete_outline,
                        onPressed: () => widget.onDelete(entry),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _InfoRow(
                    label: 'Password',
                    value: _passwordVisible
                        ? entry.password
                        : _maskPassword(entry.password),
                    copyValue: entry.password,
                    onCopy: widget.onCopy,
                    trailing: Tooltip(
                      message: _passwordVisible
                          ? 'Hide password'
                          : 'Show password',
                      child: IconButton(
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  _InfoRow(
                    label: 'Username',
                    value: entry.username,
                    onCopy: widget.onCopy,
                  ),
                  _InfoRow(
                    label: 'Email',
                    value: entry.email,
                    onCopy: widget.onCopy,
                  ),
                  _InfoRow(
                    label: 'Website',
                    value: entry.website,
                    onCopy: widget.onCopy,
                  ),
                  _InfoRow(
                    label: 'Account ID',
                    value: entry.accountId,
                    onCopy: widget.onCopy,
                  ),
                  _InfoRow(
                    label: 'Tags',
                    value: entry.tags,
                    onCopy: widget.onCopy,
                  ),
                  _InfoRow(
                    label: 'Recovery',
                    value: entry.recoveryContact,
                    onCopy: widget.onCopy,
                  ),
                  _InfoRow(
                    label: 'Two-Factor',
                    value: entry.twoFactorNotes,
                    onCopy: widget.onCopy,
                  ),
                  _InfoRow(
                    label: 'Notes',
                    value: entry.notes,
                    onCopy: widget.onCopy,
                    multiline: true,
                  ),
                ],
              ),
            ),
    );
  }

  String _updatedLabel(DateTime updatedAt) {
    final date = updatedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');

    return 'Updated ${date.year}-${two(date.month)}-${two(date.day)}';
  }

  String _maskPassword(String password) {
    if (password.isEmpty) {
      return '';
    }

    return '•' * min(password.length, 16);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.onCopy,
    this.copyValue,
    this.trailing,
    this.multiline = false,
  });

  final String label;
  final String value;
  final String? copyValue;
  final Future<void> Function(String label, String value) onCopy;
  final Widget? trailing;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.isEmpty ? 'Not saved' : value;
    final canCopy = (copyValue ?? value).isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              displayValue,
              style: TextStyle(
                color: value.isEmpty ? AppColors.muted : AppColors.ink,
                height: multiline ? 1.35 : 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ?trailing,
          Tooltip(
            message: 'Copy $label',
            child: IconButton(
              onPressed: canCopy
                  ? () => onCopy(label, copyValue ?? value)
                  : null,
              icon: const Icon(Icons.copy_outlined),
            ),
          ),
        ],
      ),
    );
  }
}
