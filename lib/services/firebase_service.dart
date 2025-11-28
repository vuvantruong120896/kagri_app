import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/sensor_data.dart';
import '../models/device.dart';
import '../models/gateway_status.dart';
import '../models/routing_table.dart';
import '../config/firebase_config.dart';
import 'auth_service.dart';

/// Firebase Realtime Database service with multi-user support
/// Database structure (multi-tenant):
/// - users/{userUID}/profile - User profile
/// - users/{userUID}/gateways/{gatewayMAC} - User's gateways
/// - nodes/{userUID}/{gatewayMAC}/{nodeId}/info - Node information
/// - nodes/{userUID}/{gatewayMAC}/{nodeId}/latest_data - Latest sensor reading
/// - sensor_data/{userUID}/{nodeId}/{timestamp} - Historical sensor data
/// - gateways/{userUID}/{gatewayMAC}/status - Gateway status
/// - gateways/{userUID}/{gatewayMAC}/routing_table - Network routing table
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Realtime Database instance (lazy initialization)
  FirebaseDatabase? _database;
  FirebaseDatabase get database {
    if (_database == null) {
      if (Firebase.apps.isEmpty) {
        throw Exception(
          'Firebase not initialized. Call Firebase.initializeApp() first.',
        );
      }
      _database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: FirebaseConfig.databaseUrl,
      );
    }
    return _database!;
  }

  // Database paths matching firmware structure
  static const String usersPath = 'users';
  static const String nodesPath = 'nodes';
  static const String sensorDataPath = 'sensor_data';
  static const String gatewaysPath = 'gateways';

  /// Get current user UID from AuthService
  String? get _currentUserUID => AuthService().currentUserUID;

  /// Get stream of devices from routing tables only
  /// Returns list of devices based on routing table entries
  /// Path: gateways/{userUID}/{gatewayMAC}/routing_table
  Stream<List<Device>> getNodesStream() {
    final userUID = _currentUserUID;

    // If user not logged in, return empty stream
    if (userUID == null) {
      return Stream.value(<Device>[]);
    }

    final gatewaysRef = database.ref('$gatewaysPath/$userUID');

    // Listen to gateways stream to get routing tables
    return gatewaysRef.onValue.asyncMap((gatewaysEvent) async {
      try {
        if (gatewaysEvent.snapshot.value == null) {
          return <Device>[];
        }

        final gatewaysData = Map<String, dynamic>.from(
          gatewaysEvent.snapshot.value as Map,
        );

        final List<Device> devices = [];

        // Process each gateway's routing table
        for (final gatewayMAC in gatewaysData.keys) {
          try {
            // Get routing table for this gateway
            final routingTableSnapshot = await database
                .ref('$gatewaysPath/$userUID/$gatewayMAC/routing_table')
                .get();

            if (routingTableSnapshot.value != null) {
              final routingData = Map<String, dynamic>.from(
                routingTableSnapshot.value as Map,
              );
              final routingTable = RoutingTable.fromJson(routingData);

              // Add all nodes from routing table (including gateway if present)
              for (final entry in routingTable.nodes.entries) {
                final nodeId = entry.key;
                final routeNode = entry.value;

                // Check if this node is the gateway (last 2 bytes of MAC)
                final macParts = gatewayMAC.split(':');
                final isGatewayNode =
                    macParts.length == 6 &&
                    nodeId.toUpperCase() ==
                        '0x${macParts[4]}${macParts[5]}'.toUpperCase();

                final deviceName = isGatewayNode
                    ? 'Gateway'
                    : 'Node ${nodeId.substring(2)}';
                final deviceType = isGatewayNode ? 'gateway' : 'sensor';

                // Get latest sensor data timestamp for accurate lastSeen
                // This is critical for online/offline detection
                // Use a short timeout to avoid blocking the stream
                // Default to epoch 0 to ensure Offline if no sensor data found
                DateTime lastSeenTimestamp =
                    DateTime.fromMillisecondsSinceEpoch(0);
                try {
                  // Set a timeout to prevent hanging if Firebase is slow
                  final latestSensorDataFuture = getLatestSensorData(nodeId);
                  final latestSensorData = await latestSensorDataFuture.timeout(
                    const Duration(seconds: 5),
                    onTimeout: () {
                      print(
                        'Timeout getting sensor data for $nodeId, using routing table timestamp',
                      );
                      return null;
                    },
                  );

                  if (latestSensorData != null) {
                    lastSeenTimestamp = latestSensorData.timestamp;
                  }
                } catch (e) {
                  print('Error getting latest sensor data for $nodeId: $e');
                  // Fallback to routing table timestamp
                }

                final nodeDevice = Device(
                  nodeId: nodeId,
                  name: deviceName,
                  type: deviceType,
                  gatewayMAC: gatewayMAC,
                  createdAt: routingTable.timestamp,
                  lastSeen:
                      lastSeenTimestamp, // Use actual sensor data timestamp
                  inRoutingTable: true,
                  via: routeNode.via,
                  metric: routeNode.metric,
                  rssi: routeNode.rssi,
                  snr: routeNode.snr,
                );
                devices.add(nodeDevice);
              }
            }
          } catch (e) {
            print('Error processing gateway $gatewayMAC: $e');
          }
        }

        // Sort devices: gateways first, then nodes
        final gateways = devices.where((d) => d.isGateway).toList();
        final nodes = devices.where((d) => !d.isGateway).toList();

        gateways.sort((a, b) => a.nodeId.compareTo(b.nodeId));
        nodes.sort((a, b) => a.nodeId.compareTo(b.nodeId));

        return [...gateways, ...nodes];
      } catch (e) {
        print('Error getting routing tables: $e');
        return <Device>[];
      }
    });
  }

  /// Normalize nodeId to match Gateway format (0xXXXX with uppercase hex digits)
  /// Handles: "0xABCD", "0xabcd", "ABCD", "abcd", "0x0abc" -> "0xABC"
  String _normalizeNodeId(String nodeId) {
    String hexPart = nodeId.toLowerCase();

    // Remove '0x' prefix if present
    if (hexPart.startsWith('0x')) {
      hexPart = hexPart.substring(2);
    }

    // Remove leading zeros and convert to uppercase
    hexPart = int.parse(hexPart, radix: 16).toRadixString(16).toUpperCase();

    return '0x$hexPart';
  }

  /// Get stream of sensor data for a specific node from sensor_data path
  /// Path: sensor_data/{userUID}/{nodeId}/{timestamp}
  ///
  /// Gateway sends data with format: 0xA30 (uppercase hex digits)
  /// User registry might have: 0x0a30 (lowercase with leading zeros)
  /// This function normalizes both to: 0xA30
  Stream<List<SensorData>> getSensorDataStream({required String nodeId}) {
    final userUID = _currentUserUID;
    if (userUID == null) {
      print('⚠️ No user authenticated');
      return Stream.value(<SensorData>[]);
    }

    // Try multiple formats to handle different Firebase storage formats
    List<String> possibleFormats = [
      _normalizeNodeId(nodeId), // 0xA30
      nodeId.toLowerCase(), // 0x0a30
      nodeId.toUpperCase(), // 0X0A30
      nodeId, // original format
    ];

    print(
      '🔍 getSensorDataStream: $nodeId → trying formats: ${possibleFormats.join(", ")}',
    );

    // Try each format until we find data
    return Stream.fromFuture(
      _findSensorDataWithFormats(userUID, possibleFormats, nodeId),
    ).asyncExpand((foundFormat) {
      if (foundFormat != null) {
        print('✅ Found sensor data using format: $foundFormat');
        final ref = database.ref('$sensorDataPath/$userUID/$foundFormat');
        return ref.orderByKey().limitToLast(100).onValue.map((event) {
          if (event.snapshot.value == null) {
            return <SensorData>[];
          }
          return _parseSensorData(event.snapshot.value, nodeId);
        });
      } else {
        print('⚠️ No sensor data found for $nodeId in any format');
        return Stream.value(<SensorData>[]);
      }
    });
  }

  /// Helper function to find which format has data in Firebase
  Future<String?> _findSensorDataWithFormats(
    String userUID,
    List<String> formats,
    String originalNodeId,
  ) async {
    for (String format in formats) {
      try {
        final ref = database.ref('$sensorDataPath/$userUID/$format');
        final snapshot = await ref.limitToLast(1).get();
        if (snapshot.value != null) {
          print('✅ Found data with format: $format for node: $originalNodeId');
          return format;
        } else {
          print('❌ No data with format: $format for node: $originalNodeId');
        }
      } catch (e) {
        print('❌ Error checking format $format: $e');
      }
    }
    return null;
  }

  /// Helper to parse sensor data from Firebase snapshot
  List<SensorData> _parseSensorData(dynamic snapshotValue, String nodeId) {
    if (snapshotValue == null) {
      return <SensorData>[];
    }

    final data = Map<String, dynamic>.from(snapshotValue as Map);
    final sensorDataList = <SensorData>[];

    print('📊 Parsing ${data.length} sensor entries for $nodeId');

    data.forEach((timestamp, sensorJson) {
      if (sensorJson is Map) {
        try {
          final sensorMap = Map<String, dynamic>.from(sensorJson);
          // Add timestamp from key if not in data
          if (!sensorMap.containsKey('timestamp')) {
            sensorMap['timestamp'] = int.parse(timestamp);
          }
          final sensorData = SensorData.fromJson(
            sensorMap,
            nodeId: nodeId,
            id: timestamp,
          );
          sensorDataList.add(sensorData);
        } catch (e) {
          print('Error parsing sensor data for $nodeId at $timestamp: $e');
        }
      }
    });

    // Sort by timestamp descending (newest first)
    sensorDataList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    print('✅ Returning ${sensorDataList.length} sensor data items');
    return sensorDataList;
  }

  /// Get latest sensor data (one-time fetch)
  /// Path: sensor_data/{userUID}/{nodeId}/{latest_timestamp}
  Future<SensorData?> getLatestSensorData(String nodeId) async {
    final userUID = _currentUserUID;
    if (userUID == null) return null;

    // Normalize nodeId to match Gateway format
    String normalizedNodeId = _normalizeNodeId(nodeId);

    final ref = database.ref('$sensorDataPath/$userUID/$normalizedNodeId');
    final snapshot = await ref.orderByKey().limitToLast(1).get();

    if (snapshot.value == null) return null;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    if (data.isEmpty) return null;

    final entry = data.entries.first;
    final sensorMap = Map<String, dynamic>.from(entry.value);
    if (!sensorMap.containsKey('timestamp')) {
      sensorMap['timestamp'] = int.parse(entry.key);
    }

    return SensorData.fromJson(sensorMap, nodeId: nodeId, id: entry.key);
  }

  /// Get historical sensor data by date range
  /// Path: sensor_data/{userUID}/{nodeId}/{timestamp}
  Future<List<SensorData>> getSensorDataByDateRange({
    required String nodeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final userUID = _currentUserUID;

    // If user not logged in, return empty list
    if (userUID == null) {
      return <SensorData>[];
    }

    // Normalize nodeId to match Gateway format
    String normalizedNodeId = _normalizeNodeId(nodeId);

    final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp = endDate.millisecondsSinceEpoch ~/ 1000;

    final ref = database.ref('$sensorDataPath/$userUID/$normalizedNodeId');
    final snapshot = await ref
        .orderByKey()
        .startAt(startTimestamp.toString())
        .endAt(endTimestamp.toString())
        .get();

    if (snapshot.value == null) return <SensorData>[];

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final List<SensorData> sensorDataList = [];

    data.forEach((timestampKey, value) {
      if (value is Map) {
        final sensorMap = Map<String, dynamic>.from(value);
        if (!sensorMap.containsKey('timestamp')) {
          sensorMap['timestamp'] = int.parse(timestampKey);
        }
        sensorDataList.add(
          SensorData.fromJson(sensorMap, nodeId: nodeId, id: timestampKey),
        );
      }
    });

    // Sort by timestamp descending
    sensorDataList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sensorDataList;
  }

  /// Get gateway status stream
  /// Path: gateways/{userUID}/{gatewayMAC}/status
  Stream<GatewayStatus?> getGatewayStatusStream(String gatewayMAC) {
    final userUID = _currentUserUID;
    if (userUID == null) {
      return Stream.value(null);
    }

    final ref = database.ref('$gatewaysPath/$userUID/$gatewayMAC/status');

    return ref.onValue.map((event) {
      if (event.snapshot.value == null) return null;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return GatewayStatus.fromJson(data, gatewayId: gatewayMAC);
    });
  }

  /// Get list of all gateways for current user
  /// Path: gateways/{userUID}/
  Stream<List<String>> getGatewaysStream() {
    final userUID = _currentUserUID;
    if (userUID == null) {
      return Stream.value(<String>[]);
    }

    final ref = database.ref('$gatewaysPath/$userUID');

    return ref.onValue.map((event) {
      if (event.snapshot.value == null) return <String>[];

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.keys.toList();
    });
  }

  /// Get routing table stream from gateway
  /// Path: gateways/{userUID}/{gatewayMAC}/routing_table
  Stream<RoutingTable?> getRoutingTableStream(String gatewayMAC) {
    final userUID = _currentUserUID;
    if (userUID == null) {
      return Stream.value(null);
    }

    final ref = database.ref(
      '$gatewaysPath/$userUID/$gatewayMAC/routing_table',
    );

    return ref.onValue.map((event) {
      if (event.snapshot.value == null) return null;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return RoutingTable.fromJson(data);
    });
  }

  /// Get routing table (one-time fetch)
  /// Path: gateways/{userUID}/{gatewayMAC}/routing_table
  Future<RoutingTable?> getRoutingTable(String gatewayMAC) async {
    final userUID = _currentUserUID;
    if (userUID == null) return null;

    final ref = database.ref(
      '$gatewaysPath/$userUID/$gatewayMAC/routing_table',
    );
    final snapshot = await ref.get();

    if (snapshot.value == null) return null;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return RoutingTable.fromJson(data);
  }

  /// Get node info (one-time fetch)
  /// Path: nodes/{userUID}/{gatewayMAC}/{nodeId}/info
  Future<Device?> getNodeInfo(String nodeId, {String? gatewayMAC}) async {
    final userUID = _currentUserUID;
    if (userUID == null || gatewayMAC == null) return null;

    final ref = database.ref('$nodesPath/$userUID/$gatewayMAC/$nodeId/info');
    final snapshot = await ref.get();

    if (snapshot.value == null) return null;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return Device.fromJson(data, nodeId: nodeId);
  }

  /// Update node info
  /// Path: nodes/{userUID}/{gatewayMAC}/{nodeId}/info
  /// This is typically done by the gateway, but mobile app can update name
  Future<void> updateNodeInfo(
    String nodeId,
    Map<String, dynamic> updates, {
    String? gatewayMAC,
  }) async {
    final userUID = _currentUserUID;
    if (userUID == null || gatewayMAC == null) {
      throw Exception('User not logged in or gatewayMAC not provided');
    }

    final ref = database.ref('$nodesPath/$userUID/$gatewayMAC/$nodeId/info');
    await ref.update(updates);
  }

  /// Write sensor data (for testing only - normally done by gateway)
  /// Path: nodes/{userUID}/{gatewayMAC}/{nodeId}/latest_data
  /// Path: sensor_data/{userUID}/{nodeId}/{timestamp}
  Future<void> addSensorData(
    String nodeId,
    SensorData sensorData, {
    String? gatewayMAC,
  }) async {
    final userUID = _currentUserUID;
    if (userUID == null || gatewayMAC == null) {
      throw Exception('User not logged in or gatewayMAC not provided');
    }

    final timestamp = sensorData.timestamp.millisecondsSinceEpoch ~/ 1000;

    // Write to latest_data
    await database
        .ref('$nodesPath/$userUID/$gatewayMAC/$nodeId/latest_data')
        .set(sensorData.toJson());

    // Write to historical data
    await database
        .ref('$sensorDataPath/$userUID/$nodeId/$timestamp')
        .set(sensorData.toJson());
  }

  /// Clean up old sensor data (older than specified days)
  /// Path: sensor_data/{userUID}/{nodeId}/{timestamp}
  Future<void> cleanupOldData(String nodeId, {int daysToKeep = 7}) async {
    final userUID = _currentUserUID;
    if (userUID == null) return;

    // Normalize nodeId to match Gateway format
    String normalizedNodeId = _normalizeNodeId(nodeId);

    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch ~/ 1000;

    final ref = database.ref('$sensorDataPath/$userUID/$normalizedNodeId');
    final snapshot = await ref
        .orderByKey()
        .endAt(cutoffTimestamp.toString())
        .get();

    if (snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      // Delete old entries
      for (var key in data.keys) {
        await ref.child(key).remove();
      }
    }
  }

  /// Upload Handheld sensor data to Firebase
  /// Stores data in: sensor_data/{userUID}/handheld/{timestamp}
  /// Also updates: nodes/handheld/latest_data (if it exists)
  /// This is for manual sensor readings from handheld devices via BLE
  Future<bool> addHandheldSensorData(
    Map<String, dynamic> sensorDataJson,
    String nodeId,
  ) async {
    try {
      final userUID = _currentUserUID;
      if (userUID == null) {
        throw Exception('User not logged in');
      }

      // Create timestamp from current time or from provided timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Prepare data for Firebase
      final data = Map<String, dynamic>.from(sensorDataJson);
      data['timestamp'] = timestamp;
      data['deviceType'] = 'soil_sensor'; // Handheld is soil sensor
      data['nodeId'] = nodeId; // Use device-specific nodeID (last 2 bytes)

      print('[Firebase] Uploading handheld sensor data: $data');

      // Write to historical data: sensor_data/{userUID}/{nodeId}/{timestamp}
      await database
          .ref('$sensorDataPath/$userUID/$nodeId/$timestamp')
          .set(data);

      print(
        '[Firebase] ✅ Handheld sensor data uploaded successfully to nodeID: $nodeId',
      );
      return true;
    } catch (e) {
      print('[Firebase] ❌ Error uploading handheld sensor data: $e');
      return false;
    }
  }

  /// Register a new Gateway after BLE provisioning
  /// Creates initial entry in gateways/{userUID}/{gatewayMAC}/status
  /// and nodes/{userUID}/{gatewayMAC}/{gatewayNodeId}/info
  Future<void> registerGateway(String gatewayMAC) async {
    final userUID = _currentUserUID;
    if (userUID == null) {
      throw Exception('User not logged in');
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Create Gateway status entry
    await database.ref('$gatewaysPath/$userUID/$gatewayMAC/status').set({
      'created_at': now,
      'last_seen': now,
      'firmware_version': 'Unknown',
      'status': 'provisioned',
    });

    // Create Gateway node entry (using last 2 bytes of MAC as nodeId)
    final macParts = gatewayMAC.split(':');
    if (macParts.length == 6) {
      final gatewayNodeId = '0x${macParts[4]}${macParts[5]}';
      await database
          .ref('$nodesPath/$userUID/$gatewayMAC/$gatewayNodeId/info')
          .set({
            'address': gatewayNodeId,
            'name': 'Gateway',
            'type': 'gateway',
            'gateway_mac': gatewayMAC,
            'created_at': now,
            'last_seen': now,
          });
    }
  }

  /// Check if Firebase is available
  bool isAvailable() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
