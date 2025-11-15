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

                final nodeDevice = Device(
                  nodeId: nodeId,
                  name: deviceName,
                  type: deviceType,
                  gatewayMAC: gatewayMAC,
                  createdAt: routingTable.timestamp,
                  lastSeen: routingTable.timestamp,
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

  /// Get stream of sensor data for a specific node from sensor_data path
  /// Path: sensor_data/{userUID}/{nodeId}/{timestamp}
  Stream<List<SensorData>> getSensorDataStream({required String nodeId}) {
    final userUID = _currentUserUID;
    if (userUID == null) {
      return Stream.value(<SensorData>[]);
    }

    final ref = database.ref('$sensorDataPath/$userUID/$nodeId');
    return ref.orderByKey().limitToLast(100).onValue.map((event) {
      if (event.snapshot.value == null) {
        return <SensorData>[];
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final sensorDataList = <SensorData>[];

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
      return sensorDataList;
    });
  }

  /// Get latest sensor data (one-time fetch)
  /// Path: sensor_data/{userUID}/{nodeId}/{latest_timestamp}
  Future<SensorData?> getLatestSensorData(String nodeId) async {
    final userUID = _currentUserUID;
    if (userUID == null) return null;

    final ref = database.ref('$sensorDataPath/$userUID/$nodeId');
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

    final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp = endDate.millisecondsSinceEpoch ~/ 1000;

    final ref = database.ref('$sensorDataPath/$userUID/$nodeId');
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

    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch ~/ 1000;

    final ref = database.ref('$sensorDataPath/$userUID/$nodeId');
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

  /// Check if Firebase is available
  bool isAvailable() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
