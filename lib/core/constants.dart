/// GymFlow — Core constants
library;

import 'package:flutter/material.dart';

class AppConstants {
  // ── Environment URLs ─────────────────────────────────────────────────────────
  static const String _prodUrl = 'https://sistema.gymflow.com.ar';
  static const String _devUrl  = 'https://training.access.ly';

  /// Current active base URL. Changed at runtime via [setEnvironment].
  static String _baseUrl = _prodUrl;

  /// Whether the app is currently targeting the development server.
  static bool isDev = false;

  /// Switch the environment for all subsequent API calls.
  /// Pass [dev: true] to target the training/dev server.
  static void setEnvironment({required bool dev}) {
    isDev = dev;
    _baseUrl = dev ? _devUrl : _prodUrl;
  }

  // ── Auth endpoints (always computed from the current baseUrl) ────────────────
  /// Public read-only access to the active base URL (for image path construction, etc.)
  static String get baseUrl => _baseUrl;

  static String get memberAuthUrl => '$_baseUrl/api/member-auth.php';
  static String get checkinUrl    => '$_baseUrl/api/checkin.php';
  static String get schedulesUrl  => '$_baseUrl/api/member-schedules.php';
  static String get bookingsUrl   => '$_baseUrl/api/member-bookings.php';
  static String get gymPortalUrl  => '$_baseUrl/api/gym-portal.php';
  static String get changePasswordUrl => '$_baseUrl/api/member-change-password.php';
  static String get sedePreferenceUrl => '$_baseUrl/api/member-sede-preference.php';
  static String get rmCalculatorUrl   => '$_baseUrl/api/rm-calculator.php';


  // ── Token storage key ────────────────────────────────────────────────────────
  static const String tokenKey = 'gf_member_token';

  // ── Days of week (Spanish) ───────────────────────────────────────────────────
  static const List<String> weekDays = [
    'Domingo', 'Lunes', 'Martes', 'Miércoles',
    'Jueves', 'Viernes', 'Sábado',
  ];

  static const List<String> weekDaysShort = [
    'Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb',
  ];
}

/// GymFlow Default Design System colors
class GFColors {
  static const accent = Color(0xFF00F5D4);
  static const accent2 = Color(0xFFFF6B35);
  static const bg = Color(0xFF080810);
  static const surface = Color(0xFF14141E);
  static const textPrimary = Color(0xFFF0F0F0);
  static const textMuted = Color(0xFF888888);
}
