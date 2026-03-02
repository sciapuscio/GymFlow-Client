import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'constants.dart';

class UpdateCheckResult {
  final bool updateRequired;
  final String currentVersion;
  final String minVersion;
  final String? androidUrl;
  final String? iosUrl;

  const UpdateCheckResult({
    required this.updateRequired,
    required this.currentVersion,
    required this.minVersion,
    this.androidUrl,
    this.iosUrl,
  });
}

class AppVersionService {
  /// Fetches minimum required version from server and compares with the
  /// installed version. Returns an [UpdateCheckResult].
  ///
  /// On network error, returns [updateRequired: false] so the app is never
  /// blocked by a connectivity issue.
  static Future<UpdateCheckResult> check() async {
    String currentVersion = '0.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version; // e.g. "1.0.5"
      debugPrint('[AppVersion] installed: $currentVersion');

      final uri = Uri.parse('${AppConstants.baseUrl}/api/app-version.php');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        debugPrint('[AppVersion] server returned ${response.statusCode} — skipping check');
        return UpdateCheckResult(
          updateRequired: false,
          currentVersion: currentVersion,
          minVersion: '?',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final minVersion = (data['min_version'] as String?) ?? '1.0.0';
      final androidUrl = data['android_url'] as String?;
      final iosUrl = data['ios_url'] as String?;

      debugPrint('[AppVersion] min required: $minVersion');

      final required = _isOutdated(currentVersion, minVersion);
      debugPrint('[AppVersion] update required: $required');

      return UpdateCheckResult(
        updateRequired: required,
        currentVersion: currentVersion,
        minVersion: minVersion,
        androidUrl: androidUrl,
        iosUrl: iosUrl,
      );
    } catch (e) {
      // Network error → never block the user
      debugPrint('[AppVersion] check failed (non-critical): $e');
      return UpdateCheckResult(
        updateRequired: false,
        currentVersion: currentVersion,
        minVersion: '?',
      );
    }
  }

  /// Returns true when [installed] < [required] using semantic versioning.
  /// Compares up to 3 parts (major.minor.patch). Non-numeric parts are treated as 0.
  static bool _isOutdated(String installed, String required) {
    final a = _parse(installed);
    final b = _parse(required);
    for (int i = 0; i < 3; i++) {
      if (a[i] < b[i]) return true;
      if (a[i] > b[i]) return false;
    }
    return false; // equal → not outdated
  }

  static List<int> _parse(String version) {
    final parts = version.split('.');
    return List.generate(3, (i) {
      if (i >= parts.length) return 0;
      return int.tryParse(parts[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    });
  }
}
