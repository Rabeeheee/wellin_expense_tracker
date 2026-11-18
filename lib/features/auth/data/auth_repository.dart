import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_config.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/profile.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;
  bool _googleInitialized = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _webGoogleSub;
  bool _webGoogleListenerAttached = false;
  /// Raw nonce for web GIS → Supabase. Google gets the SHA-256 hex form.
  String? _googleRawNonce;

  static String _generateRawNonce([int length = 32]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  void _log(String message) {
    debugPrint('[Auth/Google] $message');
  }

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  String? get userId => currentUser?.id;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'role': role.value,
      },
    );
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) {
      _log('GoogleSignIn already initialized');
      return;
    }
    final webClientId = AppConfig.googleWebClientId;
    final iosClientId = AppConfig.googleIosClientId;
    final useIosClientId =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        iosClientId.isNotEmpty;
    // Web needs the OAuth web client as clientId (+ meta tag in index.html).
    final clientId = kIsWeb
        ? (webClientId.isEmpty ? null : webClientId)
        : (useIosClientId ? iosClientId : null);
    final serverClientId =
        kIsWeb || webClientId.isEmpty ? null : webClientId;
    // Web GIS previously sent nonce as the literal string "null", which
    // breaks Supabase (claim present, param absent). Always pair a real nonce.
    String? hashedNonce;
    if (kIsWeb) {
      _googleRawNonce = _generateRawNonce();
      hashedNonce = sha256.convert(utf8.encode(_googleRawNonce!)).toString();
    } else {
      _googleRawNonce = null;
    }
    _log(
      'Initializing GoogleSignIn. '
      'kIsWeb=$kIsWeb '
      'GOOGLE_WEB_CLIENT_ID set=${webClientId.isNotEmpty} '
      '(length=${webClientId.length}), '
      'GOOGLE_IOS_CLIENT_ID set=${iosClientId.isNotEmpty} '
      '(length=${iosClientId.length}), '
      'clientId=${clientId != null}, serverClientId=${serverClientId != null}, '
      'nonce=${hashedNonce != null}',
    );
    try {
      await GoogleSignIn.instance.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
        nonce: hashedNonce,
      );
      _googleInitialized = true;
      _log('GoogleSignIn.initialize() succeeded');
    } catch (e, st) {
      _log('GoogleSignIn.initialize() FAILED: $e');
      _log('Stack: $st');
      rethrow;
    }
  }

  /// Web cannot call [GoogleSignIn.authenticate]. Listen for GIS button events
  /// and complete Supabase sign-in with the idToken.
  Future<void> attachWebGoogleSignInListener({
    VoidCallback? onSignInStarted,
    void Function(Object error)? onError,
  }) async {
    if (!kIsWeb || _webGoogleListenerAttached) return;
    if (AppConfig.googleWebClientId.isEmpty) return;

    await _ensureGoogleInitialized();
    _webGoogleListenerAttached = true;
    _log('Attaching web Google authenticationEvents listener');

    _webGoogleSub = GoogleSignIn.instance.authenticationEvents.listen(
      (event) async {
        if (event is! GoogleSignInAuthenticationEventSignIn) return;
        try {
          onSignInStarted?.call();
          _log(
            'Web Google sign-in event. email=${event.user.email}',
          );
          await _completeGoogleWithAccount(event.user);
        } catch (e, st) {
          _log('Web Google complete failed: $e');
          _log('Stack: $st');
          onError?.call(e);
        }
      },
      onError: (Object e, StackTrace st) {
        _log('Web Google authenticationEvents error: $e');
        _log('Stack: $st');
        onError?.call(e);
      },
    );
  }

  Future<AuthResponse> _completeGoogleWithAccount(
    GoogleSignInAccount account,
  ) async {
    final idToken = account.authentication.idToken;
    _log(
      'idToken present=${idToken != null} length=${idToken?.length ?? 0}',
    );
    if (idToken == null) {
      throw Exception(
        'Google sign-in failed: missing idToken. '
        'Check GOOGLE_WEB_CLIENT_ID and Supabase Google provider settings.',
      );
    }

    _log(
      'Calling Supabase signInWithIdToken(provider=google)... '
      'nonce=${_googleRawNonce != null}',
    );
    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: _googleRawNonce,
    );
    _log(
      'Supabase signInWithIdToken ok. '
      'userId=${response.user?.id}, email=${response.user?.email}',
    );
    return response;
  }

  Future<AuthResponse> signInWithGoogle() async {
    _log('signInWithGoogle() started');
    try {
      if (AppConfig.googleWebClientId.isEmpty) {
        _log('ABORT: GOOGLE_WEB_CLIENT_ID is empty');
        throw Exception(
          'Google Sign-In is not configured yet.\n'
          'Add a Google Cloud Web client ID as GOOGLE_WEB_CLIENT_ID, '
          'enable Google in Supabase Auth, then restart the app.\n'
          'Until then, use email + password.',
        );
      }

      if (kIsWeb) {
        throw Exception(
          'On web, use the Google button below (GIS). '
          'Programmatic authenticate() is not supported in browsers.',
        );
      }

      await _ensureGoogleInitialized();

      _log('Calling GoogleSignIn.authenticate()...');
      final account = await GoogleSignIn.instance.authenticate();
      _log(
        'authenticate() ok. email=${account.email}, '
        'id=${account.id}, displayName=${account.displayName}',
      );
      return _completeGoogleWithAccount(account);
    } on GoogleSignInException catch (e, st) {
      _log('GoogleSignInException code=${e.code} description=${e.description}');
      _log('Stack: $st');
      final message = switch (e.code) {
        GoogleSignInExceptionCode.clientConfigurationError =>
          'Google Sign-In misconfigured: serverClientId (Web client ID) '
              'is required on Android. Set GOOGLE_WEB_CLIENT_ID and restart.',
        GoogleSignInExceptionCode.canceled => 'Google Sign-In was canceled.',
        _ => 'Google Sign-In failed: ${e.description ?? e.code.name}',
      };
      throw Exception(message);
    } catch (e, st) {
      _log('signInWithGoogle() FAILED: $e');
      _log('Type: ${e.runtimeType}');
      _log('Stack: $st');
      rethrow;
    }
  }

  Future<void> completeProfile({
    required String name,
    required UserRole role,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not signed in');

    await _client.auth.updateUser(
      UserAttributes(data: {'name': name, 'role': role.value}),
    );

    final existing = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (existing != null) {
      await _client.from('profiles').update({'name': name}).eq('id', user.id);
      return;
    }

    final supers = await _client
        .from('profiles')
        .select('id')
        .eq('role', UserRole.superAdmin.value)
        .eq('status', UserStatus.active.value);

    final hasSuper = (supers as List).isNotEmpty;

    late final UserRole finalRole;
    late final UserStatus finalStatus;

    if (role == UserRole.superAdmin) {
      finalRole = UserRole.superAdmin;
      finalStatus = hasSuper ? UserStatus.pending : UserStatus.active;
    } else {
      finalRole = UserRole.admin;
      finalStatus = UserStatus.active;
    }

    await _client.from('profiles').insert({
      'id': user.id,
      'name': name,
      'email': user.email ?? '',
      'role': finalRole.value,
      'status': finalStatus.value,
    });
  }

  Future<Profile?> fetchMyProfile() async {
    final id = userId;
    if (id == null) return null;
    final row =
        await _client.from('profiles').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(row);
  }

  Future<bool> hasActiveSuperAdmin() async {
    try {
      final result = await _client.rpc('has_active_super_admin');
      return result == true;
    } catch (e) {
      debugPrint('[Auth] has_active_super_admin rpc failed: $e');
      // Fallback if PostgREST schema cache hasn't picked up the RPC yet.
      final rows = await _client
          .from('profiles')
          .select('id')
          .eq('role', UserRole.superAdmin.value)
          .eq('status', UserStatus.active.value)
          .limit(1);
      return (rows as List).isNotEmpty;
    }
  }

  Future<Profile> claimSuperAdminIfNone() async {
    try {
      final row = await _client.rpc('claim_super_admin_if_none');
      if (row is Map<String, dynamic>) {
        return Profile.fromJson(row);
      }
      if (row is List && row.isNotEmpty) {
        return Profile.fromJson(row.first as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[Auth] claim_super_admin_if_none rpc failed: $e');
      // Fallback path when RPC isn't visible yet: only if none are active.
      final has = await hasActiveSuperAdmin();
      if (has) {
        throw Exception('A super admin already exists');
      }
      final id = userId;
      if (id == null) throw Exception('Not signed in');
      await _client.from('profiles').update({
        'role': UserRole.superAdmin.value,
        'status': UserStatus.active.value,
      }).eq('id', id);
    }
    final profile = await fetchMyProfile();
    if (profile == null || !profile.isSuperAdmin) {
      throw Exception('Could not claim super admin');
    }
    return profile;
  }

  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String contentType,
  }) async {
    final ext = contentType.contains('png')
        ? 'png'
        : contentType.contains('webp')
            ? 'webp'
            : 'jpg';
    final path = '$userId/avatar.$ext';
    await _client.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );
    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    // Bust CDN/cache after replace.
    final withCacheBust =
        '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client
        .from('profiles')
        .update({'avatar_url': withCacheBust}).eq('id', userId);
    return withCacheBust;
  }

  /// Sends a password-reset email. [redirectTo] must be allow-listed in
  /// Supabase Auth → URL Configuration.
  Future<void> sendPasswordResetEmail(String email) async {
    final redirectTo = kIsWeb ? _webPasswordResetRedirectTo() : null;
    _log('sendPasswordResetEmail redirectTo=$redirectTo');
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }

  /// Prefer [AppConfig.webBasePath]; fall back to detecting GitHub Pages path.
  static String _webPasswordResetRedirectTo() {
    final configured = AppConfig.webBasePath.trim();
    final basePath = configured.isNotEmpty
        ? (configured.startsWith('/') ? configured : '/$configured')
            .replaceAll(RegExp(r'/+$'), '')
        : _inferredWebBasePath();
    return '${Uri.base.origin}$basePath/reset-password';
  }

  static String _inferredWebBasePath() {
    final segments = Uri.base.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return '';
    // Project Pages: /wellin_expense_tracker/<route>
    if (segments.first == 'wellin_expense_tracker') {
      return '/wellin_expense_tracker';
    }
    return '';
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() async {
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    await _client.auth.signOut();
  }

  /// Maps Auth/API exceptions to short user-facing copy.
  static String friendlyAuthError(Object error) {
    if (error is AuthException) {
      final code = error.code?.toLowerCase() ?? '';
      final message = error.message.toLowerCase();
      if (code == 'invalid_credentials' ||
          message.contains('invalid login credentials')) {
        return 'Incorrect email or password. '
            'If you signed up with Google, use Continue with Google, '
            'or tap Forgot password to set one.';
      }
      if (code == 'email_not_confirmed' ||
          message.contains('email not confirmed')) {
        return 'Confirm your email before signing in.';
      }
      if (code == 'user_not_found' || message.contains('user not found')) {
        return 'No account found for that email.';
      }
      if (message.contains('rate limit') || code.contains('rate')) {
        return 'Too many attempts. Try again in a few minutes.';
      }
      return error.message;
    }
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    if (raw.contains('Invalid login credentials')) {
      return 'Incorrect email or password. '
          'If you signed up with Google, use Continue with Google, '
          'or tap Forgot password to set one.';
    }
    return raw;
  }

  Future<void> dispose() async {
    await _webGoogleSub?.cancel();
    _webGoogleSub = null;
    _webGoogleListenerAttached = false;
  }
}
