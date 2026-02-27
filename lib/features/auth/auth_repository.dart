import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/member.dart';


/// All API calls related to member authentication.
class AuthRepository {
  /// Login with full email (e.g. juan@microssfit) — parses gym_slug from the address.
  /// The last segment after '@' is used as gym_slug.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String gymSlug,
    String device = 'Flutter App',
  }) async {
    final result = await ApiClient.post(
      '${AppConstants.memberAuthUrl}?action=login',
      {
        'email': email.trim().toLowerCase(),
        'password': password,
        'gym_slug': gymSlug.trim().toLowerCase(),
        'device': device,
      },
    );
    // Persists token in secure storage
    if (result['token'] != null) {
      await ApiClient.saveToken(result['token'] as String);
    }
    return result;
  }

  /// Register a new member account.
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String gymSlug,
    String device = 'Flutter App',
  }) async {
    final result = await ApiClient.post(
      '${AppConstants.memberAuthUrl}?action=register',
      {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'gym_slug': gymSlug.trim().toLowerCase(),
        'device': device,
      },
    );
    if (result['token'] != null) {
      await ApiClient.saveToken(result['token'] as String);
    }
    return result;
  }

  /// Fetch the current member's profile + active membership.
  static Future<Member> getMe() async {
    final data = await ApiClient.get('${AppConstants.memberAuthUrl}?action=me');
    return Member.fromJson(data);
  }

  /// Logout: revoke token on server + delete locally.
  static Future<void> logout() async {
    try {
      await ApiClient.delete('${AppConstants.memberAuthUrl}?action=logout');
    } catch (_) {
      // If network fails, still clear local token
    }
    await ApiClient.deleteToken();
  }

  /// Returns true if a stored token exists (does NOT validate with server).
  static Future<bool> hasToken() async {
    final token = await ApiClient.getToken();
    return token != null && token.isNotEmpty;
  }

  /// Delete token locally only — does NOT call the server logout endpoint.
  static Future<void> clearLocalToken() => ApiClient.deleteToken();
}
