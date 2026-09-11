import 'package:flutter/material.dart';

import '../services/vault_store.dart';
import '../services/email_recovery_service.dart';
import '../views/screens/vault_home_page.dart';
import 'app_theme.dart';

class PasswordVaultApp extends StatelessWidget {
  const PasswordVaultApp({super.key, this.store, this.recoveryService});

  final VaultStore? store;
  final EmailRecoveryService? recoveryService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Password Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: VaultHomePage(
        store: store ?? VaultStore(),
        recoveryService: recoveryService,
      ),
    );
  }
}
