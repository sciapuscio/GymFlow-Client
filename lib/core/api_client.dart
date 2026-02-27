import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

/// Central HTTP client for GymFlow API calls.
/// Automatically injects the Bearer token when available.
class ApiClient {
  // ── Token management ─────────────────────────────────────────────────────────

  static Future<String?> getToken() => TokenStorage.read();

  static Future<void> saveToken(String token) => TokenStorage.write(token);

  static Future<void> deleteToken() => TokenStorage.delete();


  // ── HTTP helpers ─────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decode(http.Response res) {
    final rawBody = utf8.decode(res.bodyBytes);
    dynamic body;
    try {
      body = jsonDecode(rawBody);
    } on FormatException {
      // Backend returned non-JSON (PHP error, HTML page, etc.)
      final preview = rawBody.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      throw ApiException(
        preview.length > 200 ? '${preview.substring(0, 200)}…' : preview.isNotEmpty ? preview : 'Respuesta inválida del servidor',
        res.statusCode,
      );
    }
    if (res.statusCode >= 400) {
      final msg = (body is Map ? body['error'] : null) ?? 'Error ${res.statusCode}';
      throw ApiException(msg, res.statusCode);
    }
    return body is Map<String, dynamic> ? body : {'data': body};
  }

  static Future<Map<String, dynamic>> get(String url) async {
    final headers = await _authHeaders();
    final res = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 10));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    final res = await http
        .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    return _decode(res);
  }

  static Future<Map<String, dynamic>> delete(String url) async {
    final headers = await _authHeaders();
    final res = await http
        .delete(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 10));
    return _decode(res);
  }
}

/// Typed API error with HTTP status code.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
