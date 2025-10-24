import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE Offline Data Sync Service (Phase 2B)
/// Handles syncing sensor data from gateway via BLE
///
/// Features:
/// - Long-press menu trigger (3 second hold)
/// - BLE sync with pagination (max 10 items/packet)
/// - Retry logic (max 2 attempts)
/// - Progress tracking
class BleSyncService {
  // BLE Sync Service UUIDs (Phase 2A Gateway)
  static const String syncServiceUuid = "660e8400-0000-1000-8000-00805f9b34fb";
  static const String dataReadCharUuid = "660e8401-0000-1000-8000-00805f9b34fb";
  static const String commandCharUuid = "660e8402-0000-1000-8000-00805f9b34fb";

  // Sync Protocol Constants
  static const int MAX_ITEMS_PER_PACKET = 10;
  static const int MAX_RETRIES = 2;
  static const Duration COMMAND_TIMEOUT = Duration(seconds: 10);

  // Command IDs (must match Phase 1 ble_sync_protocol.h)
  static const int CMD_GET_BUFFERED_DATA = 1;
  static const int CMD_CLEAR_BUFFER = 2;
  static const int CMD_PING = 3;

  // Response codes
  static const int RESP_OK = 0;
  static const int RESP_ERROR = 1;
  static const int RESP_DENIED = 2;

  late BluetoothDevice _device;
  BluetoothCharacteristic? _dataReadChar;
  BluetoothCharacteristic? _commandChar;

  int _totalItemsReceived = 0;
  int _currentOffset = 0;
  bool _isInitialized = false;

  /// Initialize BLE sync with connected device
  Future<bool> initialize(BluetoothDevice device) async {
    try {
      _device = device;

      // Discover services
      final services = await _device.discoverServices();
      print('[BleSyncService] Discovered ${services.length} services');

      for (final service in services) {
        print('[BleSyncService] Service: ${service.uuid}');

        if (service.uuid.toString().toLowerCase() ==
            syncServiceUuid.toLowerCase()) {
          print('[BleSyncService] ✅ Found BLE Sync Service!');

          // Find characteristics
          for (final char in service.characteristics) {
            print('[BleSyncService] Characteristic: ${char.uuid}');

            if (char.uuid.toString().toLowerCase() ==
                dataReadCharUuid.toLowerCase()) {
              _dataReadChar = char;
              print('[BleSyncService] ✅ Found DATA_READ characteristic');
            } else if (char.uuid.toString().toLowerCase() ==
                commandCharUuid.toLowerCase()) {
              _commandChar = char;
              print('[BleSyncService] ✅ Found COMMAND characteristic');
            }
          }
          break;
        }
      }

      if (_dataReadChar == null || _commandChar == null) {
        print('[BleSyncService] ❌ Missing required characteristics');
        return false;
      }

      _isInitialized = true;
      print('[BleSyncService] ✅ Initialization complete');
      return true;
    } catch (e) {
      print('[BleSyncService] ❌ Initialization failed: $e');
      return false;
    }
  }

  /// Send PING command to check gateway status
  /// Returns number of buffered items
  Future<int?> ping({int retries = 0}) async {
    if (!_isInitialized || _commandChar == null || _dataReadChar == null) {
      print('[BleSyncService] ❌ Not initialized');
      return null;
    }

    try {
      print(
        '[BleSyncService] 🔍 Sending PING command (attempt ${retries + 1}/$MAX_RETRIES)',
      );

      // Build PING command packet (minimal: just command ID)
      final commandPacket = ByteData(8);
      commandPacket.setUint8(0, CMD_PING);
      commandPacket.setUint8(1, 0); // sequence
      commandPacket.setUint16(2, 0, Endian.little); // payload size
      commandPacket.setUint16(4, 0, Endian.little); // reserved
      // CRC32 placeholder at bytes 6-7 (would need proper CRC in production)

      // Send command
      await _commandChar!.write(
        commandPacket.buffer.asUint8List(),
        withoutResponse: false,
      );

      // Read response (with timeout)
      final response = await _dataReadChar!.read().timeout(
        COMMAND_TIMEOUT,
        onTimeout: () {
          throw Exception('PING command timeout');
        },
      );

      // Parse response header (first 8 bytes)
      if (response.length < 8) {
        print('[BleSyncService] ❌ Invalid response length: ${response.length}');
        return null;
      }

      final responseData = ByteData.view(Uint8List.fromList(response).buffer);
      final responseCode = responseData.getUint8(0);
      final totalCount = responseData.getUint16(4, Endian.little);

      if (responseCode != RESP_OK) {
        print('[BleSyncService] ❌ PING failed: response code $responseCode');
        return null;
      }

      print('[BleSyncService] ✅ PING successful: $totalCount items buffered');
      return totalCount;
    } catch (e) {
      print('[BleSyncService] ⚠️ PING failed: $e');

      if (retries < MAX_RETRIES) {
        print('[BleSyncService] 🔄 Retrying PING...');
        await Future.delayed(const Duration(milliseconds: 500));
        return ping(retries: retries + 1);
      }
      return null;
    }
  }

