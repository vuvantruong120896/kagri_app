import 'package:flutter/material.dart';

/// Service to monitor network connectivity
///
/// Usage:
/// ```dart
/// final connectivity = NetworkConnectivityService.instance;
///
/// // Listen to connectivity changes
/// connectivity.connectionStatus.listen((isOnline) {
///   print('Online: $isOnline');
/// });
///
/// // Check current status
/// if (connectivity.isOnline) {
///   print('Currently online');
/// }
/// ```
class NetworkConnectivityService extends ChangeNotifier {
  static final NetworkConnectivityService _instance =
      NetworkConnectivityService._internal();

  factory NetworkConnectivityService() => _instance;

  NetworkConnectivityService._internal();

  static NetworkConnectivityService get instance => _instance;

  // Connection status
  bool _isOnline = true;
  DateTime? _lastOnlineTime;
  DateTime? _lastOfflineTime;
  int _connectionLossCount = 0;

  bool get isOnline => _isOnline;
  DateTime? get lastOnlineTime => _lastOnlineTime;
  DateTime? get lastOfflineTime => _lastOfflineTime;
  int get connectionLossCount => _connectionLossCount;

  /// Get time since last online
  Duration? get timeSinceLastOnline {
    if (_lastOnlineTime == null) return null;
    return DateTime.now().difference(_lastOnlineTime!);
  }

  /// Get time since last offline
  Duration? get timeSinceLastOffline {
    if (_lastOfflineTime == null) return null;
    return DateTime.now().difference(_lastOfflineTime!);
  }

  /// Set connection status
  void setOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;

      if (online) {
        _lastOnlineTime = DateTime.now();
        debugPrint('✅ Connected to internet');
      } else {
        _lastOfflineTime = DateTime.now();
        _connectionLossCount++;
        debugPrint('❌ Lost internet connection (count: $_connectionLossCount)');
      }

      notifyListeners();
    }
  }

  /// Check if connection was lost recently
  bool wasConnectionLostRecently({
    Duration duration = const Duration(minutes: 5),
  }) {
    if (_lastOfflineTime == null) return false;
    return DateTime.now().difference(_lastOfflineTime!) <= duration;
  }

  /// Get connection statistics
  Map<String, dynamic> getStats() {
    return {
      'isOnline': _isOnline,
      'connectionLossCount': _connectionLossCount,
      'lastOnlineTime': _lastOnlineTime?.toIso8601String(),
      'lastOfflineTime': _lastOfflineTime?.toIso8601String(),
      'timeSinceLastOnline': timeSinceLastOnline?.inSeconds,
      'timeSinceLastOffline': timeSinceLastOffline?.inSeconds,
    };
  }

  /// Reset statistics
  void resetStats() {
    _connectionLossCount = 0;
    _lastOnlineTime = null;
    _lastOfflineTime = null;
    debugPrint('🔄 Connection stats reset');
    notifyListeners();
  }
}

/// Simple mock connectivity service for testing
class MockConnectivityService extends ChangeNotifier {
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  void setOnline(bool online) {
    _isOnline = online;
    notifyListeners();
  }

  Future<void> simulateConnectionLoss({
    Duration duration = const Duration(seconds: 3),
  }) async {
    setOnline(false);
    await Future.delayed(duration);
    setOnline(true);
  }
}

/// Connection status listener widget
class ConnectionStatusListener extends ChangeNotifier {
  final NetworkConnectivityService _connectivity =
      NetworkConnectivityService.instance;
  late ConnectionStatus _status;

  ConnectionStatus get status => _status;

  ConnectionStatusListener() {
    _status = _connectivity.isOnline
        ? ConnectionStatus.online
        : ConnectionStatus.offline;
    _connectivity.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    final newStatus = _connectivity.isOnline
        ? ConnectionStatus.online
        : ConnectionStatus.offline;
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}

enum ConnectionStatus { online, offline }

/// Connection status widget
class ConnectionStatusWidget extends StatelessWidget {
  final Widget Function(BuildContext, bool isOnline) builder;
  final Widget? offlineWidget;

  const ConnectionStatusWidget({
    super.key,
    required this.builder,
    this.offlineWidget,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NetworkConnectivityService.instance,
      builder: (context, _) {
        final isOnline = NetworkConnectivityService.instance.isOnline;

        if (!isOnline && offlineWidget != null) {
          return offlineWidget!;
        }

        return builder(context, isOnline);
      },
    );
  }
}
