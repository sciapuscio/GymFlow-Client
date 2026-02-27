import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

/// Monitors internet connectivity and notifies listeners.
/// Uses a periodic ping to the API server to detect real connectivity.
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _timer;

  /// Start polling every 5 seconds
  void startMonitoring() {
    _timer?.cancel();
    _checkNow();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkNow());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkNow() async {
    bool online;
    try {
      final result = await InternetAddress.lookup(
        Uri.parse(AppConstants.baseUrl).host,
      ).timeout(const Duration(seconds: 4));
      online = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      online = false;
    } on TimeoutException {
      online = false;
    } catch (_) {
      online = false;
    }

    if (online != _isOnline) {
      _isOnline = online;
      notifyListeners();
    }
  }

  /// Force an immediate recheck (call after manual retry)
  Future<void> recheck() => _checkNow();
}
