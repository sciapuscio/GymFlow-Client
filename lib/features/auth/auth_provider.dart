import 'package:flutter/foundation.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
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
    // ── Restore environment FIRST (dev vs prod) ───────────────────────────
    final savedEnv = await TokenStorage.readEnvironment();
    // null = env was never saved (session pre-dates this feature).
    // Default to dev to match the old hardcoded baseUrl behavior so existing
    // sessions are not invalidated.
    final isDev = savedEnv ?? true;
    AppConstants.setEnvironment(dev: isDev);
    debugPrint('=== INIT: environment = ${isDev ? "DEV" : "PROD"} (${savedEnv == null ? "legacy default" : "persisted"})');

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
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
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
    await AuthRepository.logout();
    _member = null;
    _cachedLogoUrl = null;
    _cachedLogoFilePath = null;
    await TokenStorage.writeGymLogoUrl(null);
    await TokenStorage.deleteGymLogoBytes();
    await TokenStorage.deleteEnvironment(); // reset to production on logout
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