  /// Fetch buffered sensor data from gateway with pagination
  /// Yields data as it arrives, handles retries
  Stream<List<Map<String, dynamic>>> fetchBufferedData({
    required int totalItems,
    Function(int current, int total)? onProgress,
  }) async* {
    if (!_isInitialized || _commandChar == null || _dataReadChar == null) {
      print('[BleSyncService] ❌ Not initialized');
      yield [];
      return;
    }

    final allData = <Map<String, dynamic>>[];
    _currentOffset = 0;

    // Fetch pages with pagination
    while (_currentOffset < totalItems) {
      try {
        final itemsToFetch = (totalItems - _currentOffset).clamp(
          0,
          MAX_ITEMS_PER_PACKET,
        );

        print(
          '[BleSyncService] 📥 Fetching items $_currentOffset-${_currentOffset + itemsToFetch}/$totalItems',
        );
        onProgress?.call(_currentOffset, totalItems);

        // Build GET_BUFFERED_DATA command
        final commandPacket = ByteData(8);
        commandPacket.setUint8(0, CMD_GET_BUFFERED_DATA);
        commandPacket.setUint8(1, 0); // sequence
        commandPacket.setUint16(
          2,
          1,
          Endian.little,
        ); // payload size (offset = 1 byte)
        commandPacket.setUint8(7, _currentOffset); // offset in payload

        // Send command
        await _commandChar!.write(
          commandPacket.buffer.asUint8List(),
          withoutResponse: false,
        );

        // Read response
        final response = await _dataReadChar!.read().timeout(
          COMMAND_TIMEOUT,
          onTimeout: () {
            throw Exception('GET_BUFFERED_DATA timeout');
          },
        );

        if (response.length < 8) {
          throw Exception('Invalid response length: ${response.length}');
        }

        final responseData = ByteData.view(Uint8List.fromList(response).buffer);
        final responseCode = responseData.getUint8(0);
        final payloadSize = responseData.getUint16(2, Endian.little);

        if (responseCode != RESP_OK) {
          throw Exception('Response code $responseCode');
        }

        // Parse sensor data items from payload (18 bytes each)
        int itemCount = 0;
        for (int i = 0; i < payloadSize; i += 18) {
          if (i + 18 > payloadSize) break; // Incomplete item

          final itemData = response.sublist(8 + i, 8 + i + 18);
          final item = _parseSensorItem(itemData);
          allData.add(item);
          itemCount++;
        }

        print('[BleSyncService] ✅ Received $itemCount items');
        _currentOffset += itemCount;
        _totalItemsReceived += itemCount;

        yield List.from(allData);

        if (itemCount < MAX_ITEMS_PER_PACKET) {
          break; // No more items
        }
      } catch (e) {
        print('[BleSyncService] ❌ Fetch failed: $e');
        print(
          '[BleSyncService] ⚠️ Partial data received: ${allData.length} items',
        );
        yield List.from(allData);
        break;
      }
    }

    onProgress?.call(totalItems, totalItems);
    print('[BleSyncService] ✅ Sync complete: $_totalItemsReceived items');
  }

  /// Clear buffered data after successful sync
  Future<bool> clearBuffer({int ackCount = 0, int retries = 0}) async {
    if (!_isInitialized || _commandChar == null || _dataReadChar == null) {
      print('[BleSyncService] ❌ Not initialized');
      return false;
    }

    try {
      print(
        '[BleSyncService] 🗑️ Clearing buffer ($ackCount items, attempt ${retries + 1}/$MAX_RETRIES)',
      );

      // Build CLEAR_BUFFER command
      final commandPacket = ByteData(8);
      commandPacket.setUint8(0, CMD_CLEAR_BUFFER);
      commandPacket.setUint8(1, 0); // sequence
      commandPacket.setUint16(
        2,
        2,
        Endian.little,
      ); // payload size (ackCount = 2 bytes)
      commandPacket.setUint16(
        6,
        ackCount,
        Endian.little,
      ); // ackCount in payload

      // Send command
      await _commandChar!.write(
        commandPacket.buffer.asUint8List(),
        withoutResponse: false,
      );

      // Read response
      final response = await _dataReadChar!.read().timeout(
        COMMAND_TIMEOUT,
        onTimeout: () {
          throw Exception('CLEAR_BUFFER timeout');
        },
      );

      if (response.length < 1) {
        throw Exception('Invalid response');
      }

      final responseCode = response[0];
      if (responseCode != RESP_OK) {
        throw Exception('Response code $responseCode');
      }

      print('[BleSyncService] ✅ Buffer cleared');
      return true;
    } catch (e) {
      print('[BleSyncService] ⚠️ Clear failed: $e');

      if (retries < MAX_RETRIES) {
        await Future.delayed(const Duration(milliseconds: 500));
        return clearBuffer(ackCount: ackCount, retries: retries + 1);
      }
      return false;
    }
  }

  /// Parse sensor data item from 18-byte buffer
  Map<String, dynamic> _parseSensorItem(List<int> data) {
    if (data.length < 18) {
      return {
        'timestamp': 0,
        'nodeId': 0,
        'sensorType': 0,
        'temperature': 0.0,
        'humidity': 0.0,
        'moisture': 0.0,
        'light': 0,
        'battery': 0,
        'rssi': 0,
      };
    }

    final buffer = ByteData.view(Uint8List.fromList(data).buffer);

    return {
      'timestamp': buffer.getUint32(0, Endian.little),
      'nodeId': buffer.getUint16(4, Endian.little),
      'sensorType': buffer.getUint8(6),
      'temperature': buffer.getUint16(7, Endian.little) / 100.0,
      'humidity': buffer.getUint16(9, Endian.little) / 100.0,
      'moisture': buffer.getUint16(11, Endian.little) / 100.0,
      'light': buffer.getUint16(13, Endian.little),
      'battery': buffer.getUint8(15),
      'rssi': buffer.getInt8(16),
      'reserved': buffer.getUint8(17),
    };
  }

  /// Get sync statistics
  Map<String, int> getStats() {
    return {
      'totalReceived': _totalItemsReceived,
      'currentOffset': _currentOffset,
    };
  }

  /// Reset statistics
  void resetStats() {
    _totalItemsReceived = 0;
    _currentOffset = 0;
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
}
