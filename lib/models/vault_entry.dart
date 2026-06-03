import 'dart:math';

String createVaultId() {
  final random = Random.secure();
  final suffix = List<int>.generate(
    8,
    (_) => random.nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
}

class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.email,
    required this.password,
    required this.website,
    required this.category,
    required this.accountId,
    required this.recoveryContact,
    required this.twoFactorNotes,
    required this.tags,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.customFields = const [],
  });

  factory VaultEntry.blank() {
    final now = DateTime.now();

    return VaultEntry(
      id: createVaultId(),
      title: '',
      username: '',
      email: '',
      password: '',
      website: '',
      category: '',
      accountId: '',
      recoveryContact: '',
      twoFactorNotes: '',
      tags: '',
      notes: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    String read(String key) => json[key] as String? ?? '';
    DateTime readDate(String key) {
      return DateTime.tryParse(read(key)) ?? DateTime.now();
    }

    return VaultEntry(
      id: read('id').isEmpty ? createVaultId() : read('id'),
      title: read('title'),
      username: read('username'),
      email: read('email'),
      password: read('password'),
      website: read('website'),
      category: read('category'),
      accountId: read('accountId'),
      recoveryContact: read('recoveryContact'),
      twoFactorNotes: read('twoFactorNotes'),
      tags: read('tags'),
      notes: read('notes'),
      createdAt: readDate('createdAt'),
      updatedAt: readDate('updatedAt'),
      isPinned: json['isPinned'] as bool? ?? false,
      customFields: VaultCustomField.listFromJson(json['customFields']),
    );
  }

  final String id;
  final String title;
  final String username;
  final String email;
  final String password;
  final String website;
  final String category;
  final String accountId;
  final String recoveryContact;
  final String twoFactorNotes;
  final String tags;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final List<VaultCustomField> customFields;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'email': email,
      'password': password,
      'website': website,
      'category': category,
      'accountId': accountId,
      'recoveryContact': recoveryContact,
      'twoFactorNotes': twoFactorNotes,
      'tags': tags,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      'customFields': customFields.map((field) => field.toJson()).toList(),
    };
  }

  VaultEntry copyWith({
    String? id,
    String? title,
    String? username,
    String? email,
    String? password,
    String? website,
    String? category,
    String? accountId,
    String? recoveryContact,
    String? twoFactorNotes,
    String? tags,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    List<VaultCustomField>? customFields,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      website: website ?? this.website,
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
      recoveryContact: recoveryContact ?? this.recoveryContact,
      twoFactorNotes: twoFactorNotes ?? this.twoFactorNotes,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      customFields: customFields ?? this.customFields,
    );
  }

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchableText = [
      title,
      username,
      email,
      website,
      category,
      accountId,
      recoveryContact,
      twoFactorNotes,
      tags,
      notes,
      ...customFields.expand((field) => [field.label, field.value]),
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }
}

class VaultCustomField {
  const VaultCustomField({required this.label, required this.value});

  factory VaultCustomField.fromJson(Map<String, dynamic> json) {
    return VaultCustomField(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  static List<VaultCustomField> listFromJson(Object? rawFields) {
    if (rawFields is! List) {
      return const [];
    }

    return rawFields
        .whereType<Map<String, dynamic>>()
        .map(VaultCustomField.fromJson)
        .where((field) => field.label.isNotEmpty || field.value.isNotEmpty)
        .toList();
  }

  final String label;
  final String value;

  Map<String, dynamic> toJson() {
    return {'label': label, 'value': value};
  }
}

class VaultData {
  const VaultData({this.entries = const []});

  factory VaultData.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final entries = rawEntries is List
        ? rawEntries
              .whereType<Map<String, dynamic>>()
              .map(VaultEntry.fromJson)
              .toList()
        : <VaultEntry>[];

    _sortEntries(entries);

    return VaultData(entries: entries);
  }

  final List<VaultEntry> entries;

  Map<String, dynamic> toJson() {
    return {'entries': entries.map((entry) => entry.toJson()).toList()};
  }

  VaultData upsert(VaultEntry entry) {
    final nextEntries = [...entries];
    final index = nextEntries.indexWhere((item) => item.id == entry.id);

    if (index == -1) {
      nextEntries.insert(0, entry);
    } else {
      nextEntries[index] = entry;
    }

    _sortEntries(nextEntries);

    return VaultData(entries: nextEntries);
  }

  VaultData delete(String id) {
    return VaultData(
      entries: entries.where((entry) => entry.id != id).toList(),
    );
  }

  static void _sortEntries(List<VaultEntry> entries) {
    entries.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }

      return b.updatedAt.compareTo(a.updatedAt);
    });
  }
}
