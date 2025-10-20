import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';
import '../models/device.dart';
import 'data_service.dart';

/// Extension on DataService to add retry logic and error handling
extension DataServiceExtension on DataService {
  /// Get sensor data with retry logic
  ///
  /// Automatically retries up to [maxRetries] times with exponential backoff
  Future<List<SensorData>> getSensorDataWithRetry({
    required String nodeId,
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final data = await getLatestSensorData(nodeId);
        if (data != null) {
          return [data];
        }
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          debugPrint(
            '❌ Failed to fetch sensor data after $maxRetries retries: $e',
          );
          rethrow;
        }

        // Exponential backoff
        final delay = initialDelay * (2 ^ (retryCount - 1));
        debugPrint('⚠️ Retry #$retryCount after ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      }
    }

    return [];
  }

  /// Get devices with retry logic
  Future<List<Device>> getDevicesWithRetry({
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final stream = getDevicesStream();
        return await stream.first.timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Failed to fetch devices'),
        );
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          debugPrint('❌ Failed to fetch devices after $maxRetries retries: $e');
          rethrow;
        }

        // Exponential backoff
        final delay = initialDelay * (2 ^ (retryCount - 1));
        debugPrint('⚠️ Retry #$retryCount after ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      }
    }

    return [];
  }

  /// Get stream of devices with error handling
  Stream<List<Device>> getDevicesStreamWithErrorHandling() {
    return getDevicesStream().handleError((error, stackTrace) {
      debugPrint('❌ Error in device stream: $error');
      debugPrint('Stack trace: $stackTrace');
      return <Device>[];
    });
  }

  /// Get stream of sensor data with error handling
  Stream<List<SensorData>> getSensorDataStreamWithErrorHandling({
    String? nodeId,
  }) {
    return getSensorDataStream(nodeId: nodeId).handleError((error, stackTrace) {
      debugPrint('❌ Error in sensor data stream: $error');
      debugPrint('Stack trace: $stackTrace');
      return <SensorData>[];
    });
  }
}

/// Timeout exception
class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => message;
}

/// Cache wrapper for data service
class CachedDataService {
  final DataService _dataService = DataService();

  // Simple in-memory cache
  final Map<String, CacheEntry> _cache = {};
  final Duration _cacheDuration;

  CachedDataService({Duration cacheDuration = const Duration(minutes: 5)})
    : _cacheDuration = cacheDuration;

  /// Get cached devices or fetch from service
  Future<List<Device>> getDevicesCached() async {
    const cacheKey = 'devices';

    // Check cache
    if (_cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (DateTime.now().difference(entry.timestamp).inMilliseconds <
          _cacheDuration.inMilliseconds) {
        debugPrint('📦 Using cached devices');
        return entry.data as List<Device>;
      }
    }

    // Fetch fresh data
    try {
      final devices = await _dataService.getDevicesStream().first.timeout(
        const Duration(seconds: 10),
      );

      // Update cache
      _cache[cacheKey] = CacheEntry(data: devices, timestamp: DateTime.now());

      return devices;
    } catch (e) {
      debugPrint('❌ Failed to fetch devices: $e');

      // Return cached data if available (even if expired)
      if (_cache.containsKey(cacheKey)) {
        debugPrint('📦 Using stale cached devices');
        return _cache[cacheKey]!.data as List<Device>;
      }

      rethrow;
    }
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    debugPrint('🗑️ Cache cleared');
  }

  /// Get cache stats
  Map<String, dynamic> getCacheStats() {
    return {
      'itemCount': _cache.length,
      'entries': _cache.entries
          .map(
            (e) => {
              'key': e.key,
              'age': DateTime.now().difference(e.value.timestamp).inSeconds,
            },
          )
          .toList(),
    };
  }
}

/// Cache entry
class CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  CacheEntry({required this.data, required this.timestamp});
}

/// Network connectivity aware data service
class NetworkAwareDataService {
  final DataService _dataService = DataService();
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  /// Set network status
  void setNetworkStatus(bool isOnline) {
    _isOnline = isOnline;
    if (isOnline) {
      debugPrint('✅ Network is online');
    } else {
      debugPrint('❌ Network is offline');
    }
  }

  /// Get devices with network awareness
  Future<List<Device>> getDevices() async {
    if (!_isOnline) {
      throw NetworkException('Device is offline');
    }

    try {
      return await _dataService.getDevicesStream().first.timeout(
        const Duration(seconds: 10),
      );
    } on TimeoutException catch (e) {
      throw NetworkException('Request timeout: ${e.message}');
    } catch (e) {
      throw NetworkException('Network error: $e');
    }
  }

  /// Get sensor data with network awareness
  Future<List<SensorData>> getSensorData(String nodeId) async {
    if (!_isOnline) {
      throw NetworkException('Device is offline');
    }

    try {
      final data = await _dataService.getLatestSensorData(nodeId);
      return data != null ? [data] : [];
    } on TimeoutException catch (e) {
      throw NetworkException('Request timeout: ${e.message}');
    } catch (e) {
      throw NetworkException('Network error: $e');
    }
  }
}

/// Network exception
class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => message;
}
