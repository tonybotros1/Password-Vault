import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class EmailRecoveryException implements Exception {
  const EmailRecoveryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecoveryIdentity {
  const RecoveryIdentity({required this.userId, required this.email});

  final String userId;
  final String email;
}

class EmailRecoveryAuthEvent {
  const EmailRecoveryAuthEvent({
    required this.identity,
    required this.isPasswordRecovery,
  });

  final RecoveryIdentity identity;
  final bool isPasswordRecovery;
}

abstract class EmailRecoveryService {
  Stream<EmailRecoveryAuthEvent> get authEvents;
  RecoveryIdentity? get currentIdentity;

  Future<void> beginEmailLink(String email);
  Future<void> requestPasswordReset(String email);
  Future<void> saveRecoveryKey({
    required String userId,
    required List<int> recoveryKey,
  });
  Future<List<int>> loadRecoveryKey(String userId);
  Future<void> completeRecoverySession();
  Future<void> signOut();
}

class EmailRecoveryBootstrap {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String callbackUrl = 'passwordvault://recovery-callback';

  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;

  static Future<EmailRecoveryService?> initialize() async {
    if (!isConfigured) {
      return null;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        persistSession: true,
      ),
    );

    return SupabaseEmailRecoveryService(Supabase.instance.client);
  }
}

class SupabaseEmailRecoveryService implements EmailRecoveryService {
  SupabaseEmailRecoveryService(this._client);

  final SupabaseClient _client;

  @override
  Stream<EmailRecoveryAuthEvent> get authEvents => _client
      .auth
      .onAuthStateChange
      .where(
        (state) =>
            state.session?.user.email != null &&
            (state.event == AuthChangeEvent.signedIn ||
                state.event == AuthChangeEvent.passwordRecovery ||
                state.event == AuthChangeEvent.initialSession),
      )
      .map(
        (state) => EmailRecoveryAuthEvent(
          identity: RecoveryIdentity(
            userId: state.session!.user.id,
            email: state.session!.user.email!,
          ),
          isPasswordRecovery: state.event == AuthChangeEvent.passwordRecovery,
        ),
      );

  @override
  RecoveryIdentity? get currentIdentity {
    final user = _client.auth.currentSession?.user;
    final email = user?.email;
    if (user == null || email == null) {
      return null;
    }
    return RecoveryIdentity(userId: user.id, email: email);
  }

  @override
  Future<void> beginEmailLink(String email) async {
    try {
      await _client.auth.signOut();
      await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: _randomAccountPassword(),
        emailRedirectTo: EmailRecoveryBootstrap.callbackUrl,
      );
    } on AuthException catch (error) {
      throw EmailRecoveryException(error.message);
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _client.auth.signOut();
      await _client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: EmailRecoveryBootstrap.callbackUrl,
      );
    } on AuthException catch (error) {
      throw EmailRecoveryException(error.message);
    }
  }

  @override
  Future<void> saveRecoveryKey({
    required String userId,
    required List<int> recoveryKey,
  }) async {
    _requireMatchingSession(userId);
    try {
      await _client.from('vault_recovery_keys').upsert({
        'user_id': userId,
        'recovery_key': base64Encode(recoveryKey),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } on PostgrestException catch (error) {
      throw EmailRecoveryException(error.message);
    }
  }

  @override
  Future<List<int>> loadRecoveryKey(String userId) async {
    _requireMatchingSession(userId);
    try {
      final row = await _client
          .from('vault_recovery_keys')
          .select('recovery_key')
          .eq('user_id', userId)
          .single();
      final encodedKey = row['recovery_key'];
      if (encodedKey is! String) {
        throw const EmailRecoveryException(
          'No recovery key was found for this vault.',
        );
      }
      final key = base64Decode(encodedKey);
      if (key.length != 32) {
        throw const EmailRecoveryException(
          'The stored recovery key is not valid.',
        );
      }
      return key;
    } on EmailRecoveryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw EmailRecoveryException(error.message);
    } on FormatException {
      throw const EmailRecoveryException(
        'The stored recovery key is not valid.',
      );
    }
  }

  @override
  Future<void> completeRecoverySession() async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: _randomAccountPassword()),
      );
      await _client.auth.signOut(scope: SignOutScope.global);
    } on AuthException catch (error) {
      throw EmailRecoveryException(error.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.global);
    } on AuthException catch (error) {
      throw EmailRecoveryException(error.message);
    }
  }

  void _requireMatchingSession(String userId) {
    if (_client.auth.currentSession?.user.id != userId) {
      throw const EmailRecoveryException(
        'The verified email session does not match this vault.',
      );
    }
  }

  String _randomAccountPassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(48, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}

String emailRecoveryErrorMessage(Object error) {
  if (error is EmailRecoveryException) {
    return error.message;
  }
  if (error is AuthException) {
    return error.message;
  }
  if (error is PostgrestException) {
    return error.message;
  }
  return 'Email recovery could not be completed.';
}
