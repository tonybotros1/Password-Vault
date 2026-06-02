import 'package:flutter/material.dart';

import '../services/vault_store.dart';
import '../views/screens/vault_home_page.dart';
import 'app_theme.dart';

class PasswordVaultApp extends StatelessWidget {
  const PasswordVaultApp({super.key, this.store});

  final VaultStore? store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Password Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: VaultHomePage(store: store ?? VaultStore()),
    );
  }
}
