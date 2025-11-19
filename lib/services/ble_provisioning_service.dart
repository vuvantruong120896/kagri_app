import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_constants.dart';
import '../services/auth_service.dart';
import '../services/provisioning_storage.dart';

/// BLE Provisioning Service v2.0
///
/// Complete rewrite to support both Gateway and Node provisioning
/// with proper UUID handling and response parsing.
///
/// Features:
/// - Gateway WiFi mode provisioning
/// - Gateway Cellular mode provisioning
/// - Node provisioning with Gateway MAC
/// - Multi-gateway support
/// - Proper error handling and timeouts
///
/// Updated: November 2025
/// Architecture: docs/PROVISIONING_BLE_ARCHITECTURE.md

class BleProvisioningService {
  final ProvisioningStorage storage = ProvisioningStorage();

  // ============================================================================
  // BLUETOOTH AVAILABILITY CHECK
  // ============================================================================

  /// Check if Bluetooth is available and turned on
  Future<bool> isBluetoothReady() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        print('[BLE] Bluetooth not supported on this device');
        return false;
      }

      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        print('[BLE] Bluetooth is not turned on: $state');
        return false;
      }

      return true;
    } catch (e) {
      print('[BLE] Error checking Bluetooth state: $e');
      return false;
    }
  }

  // ============================================================================
  // DEVICE SCANNING
  // ============================================================================

  /// Scan for Kagri devices (Gateway and Node)
  /// Returns a stream of scan results
  Stream<List<ScanResult>> scanDevices({
    required Duration timeout,
    DeviceType? filterType,
  }) async* {
    await FlutterBluePlus.stopScan();

    print(
      '[BLE] Starting scan for ${filterType?.displayName ?? 'all'} devices...',
    );

    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );

    await for (final results in FlutterBluePlus.scanResults) {
      // Filter Kagri devices only
      final kagriDevices = results.where((result) {
        final name = result.device.platformName;
        if (name.isEmpty) return false;

        final isKagriDevice =
            BleConstants.isGatewayDevice(name) ||
            BleConstants.isNodeDevice(name);

        if (!isKagriDevice) return false;

        // Apply type filter if specified
        if (filterType != null) {
          final deviceType = BleConstants.getDeviceType(name);
          return deviceType == filterType;
        }

        return true;
      }).toList();

      yield kagriDevices;
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    print('[BLE] Scan stopped');
  }

  // ============================================================================
  // CONNECTION MANAGEMENT
  // ============================================================================

  /// Connect to a device with retry logic
  Future<BluetoothDevice> connect(
    BluetoothDevice device, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        print(
          '[BLE] Connection attempt ${attempt + 1}/$maxRetries to ${device.platformName}...',
        );

        // Ensure device is disconnected first
        try {
          await device.disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (_) {}

        await device.connect(
          autoConnect: false,
          timeout: Duration(seconds: BleConstants.connectionTimeoutSeconds),
        );

        print('[BLE] ✓ Connected to ${device.platformName}');
        return device;
      } catch (e) {
        attempt++;
        print('[BLE] ✗ Connection attempt $attempt failed: $e');

        if (attempt >= maxRetries) {
          throw Exception(
            'Kết nối BLE thất bại sau $maxRetries lần thử. '
            'Vui lòng thử lại hoặc khởi động lại Bluetooth.',
          );
        }

        // Wait before retry (longer for each attempt)
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    throw Exception('Không thể kết nối BLE');
  }

  /// Disconnect from device
  Future<void> disconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
      print('[BLE] Disconnected from ${device.platformName}');
    } catch (e) {
      print('[BLE] Error disconnecting: $e');
    }
  }

  // ============================================================================
  // GATEWAY PROVISIONING - WIFI MODE
  // ============================================================================

  /// Provision Gateway in WiFi mode
  ///
  /// Sends:
  /// ```json
  /// {
  ///   "userUID": "user-xxx",
  ///   "isWiFi": true,
  ///   "wifiSSID": "NetworkName",
  ///   "wifiPassword": "password123",
  ///   "timestamp": 1700000000
  /// }
  /// ```
  ///
  /// Returns Gateway MAC on success
  Future<String> provisionGatewayWiFi({
    required BluetoothDevice device,
    required String ssid,
    required String password,
    Function(String)? onProgress,
  }) async {
    final uid = AuthService().currentUserUID;
    if (uid == null) throw Exception('User not logged in');

    onProgress?.call('Kết nối với Gateway...');

    // Discover services
    onProgress?.call('Tìm kiếm BLE services...');
    final services = await device.discoverServices();

    final service = _findService(
      services,
      BleConstants.gatewayServiceUuid,
      'Gateway',
    );

    final commandChar = _findCharacteristic(
      service,
      BleConstants.gatewayCommandCharUuid,
      'Gateway Command',
    );

    final responseChar = _findCharacteristic(
      service,
      BleConstants.gatewayResponseCharUuid,
      'Gateway Response',
    );

    // Subscribe to notifications
    onProgress?.call('Chuẩn bị nhận phản hồi...');
    await responseChar.setNotifyValue(true);

    // Stabilization delay
    await Future.delayed(
      Duration(milliseconds: BleConstants.connectionStabilizationDelayMs),
    );

    // Prepare payload
    final payload = {
      BleConstants.keyUserUID: uid,
      BleConstants.keyIsWiFi: true,
      BleConstants.keyWiFiSSID: ssid,
      BleConstants.keyWiFiPassword: password,
      BleConstants.keyTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    onProgress?.call('Gửi thông tin WiFi...');

    return await _sendProvisioningDataAndWaitResponse(
      device: device,
      commandChar: commandChar,
      responseChar: responseChar,
      payload: payload,
      deviceType: 'Gateway WiFi',
      onProgress: onProgress,
    );
  }

  // ============================================================================
  // GATEWAY PROVISIONING - CELLULAR MODE
  // ============================================================================

  /// Provision Gateway in Cellular mode
  ///
  /// Sends:
  /// ```json
  /// {
  ///   "userUID": "user-xxx",
  ///   "isWiFi": false,
  ///   "timestamp": 1700000000
  /// }
  /// ```
  ///
  /// Returns Gateway MAC on success
  Future<String> provisionGatewayCellular({
    required BluetoothDevice device,
    Function(String)? onProgress,
  }) async {
    final uid = AuthService().currentUserUID;
    if (uid == null) throw Exception('User not logged in');

    onProgress?.call('Kết nối với Gateway...');

    // Discover services
    onProgress?.call('Tìm kiếm BLE services...');
    final services = await device.discoverServices();

    final service = _findService(
      services,
      BleConstants.gatewayServiceUuid,
      'Gateway',
    );

    final commandChar = _findCharacteristic(
      service,
      BleConstants.gatewayCommandCharUuid,
      'Gateway Command',
    );

    final responseChar = _findCharacteristic(
      service,
      BleConstants.gatewayResponseCharUuid,
      'Gateway Response',
    );

    // Subscribe to notifications
    onProgress?.call('Chuẩn bị nhận phản hồi...');
    await responseChar.setNotifyValue(true);

    await Future.delayed(
      Duration(milliseconds: BleConstants.connectionStabilizationDelayMs),
    );

    // Prepare payload (NO WiFi credentials)
    final payload = {
      BleConstants.keyUserUID: uid,
      BleConstants.keyIsWiFi: false,
      BleConstants.keyTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    onProgress?.call('Gửi thông tin Cellular...');

    return await _sendProvisioningDataAndWaitResponse(
      device: device,
      commandChar: commandChar,
      responseChar: responseChar,
      payload: payload,
      deviceType: 'Gateway Cellular',
      onProgress: onProgress,
    );
  }

  // ============================================================================
  // NODE PROVISIONING
  // ============================================================================

  /// Provision Node with Gateway MAC
  ///
  /// Sends:
  /// ```json
  /// {
  ///   "userUID": "user-xxx",
  ///   "gatewayMAC": "AA:BB:CC:DD:EE:FF",
  ///   "timestamp": 1700000000
  /// }
  /// ```
  ///
  /// Returns Node address on success
  Future<int> provisionNode({
    required BluetoothDevice device,
    required String gatewayMAC,
    Function(String)? onProgress,
  }) async {
    final uid = AuthService().currentUserUID;
    if (uid == null) throw Exception('User not logged in');

    // Validate Gateway MAC format
    if (!BleConstants.isValidMacAddress(gatewayMAC)) {
      throw Exception(
        'Gateway MAC không đúng định dạng. '
        'Sử dụng: AA:BB:CC:DD:EE:FF',
      );
    }

    onProgress?.call('Kết nối với Node...');

    // Discover services
    onProgress?.call('Tìm kiếm BLE services...');
    final services = await device.discoverServices();

    final service = _findService(
      services,
      BleConstants.nodeServiceUuid,
      'Node',
    );

    final commandChar = _findCharacteristic(
      service,
      BleConstants.nodeCommandCharUuid,
      'Node Command',
    );

    final responseChar = _findCharacteristic(
      service,
      BleConstants.nodeResponseCharUuid,
      'Node Response',
    );

    // Subscribe to notifications
    onProgress?.call('Chuẩn bị nhận phản hồi...');
    await responseChar.setNotifyValue(true);

    await Future.delayed(
      Duration(milliseconds: BleConstants.connectionStabilizationDelayMs),
    );

    // Prepare payload
    final payload = {
      BleConstants.keyUserUID: uid,
      BleConstants.keyGatewayMAC: gatewayMAC,
      BleConstants.keyTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    onProgress?.call('Gửi thông tin Node...');

    final responseData = await _sendProvisioningDataAndWaitResponse(
      device: device,
      commandChar: commandChar,
      responseChar: responseChar,
      payload: payload,
      deviceType: 'Node',
      onProgress: onProgress,
      parseNodeAddress: true,
    );

    // Parse node address from response
    return int.tryParse(responseData) ?? 0;
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Find service by UUID
  BluetoothService _findService(
    List<BluetoothService> services,
    String targetUuid,
    String serviceName,
  ) {
    print('[BLE] Searching for $serviceName service...');
    print('[BLE] Found ${services.length} services');

    for (var s in services) {
      print('[BLE]   - Service: ${s.uuid}');
    }

    final service = services.firstWhere(
      (s) => _matchUuid(s.uuid.toString(), targetUuid),
      orElse: () => throw Exception('$serviceName service không tìm thấy'),
    );

    print('[BLE] ✓ Found $serviceName service: ${service.uuid}');
    return service;
  }

  /// Find characteristic by UUID
  BluetoothCharacteristic _findCharacteristic(
    BluetoothService service,
    String targetUuid,
    String charName,
  ) {
    print('[BLE] Searching for $charName characteristic...');

    for (var c in service.characteristics) {
      print('[BLE]   - Char: ${c.uuid}, properties: ${c.properties}');
    }

    final char = service.characteristics.firstWhere(
      (c) => _matchUuid(c.uuid.toString(), targetUuid),
      orElse: () => throw Exception('$charName characteristic không tìm thấy'),
    );

    print('[BLE] ✓ Found $charName: ${char.uuid}');
    return char;
  }

  /// Match UUID (handles both short and long format)
  bool _matchUuid(String uuid1, String uuid2) {
    final u1 = uuid1.toLowerCase().replaceAll('-', '');
    final u2 = uuid2.toLowerCase().replaceAll('-', '');
    return u1 == u2 || u1.contains(u2) || u2.contains(u1);
  }

  /// Send provisioning data and wait for response
  Future<String> _sendProvisioningDataAndWaitResponse({
    required BluetoothDevice device,
    required BluetoothCharacteristic commandChar,
    required BluetoothCharacteristic responseChar,
    required Map<String, dynamic> payload,
    required String deviceType,
    Function(String)? onProgress,
    bool parseNodeAddress = false,
  }) async {
    // Encode payload
    final jsonString = jsonEncode(payload);
    print('[BLE] Sending $deviceType payload: $jsonString');
    final data = utf8.encode(jsonString);

    // Listen for response
    final completer = Completer<String>();
    late StreamSubscription subscription;

    subscription = responseChar.lastValueStream.listen((value) {
      if (value.isNotEmpty && !completer.isCompleted) {
        print('[BLE] Raw response: ${value.length} bytes');
        try {
          final responseStr = utf8.decode(value);
          print('[BLE] Response decoded: $responseStr');

          final response = jsonDecode(responseStr) as Map<String, dynamic>;
          print('[BLE] Response parsed: $response');

          final status = response[BleConstants.keyStatus];

          if (status == BleConstants.statusSuccess) {
            print('[BLE] ✓ $deviceType provisioning successful');

            // Extract Gateway MAC or Node address
            if (parseNodeAddress) {
              final nodeAddr = response[BleConstants.keyNodeAddress];
              completer.complete(nodeAddr.toString());
            } else {
              final gatewayMAC = response[BleConstants.keyResponseGatewayMAC];
              if (gatewayMAC != null) {
                // Save Gateway MAC for future Node provisioning
                storage.saveGatewayMAC(gatewayMAC);
                completer.complete(gatewayMAC);
              } else {
                completer.completeError(
                  Exception('Response thiếu Gateway MAC'),
                );
              }
            }
          } else {
            final message =
                response[BleConstants.keyMessage] ?? 'Unknown error';
            print('[BLE] ✗ $deviceType provisioning failed: $message');
            completer.completeError(Exception(message));
          }
        } catch (e) {
          print('[BLE] ✗ Failed to parse response: $e');
          completer.completeError(
            Exception('Không thể phân tích phản hồi từ thiết bị'),
          );
        }
      }
    });

    // Write data
    onProgress?.call('Đang gửi dữ liệu...');
    await commandChar.write(data, withoutResponse: true);
    print('[BLE] Data written to $deviceType');

    // Wait for response with timeout
    onProgress?.call('Chờ phản hồi từ thiết bị...');

    try {
      final result = await completer.future.timeout(
        Duration(seconds: BleConstants.responseTimeoutSeconds),
        onTimeout: () {
          throw Exception(
            'Timeout: Không nhận được phản hồi từ thiết bị sau '
            '${BleConstants.responseTimeoutSeconds}s',
          );
        },
      );

      await subscription.cancel();
      return result;
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }
  }
}
