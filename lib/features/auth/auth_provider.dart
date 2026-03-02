import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/api_client.dart';
import '../../core/app_version_service.dart';
import '../../core/constants.dart';
import '../../core/notification_service.dart';
import '../../core/saved_account.dart';
import '../../core/token_storage.dart';
import '../../models/member.dart';
import 'auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Global auth state — provided at the root of the widget tree.
class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  Member? _member;
  String? _error;
  bool _loading = false;
  /// true cuando el splash puede navegar (min duration cumplida)
  bool _splashReady = false;
  bool get splashReady => _splashReady;
  /// URL del logo cacheada en SharedPreferences
  String? _cachedLogoUrl;
  /// Ruta local del archivo de imagen del logo (cargada sin red)
  String? _cachedLogoFilePath;

  AuthStatus get status => _status;
  Member? get member => _member;
  String? get error => _error;
  bool get loading => _loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool _mustChangePassword = false;
  bool get mustChangePassword => _mustChangePassword;
  String? _token;
  String? get token => _token;
  /// URL del logo del gym (para comparaciones de cambio)
  String? get gymLogoUrl => _member?.gym?.logoPath ?? _cachedLogoUrl;
  /// Ruta local del archivo de imagen — disponible sin red para el splash
  String? get gymLogoFilePath => _cachedLogoFilePath;

  // ── Multi-account ─────────────────────────────────────────────────────────
  List<SavedAccount> _savedAccounts = [];
  List<SavedAccount> get savedAccounts => List.unmodifiable(_savedAccounts);

  Future<void> _loadSavedAccounts() async {
    _savedAccounts = await TokenStorage.readAccounts();
  }

  /// Switches the active account. Restores env, token, logo and refreshes member data.
  Future<void> switchAccount(SavedAccount account) async {
    _loading = true;
    notifyListeners();
    // Persist the new active token
    await TokenStorage.setActiveAccount(account.token);
    // Restore environment
    final isDev = account.env == 'dev';
    AppConstants.setEnvironment(dev: isDev);
    await TokenStorage.writeEnvironment(isDev);
    // Update in-memory state
    _token = account.token;
    _cachedLogoUrl = account.gymLogoUrl;
    _cachedLogoFilePath = null;
    await TokenStorage.writeGymLogoUrl(account.gymLogoUrl);
    if (account.gymLogoUrl != null) {
      _cachedLogoFilePath = await TokenStorage.cacheGymLogoBytes(account.gymLogoUrl!);
    }
    _status = AuthStatus.authenticated;
    _savedAccounts = await TokenStorage.readAccounts();
    _loading = false;
    notifyListeners();
    // Refresh member data in background
    refresh();
  }

  // ── Force update ──────────────────────────────────────────────────────────
  bool _updateRequired = false;
  bool get updateRequired => _updateRequired;
  String _currentVersion = '?';
  String get currentVersion => _currentVersion;
  String _minVersion = '?';
  String get minVersion => _minVersion;
  String? _storeUrl;
  String? get storeUrl => _storeUrl;

  /// Called by the SplashScreen as a last resort if init() is hanging.
  void forceTimeout() {
    debugPrint('=== forceTimeout: status was $_status');
    if (_status == AuthStatus.unknown) {
      _status = AuthStatus.unauthenticated;
    }
    _splashReady = true; // unblock router
    notifyListeners();
  }

  // ── Initialization: called at app startup ────────────────────────────────────
  // Always waits at least 2.5 s so the splash breathing animation is visible.
  Future<void> init() async {
    try {
      // Hard 8-second cap — _doInit() must complete within this time.
      await _doInit().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('=== INIT error (caught): $e');
      if (_status == AuthStatus.unknown) {
        _status = AuthStatus.unauthenticated;
      }
      _splashReady = true; // always unblock splash on error
    }
    // ALWAYS notify — this triggers the router redirect out of the splash.
    notifyListeners();
  }

  Future<void> _doInit() async {
    await _loadSavedAccounts();
    // ── 0. Restore environment FIRST — version check needs the correct baseUrl ─
    final savedEnv = await TokenStorage.readEnvironment();
    // null = env was never saved (pre-dates this feature). Default to dev so
    // existing sessions are not invalidated.
    final isDev = savedEnv ?? true;
    AppConstants.setEnvironment(dev: isDev);
    debugPrint('=== INIT: environment = ${isDev ? "DEV" : "PROD"} (${savedEnv == null ? "legacy default" : "persisted"})');

    // ── 1. Version check (before auth, blocks everything if outdated) ─────────
    try {
      final result = await AppVersionService.check();
      _currentVersion = result.currentVersion;
      _minVersion     = result.minVersion;
      _updateRequired = result.updateRequired;
      _storeUrl       = result.androidUrl;
      debugPrint('[AppVersion] current=$_currentVersion  min=$_minVersion  blocked=$_updateRequired');
      if (result.updateRequired) {
        // Unblock splash so the router can redirect to /force-update
        _splashReady = true;
        return;
      }
    } catch (e) {
      debugPrint('[AppVersion] check error (ignored, fail-open): $e');
    }

    // Load cached gym logo FIRST and notify so the splash rebuilds with it
    _cachedLogoUrl = await TokenStorage.readGymLogoUrl();
    _cachedLogoFilePath = await TokenStorage.readGymLogoFilePath();
    final hasLogo = _cachedLogoFilePath != null || _cachedLogoUrl != null;
    if (hasLogo) {
      notifyListeners(); // splash rebuilds → shows gym logo breathing
    }
    debugPrint('=== INIT: cached logo file = ${_cachedLogoFilePath ?? 'none'}');

    final token = await ApiClient.getToken();
    debugPrint('=== INIT: token from storage = "${token?.substring(0, 8) ?? 'NULL'}"');

    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      debugPrint('=== INIT: no token → unauthenticated');
      // No logo, no delay needed
      _splashReady = true;
      return;
    }

    _status = AuthStatus.authenticated;
    debugPrint('=== INIT: token found → authenticated (member data loads lazily)');

    // If we have a gym logo, hold on the splash for at least 2s so the
    // user actually sees the gym branding before navigating away.
    if (hasLogo) {
      await Future.delayed(const Duration(milliseconds: 2000));
    }
    _splashReady = true;
  }

  // ── Login ────────────────────────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
    required String gymSlug,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await AuthRepository.login(
        email: email,
        password: password,
        gymSlug: gymSlug,
      );
      _token = result['token'] as String?;
      _member = Member.fromJson(result['member'] as Map<String, dynamic>);
      _mustChangePassword = result['member']?['must_change_password'] == true;
      _status = AuthStatus.authenticated;
      _loading = false;
      // Cache gym logo (URL + download bytes) on login
      final logoUrl = _member?.gym?.logoPath;
      _cachedLogoUrl = logoUrl;
      await TokenStorage.writeGymLogoUrl(logoUrl);
      if (logoUrl != null) {
        _cachedLogoFilePath = await TokenStorage.cacheGymLogoBytes(logoUrl);
      }
      // ── Save account to multi-account list ──────────────────────────────
      final currentEnv = AppConstants.isDev ? 'dev' : 'prod';
      await TokenStorage.addOrUpdateAccount(SavedAccount(
        token: _token!,
        memberName: _member?.name ?? '',
        gymName: _member?.gym?.name ?? gymSlug,
        gymSlug: gymSlug,
        gymLogoUrl: logoUrl,
        env: currentEnv,
        isActive: true,
      ));
      _savedAccounts = await TokenStorage.readAccounts();
      notifyListeners();
      // Register FCM token with backend (fire-and-forget)
      _registerFcmToken();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Silently uploads the FCM device token to the backend after login.
  Future<void> _registerFcmToken() async {
    try {
      final fcmToken = await NotificationService.getToken();
      if (fcmToken == null || _token == null) return;
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/member-register-token.php'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcm_token': fcmToken, 'platform': 'android'}),
      );
      debugPrint('[FCM] Token registered');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  // ── Register ─────────────────────────────────────────────────────────────────
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String gymSlug,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await AuthRepository.register(
        name: name,
        email: email,
        password: password,
        gymSlug: gymSlug,
      );
      _member = Member.fromJson(result['member'] as Map<String, dynamic>);
      _status = AuthStatus.authenticated;
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Refresh member data ───────────────────────────────────────────────────────
  bool _loadingMember = false;
  bool get loadingMember => _loadingMember;

  Future<void> refresh() async {
    if (_loadingMember) return; // guard: avoid concurrent refresh calls
    _loadingMember = true;
    notifyListeners();
    try {
      _member = await AuthRepository.getMe();
      debugPrint('=== REFRESH: member loaded OK → ${_member?.name}');
      // Update cached logo if it changed (e.g. gym updated their image)
      final newLogo = _member?.gym?.logoPath;
      if (newLogo != _cachedLogoUrl) {
        _cachedLogoUrl = newLogo;
        await TokenStorage.writeGymLogoUrl(newLogo);
        // Re-download the image bytes with the new URL
        if (newLogo != null) {
          _cachedLogoFilePath = await TokenStorage.cacheGymLogoBytes(newLogo);
        } else {
          _cachedLogoFilePath = null;
          await TokenStorage.deleteGymLogoBytes();
        }
        debugPrint('=== REFRESH: gym logo updated → $newLogo');
      }
    } on ApiException catch (e) {
      debugPrint('=== REFRESH: ApiException ${e.statusCode}: ${e.message}');
      // Don't delete token here — a transient 401 shouldn't kill the session.
    } catch (e) {
      debugPrint('=== REFRESH: error → $e');
    } finally {
      _loadingMember = false;
      notifyListeners();
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    final currentToken = _token;
    await AuthRepository.logout();
    // Remove this account from the saved list
    if (currentToken != null) {
      await TokenStorage.removeAccount(currentToken);
    }
    _savedAccounts = await TokenStorage.readAccounts();
    // If there are other saved accounts, switch to the first one instead of fully logging out
    if (_savedAccounts.isNotEmpty) {
      await switchAccount(_savedAccounts.first);
      return;
    }
    // Full logout — no other accounts
    _member = null;
    _token = null;
    _cachedLogoUrl = null;
    _cachedLogoFilePath = null;
    await TokenStorage.writeGymLogoUrl(null);
    await TokenStorage.deleteGymLogoBytes();
    await TokenStorage.delete();
    await TokenStorage.deleteEnvironment();
    AppConstants.setEnvironment(dev: false);
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearMustChangePassword() {
    _mustChangePassword = false;
    notifyListeners();
  }
}
