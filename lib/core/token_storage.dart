import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cross-platform token storage.
/// Uses shared_preferences for all platforms (simple key-value store).
/// NOTE: For production Android/iOS builds, use flutter_secure_storage instead
/// by adding it back to pubspec.yaml and restoring the platform-specific logic.
class TokenStorage {
  static const _key = 'gf_member_token';

  static Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> delete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // ── Gym logo URL cache ────────────────────────────────────────────────────
  static const _logoKey = 'gf_gym_logo_url';

  static Future<void> writeGymLogoUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null) {
      await prefs.remove(_logoKey);
    } else {
      await prefs.setString(_logoKey, url);
    }
  }

  static Future<String?> readGymLogoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_logoKey);
  }

  // ── Gym logo bytes (local file cache for instant splash load) ─────────────
  static Future<String> _logoFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/gf_gym_logo_cache.png';
  }

  /// Downloads the gym logo from [url] and saves it as a local file.
  /// Returns the local file path, or null if the download failed.
  static Future<String?> cacheGymLogoBytes(String url) async {
    try {
      final client = http.Client();
      final response = await client.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      client.close();
      if (response.statusCode == 200) {
        final path = await _logoFilePath();
        await File(path).writeAsBytes(response.bodyBytes);
        return path;
      }
    } catch (_) {}
    return null;
  }

  /// Returns the local file path of the cached logo, or null if not cached.
  static Future<String?> readGymLogoFilePath() async {
    final path = await _logoFilePath();
    if (await File(path).exists()) return path;
    return null;
  }

  /// Deletes the cached logo file.
  static Future<void> deleteGymLogoBytes() async {
    try {
      final path = await _logoFilePath();
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // ── Environment persistence ───────────────────────────────────────────────
  static const _envKey = 'gf_environment';

  /// Persists [isDev] so subsequent app launches restore the same server.
  static Future<void> writeEnvironment(bool isDev) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_envKey, isDev ? 'dev' : 'prod');
  }

  /// Returns true if dev, false if prod, or **null** if this has never been set
  /// (e.g., the user had a session before the env-switcher feature existed).
  static Future<bool?> readEnvironment() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_envKey);
    if (val == null) return null; // never persisted
    return val == 'dev';
  }

  /// Clears the persisted environment (resets to prod).
  static Future<void> deleteEnvironment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_envKey);
  }
}
