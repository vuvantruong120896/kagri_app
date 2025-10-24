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

  /// Get stream of all nodes with their latest data for current user
  /// Returns list of devices with latest sensor readings
  /// Path: nodes/{userUID}/{gatewayMAC}/{nodeId}/
  /// Note: Gateway devices are identified by isGateway property (MAC format nodeId)
  Stream<List<Device>> getNodesStream() {
    final userUID = _currentUserUID;

    // If user not logged in, return empty stream
    if (userUID == null) {
      return Stream.value(<Device>[]);
    }

    final nodesRef = database.ref('$nodesPath/$userUID');
    final gatewaysRef = database.ref('$gatewaysPath/$userUID');

    // Listen to nodes stream and combine with routing tables + gateway status
    return nodesRef.onValue.asyncMap((nodesEvent) async {
      try {
        // For each nodes event, fetch latest gateways and routing tables
        final gatewaysSnapshot = await gatewaysRef.get();

        if (gatewaysSnapshot.value == null) {
          return _buildDevicesFromNodes(nodesEvent, {}, {});
        }

        final gatewaysData = Map<String, dynamic>.from(
          gatewaysSnapshot.value as Map,
        );

        // Fetch all routing tables and gateway status for each gateway concurrently
        final routingTableFutures = <String, Future<RoutingTable?>>{};
        final gatewayStatusFutures = <String, Future<GatewayStatus?>>{};

        for (final gatewayMAC in gatewaysData.keys) {
          routingTableFutures[gatewayMAC] = database
              .ref('$gatewaysPath/$userUID/$gatewayMAC/routing_table')
              .get()
              .then((snapshot) {
                if (snapshot.value == null) return null;
                final data = Map<String, dynamic>.from(snapshot.value as Map);
                return RoutingTable.fromJson(data);
              })
              .catchError((_) => null as RoutingTable?);

          gatewayStatusFutures[gatewayMAC] = database
              .ref('$gatewaysPath/$userUID/$gatewayMAC/status')
              .get()
              .then((snapshot) {
                if (snapshot.value == null) return null;
                final data = Map<String, dynamic>.from(snapshot.value as Map);
                return GatewayStatus.fromJson(data, gatewayId: gatewayMAC);
              })
              .catchError((_) => null as GatewayStatus?);
        }

        // Wait for all routing tables and gateway status to load
        final routingTables = <String, RoutingTable?>{};
        final gatewayStatuses = <String, GatewayStatus?>{};

        for (final entry in routingTableFutures.entries) {
          routingTables[entry.key] = await entry.value;
        }

        for (final entry in gatewayStatusFutures.entries) {
          gatewayStatuses[entry.key] = await entry.value;
        }

        return _buildDevicesFromNodes(
          nodesEvent,
          routingTables,
          gatewayStatuses,
        );
      } catch (e) {
        print('Error fetching gateways and routing tables: $e');
        return _buildDevicesFromNodes(nodesEvent, {}, {});
      }
    });
  }

  /// Build devices from nodes data, merging with routing table info and gateway status
  /// IMPORTANT: Includes nodes from routing table even if they don't have entries in nodes/
  /// Also includes gateways from gateway status
  List<Device> _buildDevicesFromNodes(
    DatabaseEvent event,
    Map<String, RoutingTable?> routingTables,
    Map<String, GatewayStatus?> gatewayStatuses,
  ) {
    final data = event.snapshot.value != null
        ? Map<String, dynamic>.from(event.snapshot.value as Map)
        : <String, dynamic>{};

    final List<Device> devices = [];
    final processedNodeIds =
        <String, Set<String>>{}; // Track processed nodes per gateway

    // Step 1: Process nodes from nodes/ path (these have info/latest_data)
    data.forEach((gatewayMAC, gatewayData) {
      if (gatewayData is Map) {
        final gatewayMap = Map<String, dynamic>.from(gatewayData);
        final routingTable = routingTables[gatewayMAC];
        processedNodeIds[gatewayMAC] = {};

        // Iterate through nodes under this gateway
        gatewayMap.forEach((nodeId, nodeData) {
          if (nodeData is Map) {
            final nodeMap = Map<String, dynamic>.from(nodeData);

            // Merge info and latest_data
            final info = nodeMap['info'] != null
                ? Map<String, dynamic>.from(nodeMap['info'] as Map)
                : <String, dynamic>{};

            // Add gateway MAC to device info
            info['gatewayMAC'] = gatewayMAC;

            // Create device with info
            var device = Device.fromJson(info, nodeId: nodeId);

            // Check if node is in routing table
            final inRoutingTable =
                routingTable?.nodes.containsKey(nodeId) ?? false;
            final routeNode = inRoutingTable
                ? routingTable!.nodes[nodeId]
                : null;

            // Attach latest data if available + routing table info
            if (nodeMap['latest_data'] != null) {
              final latestDataMap = Map<String, dynamic>.from(
                nodeMap['latest_data'] as Map,
              );
              final latestData = SensorData.fromJson(
                latestDataMap,
                nodeId: nodeId,
              );
              device = device.copyWith(
                latestData: latestData,
                lastSeen: latestData.timestamp,
                inRoutingTable: inRoutingTable,
                via: routeNode?.via,
                metric: routeNode?.metric ?? 0,
                rssi: routeNode?.rssi,
                snr: routeNode?.snr,
              );
            } else {
              // No latest data, but still update routing table info
              device = device.copyWith(
                inRoutingTable: inRoutingTable,
                via: routeNode?.via,
                metric: routeNode?.metric ?? 0,
                rssi: routeNode?.rssi,
                snr: routeNode?.snr,
              );
            }

            devices.add(device);
            processedNodeIds[gatewayMAC]!.add(nodeId);
          }
        });
      }
    });

    // Step 2: Add nodes from routing table that are NOT in nodes/ path
    routingTables.forEach((gatewayMAC, routingTable) {
      if (routingTable != null) {
        final processedSet = processedNodeIds[gatewayMAC] ?? {};

        // For each node in routing table
        routingTable.nodes.forEach((nodeId, routeNode) {
          // Skip if already processed
          if (processedSet.contains(nodeId)) {
            return;
          }

          // Create a device from routing table entry only
          // Use routing table timestamp as lastSeen since we don't have actual data timestamp
          final device = Device(
            nodeId: nodeId,
            name:
                'Node ${nodeId.substring(2)}', // e.g., "Node CC64" from "0xCC64"
            type: 'sensor',
            gatewayMAC: gatewayMAC,
            createdAt: routingTable.timestamp,
            lastSeen: routingTable.timestamp, // Use routing table timestamp
            inRoutingTable: true,
            via: routeNode.via,
            metric: routeNode.metric,
            rssi: routeNode.rssi,
            snr: routeNode.snr,
          );

          devices.add(device);
        });
      }
    });

    // Step 3: Add gateways from gateway status that are not already in devices
    gatewayStatuses.forEach((gatewayMAC, gatewayStatus) {
      if (gatewayStatus != null) {
        // Check if this gateway is already in devices (from nodes path)
        final gatewayExists = devices.any(
          (d) =>
              d.isGateway &&
              (d.nodeId == gatewayMAC || d.gatewayMAC == gatewayMAC),
        );

        if (!gatewayExists) {
          // Create a device from gateway status only
          // Use status timestamp as lastSeen
          final device = Device(
            nodeId: gatewayMAC, // Gateway nodeId is its MAC address
            name: 'Gateway',
            type: 'gateway',
            gatewayMAC: gatewayMAC,
            createdAt: gatewayStatus.timestamp,
            lastSeen: gatewayStatus.timestamp,
          );

          devices.add(device);
        }
      }
    });

    // Step 4: Separate gateways and nodes, then sort stably
    final gateways = <Device>[];
    final nodes = <Device>[];

    for (final device in devices) {
      if (device.isGateway) {
        gateways.add(device);
      } else {
        nodes.add(device);
      }
    }

    // Sort gateways by MAC (stable order)
    gateways.sort(
      (a, b) => (a.gatewayMAC ?? a.nodeId).compareTo(b.gatewayMAC ?? b.nodeId),
    );

    // Sort nodes by nodeId (stable order)
    nodes.sort((a, b) => a.nodeId.compareTo(b.nodeId));

    // Combine: gateways first, then nodes
    return [...gateways, ...nodes];
  }

  /// Get stream of latest sensor data for a specific node
  /// Path: nodes/{userUID}/{gatewayMAC}/{nodeId}/latest_data
  Stream<SensorData?> getLatestDataStream(String nodeId, {String? gatewayMAC}) {
    final userUID = _currentUserUID;
    if (userUID == null || gatewayMAC == null) {
      return Stream.value(null);
    }

    final ref = database.ref(
      '$nodesPath/$userUID/$gatewayMAC/$nodeId/latest_data',
    );

    return ref.onValue.map((event) {
      if (event.snapshot.value == null) return null;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return SensorData.fromJson(data, nodeId: nodeId);
    });
  }

  /// Get stream of historical sensor data for a node
  /// Path: sensor_data/{userUID}/{nodeId}/{timestamp}
  /// Returns data sorted by timestamp (newest first)
  Stream<List<SensorData>> getSensorDataStream({
    required String nodeId,
    int limit = 100,
  }) {
    final userUID = _currentUserUID;

    // If user not logged in, return empty stream
    if (userUID == null) {
      return Stream.value(<SensorData>[]);
    }

    final ref = database.ref('$sensorDataPath/$userUID/$nodeId');

    return ref.orderByKey().limitToLast(limit).onValue.map((event) {
      if (event.snapshot.value == null) return <SensorData>[];

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final List<SensorData> sensorDataList = [];

      data.forEach((timestampKey, value) {
        if (value is Map) {
          final sensorMap = Map<String, dynamic>.from(value);
          // Add timestamp from key if not in data
          if (!sensorMap.containsKey('timestamp')) {
            sensorMap['timestamp'] = int.parse(timestampKey);
          }
          sensorDataList.add(
            SensorData.fromJson(sensorMap, nodeId: nodeId, id: timestampKey),
          );
        }
      });

      // Sort by timestamp descending (newest first)
      sensorDataList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return sensorDataList;
    });
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

  /// Get latest sensor data (one-time fetch)
  /// Path: nodes/{userUID}/{gatewayMAC}/{nodeId}/latest_data
  Future<SensorData?> getLatestSensorData(
    String nodeId, {
    String? gatewayMAC,
  }) async {
    final userUID = _currentUserUID;
    if (userUID == null || gatewayMAC == null) return null;

    final ref = database.ref(
      '$nodesPath/$userUID/$gatewayMAC/$nodeId/latest_data',
    );
    final snapshot = await ref.get();

    if (snapshot.value == null) return null;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return SensorData.fromJson(data, nodeId: nodeId);
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
