import 'package:flutter/material.dart';

import 'app/password_vault_app.dart';
import 'services/email_recovery_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  EmailRecoveryService? recoveryService;
  try {
    recoveryService = await EmailRecoveryBootstrap.initialize();
  } on Object {
    recoveryService = null;
  }

  runApp(PasswordVaultApp(recoveryService: recoveryService));
}
