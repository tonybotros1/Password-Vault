import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/vault_entry.dart';

class ChromePasswordImportException implements Exception {
  const ChromePasswordImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChromePasswordImportData {
  const ChromePasswordImportData({
    required this.entries,
    required this.skippedInvalidRows,
  });

  final List<VaultEntry> entries;
  final int skippedInvalidRows;
}

class ChromePasswordImportResult {
  const ChromePasswordImportResult({
    required this.imported,
    required this.skippedDuplicates,
    required this.skippedInvalidRows,
  });

  final int imported;
  final int skippedDuplicates;
  final int skippedInvalidRows;
}

class ChromePasswordCsvImporter {
  const ChromePasswordCsvImporter();

  Future<ChromePasswordImportData> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const ChromePasswordImportException(
        'The selected Chrome password file was not found.',
      );
    }

    try {
      return parse(await file.readAsString(encoding: utf8));
    } on ChromePasswordImportException {
      rethrow;
    } on FileSystemException {
      throw const ChromePasswordImportException(
        'The selected Chrome password file could not be read.',
      );
    } on FormatException {
      throw const ChromePasswordImportException(
        'The selected file is not a readable Chrome password CSV.',
      );
    }
  }

  ChromePasswordImportData parse(String contents) {
    final rows = csv.decode(contents);
    if (rows.isEmpty) {
      throw const ChromePasswordImportException(
        'The selected Chrome password CSV is empty.',
      );
    }

    final headerIndexes = <String, int>{};
    for (var index = 0; index < rows.first.length; index++) {
      final header = rows.first[index]
          .toString()
          .replaceFirst('\ufeff', '')
          .trim()
          .toLowerCase();
      if (header.isNotEmpty) {
        headerIndexes[header] = index;
      }
    }

    const requiredHeaders = ['url', 'username', 'password'];
    if (requiredHeaders.any((header) => !headerIndexes.containsKey(header))) {
      throw const ChromePasswordImportException(
        'This CSV does not contain Chrome password columns.',
      );
    }

    final entries = <VaultEntry>[];
    var skippedInvalidRows = 0;
    final importedAt = DateTime.now();

    for (final row in rows.skip(1)) {
      final website = _read(row, headerIndexes['url']);
      final password = _read(
        row,
        headerIndexes['password'],
        trimWhitespace: false,
      );
      if (website.isEmpty || password.isEmpty) {
        if (row.any((value) => value.toString().trim().isNotEmpty)) {
          skippedInvalidRows++;
        }
        continue;
      }

      final exportedName = _read(row, headerIndexes['name']);
      entries.add(
        VaultEntry(
          id: createVaultId(),
          title: exportedName.isEmpty
              ? _titleFromWebsite(website)
              : exportedName,
          username: _read(
            row,
            headerIndexes['username'],
            trimWhitespace: false,
          ),
          email: '',
          password: password,
          website: website,
          category: 'Google Chrome',
          accountId: '',
          recoveryContact: '',
          twoFactorNotes: '',
          tags: '',
          notes: _read(row, headerIndexes['note'], trimWhitespace: false),
          createdAt: importedAt,
          updatedAt: importedAt,
        ),
      );
    }

    return ChromePasswordImportData(
      entries: entries,
      skippedInvalidRows: skippedInvalidRows,
    );
  }

  String _read(List<dynamic> row, int? index, {bool trimWhitespace = true}) {
    if (index == null || index >= row.length) {
      return '';
    }
    final value = row[index].toString();
    return trimWhitespace ? value.trim() : value;
  }

  String _titleFromWebsite(String website) {
    final uri = Uri.tryParse(website);
    final host = uri?.host ?? '';
    if (host.isNotEmpty) {
      return host.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
    }
    return website;
  }
}

class ChromePasswordManagerLauncher {
  const ChromePasswordManagerLauncher();

  static const String _chromeSettingsUrl =
      'https://passwords.google.com/options';
  static final Uri _googlePasswordManagerUrl = Uri.parse(_chromeSettingsUrl);

  Future<void> open() async {
    if (await _tryOpenChrome()) {
      return;
    }

    bool launched;
    try {
      launched = await launchUrl(
        _googlePasswordManagerUrl,
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      launched = false;
    }
    if (!launched) {
      throw const ChromePasswordImportException(
        'Google Chrome or Google Password Manager could not be opened.',
      );
    }
  }

  Future<bool> _tryOpenChrome() async {
    if (Platform.isWindows) {
      final environment = Platform.environment;
      final candidates = <String>[
        if (environment['PROGRAMFILES'] case final path?)
          '$path\\Google\\Chrome\\Application\\chrome.exe',
        if (environment['PROGRAMFILES(X86)'] case final path?)
          '$path\\Google\\Chrome\\Application\\chrome.exe',
        if (environment['LOCALAPPDATA'] case final path?)
          '$path\\Google\\Chrome\\Application\\chrome.exe',
      ];

      for (final executable in candidates) {
        if (await File(executable).exists()) {
          try {
            await Process.start(executable, const [
              _chromeSettingsUrl,
            ], mode: ProcessStartMode.detached);
            return true;
          } on ProcessException {
            continue;
          }
        }
      }
      return false;
    }

    if (Platform.isMacOS) {
      try {
        await Process.start('open', const [
          '-a',
          'Google Chrome',
          _chromeSettingsUrl,
        ], mode: ProcessStartMode.detached);
        return true;
      } on ProcessException {
        return false;
      }
    }

    if (Platform.isLinux) {
      for (final executable in const [
        'google-chrome',
        'google-chrome-stable',
        'chromium',
        'chromium-browser',
      ]) {
        try {
          await Process.start(executable, const [
            _chromeSettingsUrl,
          ], mode: ProcessStartMode.detached);
          return true;
        } on ProcessException {
          continue;
        }
      }
    }

    return false;
  }
}
