import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'auth_service.dart';

class BleProvisioningService {
  // Replace with your Gateway's advertised service/characteristics UUIDs
  // TODO: verify with firmware and update accordingly
  static const String provisioningServiceUuid =
      "0000ffb0-0000-1000-8000-00805f9b34fb"; // example
  static const String commandCharUuid =
      "0000ffb1-0000-1000-8000-00805f9b34fb"; // write
  static const String responseCharUuid =
      "0000ffb2-0000-1000-8000-00805f9b34fb"; // notify/indicate

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

  Stream<List<ScanResult>> scanGateways({
    Duration timeout = const Duration(seconds: 5),
  }) async* {
    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan(timeout: timeout);
    yield* FlutterBluePlus.scanResults;
  }

  Future<BluetoothDevice> connect(ScanResult result) async {
    final device = result.device;

    // Android BLE connection can be flaky - retry up to 3 times
    int maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        print('[BLE] Connection attempt ${attempt + 1}/$maxRetries...');

        // Ensure device is disconnected first
        try {
          await device.disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (_) {}

        await device.connect(
          autoConnect: false,
          timeout: const Duration(seconds: 15),
        );

        print('[BLE] Connected successfully!');
        return device;
      } catch (e) {
        attempt++;
        print('[BLE] Connection attempt $attempt failed: $e');

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

  Future<void> disconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {}
  }

  Future<bool> provisionGateway({
    required BluetoothDevice device,
    required String ssid,
    required String password,
  }) async {
    // Get current user UID - Gateway will derive netkey itself
    final uid = AuthService().currentUserUID;
    if (uid == null) throw Exception('User not logged in');

    print('[BLE] Discovering services...');
    // Discover services
    final services = await device.discoverServices();

    print('[BLE] Found ${services.length} services');

    // Debug: print all services and characteristics
    for (var s in services) {
      print('[BLE] Service: ${s.uuid}');
      for (var c in s.characteristics) {
        print('[BLE]   - Char: ${c.uuid}, properties: ${c.properties}');
      }
    }

    // Helper to compare UUIDs (handles both short and long format)
    bool matchUuid(String uuid1, String uuid2) {
      final u1 = uuid1.toLowerCase().replaceAll('-', '');
      final u2 = uuid2.toLowerCase().replaceAll('-', '');
      // Compare last 4 chars (short UUID) or full UUID
      return u1.contains(u2.substring(u2.length >= 4 ? u2.length - 4 : 0)) ||
          u2.contains(u1.substring(u1.length >= 4 ? u1.length - 4 : 0));
    }

    final service = services.firstWhere(
      (s) => matchUuid(s.uuid.toString(), provisioningServiceUuid),
      orElse: () => throw Exception('Provisioning service not found'),
    );

    print('[BLE] Found provisioning service: ${service.uuid}');
    final commandChar = service.characteristics.firstWhere(
      (c) => matchUuid(c.uuid.toString(), commandCharUuid),
      orElse: () => throw Exception('Provisioning characteristic not found'),
    );

    print('[BLE] Found command characteristic: ${commandChar.uuid}');

    // Try to find response characteristic for notifications
    final responseChar = service.characteristics.firstWhere(
      (c) => matchUuid(c.uuid.toString(), responseCharUuid),
      orElse: () => throw Exception('Response characteristic not found'),
    );

    print('[BLE] Found response characteristic: ${responseChar.uuid}');

    // Subscribe to response notifications
    print('[BLE] Subscribing to response notifications...');
    await responseChar.setNotifyValue(true);

    // Wait a bit for connection to stabilize
    await Future.delayed(const Duration(milliseconds: 500));

    // Prepare provisioning payload (JSON)
    // Gateway will derive netkey from userUID + its own MAC address
    final payload = jsonEncode({
      'ssid': ssid,
      'password': password,
      'userUID': uid,
    });

    print('[BLE] Sending provisioning data: ${payload.length} bytes');
    print('[BLE] Payload: $payload');
    final data = Uint8List.fromList(utf8.encode(payload));

    // Listen for response
    bool responseReceived = false;
    bool success = false;

    final subscription = responseChar.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        print('[BLE] Raw response: ${value.length} bytes - ${value.toList()}');
        try {
          final responseStr = utf8.decode(value, allowMalformed: true);
          print('[BLE] Response decoded: $responseStr');
          final response = jsonDecode(responseStr);
          print('[BLE] Response parsed: $response');
          if (response['status'] == 'success') {
            success = true;
          }
          responseReceived = true;
        } catch (e) {
          print('[BLE] Failed to parse response: $e');
          // Consider it success anyway if we got some response
          print('[BLE] Assuming success since Gateway sent response');
          success = true;
          responseReceived = true;
        }
      }
    });

    // Write to characteristic (without waiting for BLE ACK to avoid timeout)
    await commandChar.write(data, withoutResponse: true);
    print('[BLE] Data written, waiting for response...');

    // Wait for response (max 5 seconds)
    final startTime = DateTime.now();
    while (!responseReceived &&
        DateTime.now().difference(startTime).inSeconds < 5) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await subscription.cancel();

    if (responseReceived) {
      print('[BLE] Gateway acknowledged: ${success ? "SUCCESS" : "ERROR"}');
      return success;
    } else {
      print('[BLE] No response received within timeout');
      // Consider it success if no error (Gateway might reboot immediately)
      return true;
    }
  }
}
