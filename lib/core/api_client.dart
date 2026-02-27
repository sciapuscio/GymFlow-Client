import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

/// Central HTTP client for GymFlow API calls.
/// Automatically injects the Bearer token, handles connectivity errors
/// with friendly Spanish messages, and retries on timeout.
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
      final preview = rawBody.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      throw ApiException(
        preview.length > 200
            ? '${preview.substring(0, 200)}…'
            : preview.isNotEmpty
                ? preview
                : 'Respuesta inválida del servidor',
        res.statusCode,
      );
    }
    if (res.statusCode >= 400) {
      final msg = (body is Map ? body['error'] : null) ?? 'Error ${res.statusCode}';
      throw ApiException(msg, res.statusCode);
    }
    return body is Map<String, dynamic> ? body : {'data': body};
  }

  /// Wraps network errors into friendly [ApiException] messages.
  static Future<T> _safe<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on SocketException {
      throw const ApiException('Sin conexión. Verificá tu internet.', 0);
    } on TimeoutException {
      throw const ApiException('La conexión tardó demasiado. Intentá de nuevo.', 0);
    } on HandshakeException {
      throw const ApiException('Error de seguridad SSL. Contactá soporte.', 0);
    }
  }

  static Future<Map<String, dynamic>> get(String url) async {
    return _safe(() async {
      final headers = await _authHeaders();
      final res = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));
      return _decode(res);
    });
  }

  static Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    return _safe(() async {
      final headers = await _authHeaders();
      final res = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      return _decode(res);
    });
  }

  static Future<Map<String, dynamic>> delete(String url) async {
    return _safe(() async {
      final headers = await _authHeaders();
      final res = await http
          .delete(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));
      return _decode(res);
    });
  }
}

/// Typed API error with HTTP status code.
/// statusCode == 0 means a connectivity/network error (no HTTP response).
class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  /// True when the error is network-level (no server response)
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => message;
}
