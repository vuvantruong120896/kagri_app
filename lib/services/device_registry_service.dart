import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/registered_device.dart';

/// Service for managing user's registered devices in Firebase
/// Stores devices under: users/{uid}/devices/
///
/// This is separate from routing_table which is managed by the Gateway.
/// Devices registered here are persistent and don't disappear when offline.
class DeviceRegistryService {
  static final DeviceRegistryService _instance =
      DeviceRegistryService._internal();
  factory DeviceRegistryService() => _instance;
  DeviceRegistryService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get reference to user's devices path
  DatabaseReference? _getUserDevicesRef() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _database.ref('users/${user.uid}/devices');
  }

  /// Register a new device after provisioning
  ///
  /// This should be called immediately after successful BLE provisioning
  /// to create a persistent record of the device.
  ///
  /// Parameters:
  /// - nodeId: The device's node ID (e.g., "0x1234")
  /// - deviceType: Type of device ("soil_sensor", "env_sensor", "gateway")
  /// - displayName: Optional custom name, defaults to "Device {nodeId}"
  /// - location: Optional location/area description
  /// - notes: Optional notes
  /// - firmwareVersion: Optional firmware version
  Future<void> registerDevice({
    required String nodeId,
    required String deviceType,
    String? displayName,
    String? location,
    String? notes,
    String? firmwareVersion,
  }) async {
    final ref = _getUserDevicesRef();
    if (ref == null) {
      throw Exception('User not authenticated');
    }

    // Create device key (e.g., "device_0x1234")
    final deviceKey = 'device_$nodeId';

    final device = RegisteredDevice(
      nodeId: nodeId,
      deviceType: deviceType,
      displayName: displayName ?? 'Device $nodeId',
      location: location,
      notes: notes,
      provisionedAt: DateTime.now(),
      firmwareVersion: firmwareVersion,
      provisionedBy: 'mobile_app_v1.0.0', // TODO: Get from package info
      isOnline: true, // Device is online when first provisioned
      lastSeen:
          DateTime.now(), // Set lastSeen to now so it doesn't appear offline
    );

    await ref.child(deviceKey).set(device.toFirebase());

    print('✅ Device registered: $nodeId as $deviceKey');
  }

  /// Get stream of all registered devices for current user
  ///
  /// Returns a real-time stream that updates whenever devices are added,
  /// removed, or their status changes.
  Stream<List<RegisteredDevice>> getDevicesStream() {
    final ref = _getUserDevicesRef();
    if (ref == null) {
      return Stream.value([]);
    }

    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <RegisteredDevice>[];

      final devicesMap = data as Map<dynamic, dynamic>;
      final devicesByNodeId = <String, RegisteredDevice>{}; // Merge by nodeId

      devicesMap.forEach((key, value) {
        if (value is Map) {
          try {
            final device = RegisteredDevice.fromFirebase(key, value);

            // If already exists, merge data (keep the one with more info)
            if (devicesByNodeId.containsKey(device.nodeId)) {
              final existing = devicesByNodeId[device.nodeId]!;

              // Keep the one that was provisioned first, or has better display name
              if (device.provisionedAt.isBefore(existing.provisionedAt) ||
                  (existing.displayName == 'Unknown Device' &&
                      device.displayName != 'Unknown Device')) {
                devicesByNodeId[device.nodeId] = device;
                print(
                  '✅ Merged device: ${device.nodeId} (kept newer/better data)',
                );
              } else {
                print('⚠️ Skipped duplicate: ${device.nodeId}');
              }
            } else {
              devicesByNodeId[device.nodeId] = device;
              print(
                '✅ Loaded device: ${device.nodeId} - ${device.displayName}',
              );
            }
          } catch (e) {
            print('Error parsing device $key: $e');
          }
        }
      });

      final devices = devicesByNodeId.values.toList();

      // Sort by provision date (newest first)
      devices.sort((a, b) => b.provisionedAt.compareTo(a.provisionedAt));

      return devices;
    });
  }

  /// Get a specific device by nodeId
  Stream<RegisteredDevice?> getDeviceStream(String nodeId) {
    final ref = _getUserDevicesRef();
    if (ref == null) {
      return Stream.value(null);
    }

    final deviceKey = 'device_$nodeId';
    return ref.child(deviceKey).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;

      try {
        return RegisteredDevice.fromFirebase(
          deviceKey,
          data as Map<dynamic, dynamic>,
        );
      } catch (e) {
        print('Error parsing device $nodeId: $e');
        return null;
      }
    });
  }

  /// Update device information
  ///
  /// Can update: displayName, location, notes, firmwareVersion
  /// Cannot update: nodeId, deviceType, provisionedAt
  Future<void> updateDevice(String nodeId, Map<String, dynamic> updates) async {
    final ref = _getUserDevicesRef();
    if (ref == null) {
      throw Exception('User not authenticated');
    }

    final deviceKey = 'device_$nodeId';

    // Filter out invalid fields
    final validUpdates = <String, dynamic>{};
    final allowedFields = [
      'displayName',
      'location',
      'notes',
      'firmwareVersion',
    ];

    updates.forEach((key, value) {
      if (allowedFields.contains(key)) {
        validUpdates[key] = value;
      }
    });

    if (validUpdates.isEmpty) return;

    await ref.child(deviceKey).update(validUpdates);
    print('✅ Device $nodeId updated: $validUpdates');
  }

  /// Update device online status from routing table
  ///
  /// This should be called periodically or when routing_table changes
  /// to sync the online/offline status.
  ///
  /// Parameters:
  /// - nodeId: Device node ID
  /// - isOnline: Current online status from routing_table
  /// - lastSeen: Last update timestamp from routing_table
  /// - rssi: Signal strength (optional)
  /// - hopCount: Hop count from gateway (optional)
  Future<void> updateDeviceStatus({
    required String nodeId,
    required bool isOnline,
    DateTime? lastSeen,
    int? rssi,
    int? hopCount,
  }) async {
    final ref = _getUserDevicesRef();
    if (ref == null) return;

    final deviceKey = 'device_$nodeId';

    final updates = <String, dynamic>{
      'isOnline': isOnline,
      if (lastSeen != null) 'lastSeen': lastSeen.millisecondsSinceEpoch,
      if (rssi != null) 'rssi': rssi,
      if (hopCount != null) 'hopCount': hopCount,
    };

    await ref.child(deviceKey).update(updates);
  }

  /// Batch update multiple device statuses
  ///
  /// More efficient than calling updateDeviceStatus() multiple times
  Future<void> batchUpdateDeviceStatuses(
    List<Map<String, dynamic>> updates,
  ) async {
    final ref = _getUserDevicesRef();
    if (ref == null) return;

    final batchUpdates = <String, dynamic>{};

    for (var update in updates) {
      final nodeId = update['nodeId'] as String;
      final deviceKey = 'device_$nodeId';

      if (update['isOnline'] != null) {
        batchUpdates['$deviceKey/isOnline'] = update['isOnline'];
      }
      if (update['lastSeen'] != null) {
        batchUpdates['$deviceKey/lastSeen'] =
            (update['lastSeen'] as DateTime).millisecondsSinceEpoch;
      }
      if (update['rssi'] != null) {
        batchUpdates['$deviceKey/rssi'] = update['rssi'];
      }
      if (update['hopCount'] != null) {
        batchUpdates['$deviceKey/hopCount'] = update['hopCount'];
      }
    }

    if (batchUpdates.isNotEmpty) {
      await ref.update(batchUpdates);
    }
  }

  /// Delete a device from registry
  ///
  /// Warning: This permanently removes the device from user's account.
  /// The device can be re-provisioned later if needed.
  Future<void> deleteDevice(String nodeId) async {
    final ref = _getUserDevicesRef();
    if (ref == null) {
      throw Exception('User not authenticated');
    }

    final deviceKey = 'device_$nodeId';
    await ref.child(deviceKey).remove();

    print('✅ Device deleted: $nodeId');
  }

  /// Check if a device is already registered
  Future<bool> isDeviceRegistered(String nodeId) async {
    final ref = _getUserDevicesRef();
    if (ref == null) return false;

    final deviceKey = 'device_$nodeId';
    final snapshot = await ref.child(deviceKey).get();

    return snapshot.exists;
  }

  /// Get count of registered devices
  Future<int> getDeviceCount() async {
    final ref = _getUserDevicesRef();
    if (ref == null) return 0;

    final snapshot = await ref.get();
    if (!snapshot.exists) return 0;

    final data = snapshot.value as Map<dynamic, dynamic>?;
    return data?.length ?? 0;
  }

  /// Sync all devices with routing table
  ///
  /// This compares registered devices with current routing table
  /// and updates online/offline status accordingly.
  ///
  /// Devices not in routing table are marked as offline.
  Future<void> syncWithRoutingTable(
    Map<String, dynamic> routingTableData,
  ) async {
    final ref = _getUserDevicesRef();
    if (ref == null) return;

    // Get all registered devices
    final snapshot = await ref.get();
    if (!snapshot.exists) return;

    final devicesData = snapshot.value as Map<dynamic, dynamic>;
    final updates = <Map<String, dynamic>>[];

    devicesData.forEach((key, value) {
      final nodeId = (value as Map)['nodeId'] as String;

      // Check if node exists in routing table
      final routingNode =
          routingTableData[nodeId] ?? routingTableData['node_$nodeId'];

      if (routingNode != null) {
        // Node is in routing table - update status
        final status = routingNode['status'] as String? ?? 'offline';
        final lastUpdate = routingNode['lastUpdate'] as int?;
        final rssi = routingNode['rssi'] as int?;
        final hopCount = routingNode['hopCount'] as int?;

        updates.add({
          'nodeId': nodeId,
          'isOnline': status == 'online',
          if (lastUpdate != null)
            'lastSeen': DateTime.fromMillisecondsSinceEpoch(lastUpdate),
          if (rssi != null) 'rssi': rssi,
          if (hopCount != null) 'hopCount': hopCount,
        });
      } else {
        // Node not in routing table - mark as offline
        updates.add({'nodeId': nodeId, 'isOnline': false});
      }
    });

    if (updates.isNotEmpty) {
      await batchUpdateDeviceStatuses(updates);
      print('✅ Synced ${updates.length} devices with routing table');
    }
  }

  /// Clean up duplicate device entries in Firebase
  /// Removes entries where multiple devices have the same nodeId (case-insensitive)
  /// Keeps only the normalized lowercase version (device_0xXXXX)
  Future<void> cleanupDuplicates() async {
    final ref = _getUserDevicesRef();
    if (ref == null) return;

    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) return;

      final devicesData = snapshot.value as Map<dynamic, dynamic>;
      final devicesByNodeId = <String, List<String>>{}; // nodeId -> [keys]

      // Group by nodeId (normalized to lowercase)
      devicesData.forEach((key, value) {
        if (value is Map) {
          final nodeId = (value['nodeId'] as String?)?.toLowerCase();
          if (nodeId != null) {
            devicesByNodeId.putIfAbsent(nodeId, () => []).add(key);
          }
        }
      });

      // Find and remove duplicates
      final keysToDelete = <String>[];
      devicesByNodeId.forEach((nodeId, keys) {
        if (keys.length > 1) {
          // Multiple entries for same nodeId - keep the best one
          print('⚠️ Found ${keys.length} entries for nodeId $nodeId: $keys');

          // Sort by key name (device_0xXXXX is better than others)
          keys.sort((a, b) {
            // Prefer normalized format: device_0xXXXX (lowercase)
            final aIsNormalized =
                a.toLowerCase().startsWith('device_0x') &&
                a.toLowerCase() == 'device_$nodeId';
            final bIsNormalized =
                b.toLowerCase().startsWith('device_0x') &&
                b.toLowerCase() == 'device_$nodeId';

            if (aIsNormalized && !bIsNormalized) return -1;
            if (!aIsNormalized && bIsNormalized) return 1;
            return 0;
          });

          // Keep first (best), delete rest
          for (int i = 1; i < keys.length; i++) {
            keysToDelete.add(keys[i]);
            print('🗑️ Marking for deletion: ${keys[i]}');
          }
        }
      });

      // Delete old entries
      for (final key in keysToDelete) {
        await ref.child(key).remove();
        print('✅ Deleted duplicate: $key');
      }

      if (keysToDelete.isNotEmpty) {
        print('✅ Cleaned up ${keysToDelete.length} duplicate entries');
      }
    } catch (e) {
      print('Error cleaning up duplicates: $e');
    }
  }
}
