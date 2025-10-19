import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Service to send commands to Gateway via Firebase and listen for results
class FirebaseCommandService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  StreamSubscription? _resultSubscription;

  /// Send start provisioning command to Gateway
  ///
  /// [userUID] - Current user's Firebase UID
  /// [gatewayMAC] - Gateway MAC address (e.g., "AA:BB:CC:DD:EE:FF")
  /// [durationMs] - Provisioning duration in milliseconds
  ///
  /// Returns command ID for tracking
  Future<String> sendStartProvisioningCommand({
    required String userUID,
    required String gatewayMAC,
    required int durationMs,
  }) async {
    // Generate unique command ID
    final commandId = 'cmd-${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Create command data
    final commandData = {
      'id': commandId,
      'type': 'start_provisioning',
      'params': {'durationMs': durationMs},
      'timestamp': timestamp,
      'priority': 5,
    };

    // Write to pending queue
    final commandPath =
        'users/$userUID/commands/$gatewayMAC/pending/$commandId';
    await _database.child(commandPath).set(commandData);

    debugPrint('📤 Sent start_provisioning command: $commandId');
    return commandId;
  }

  /// Send stop provisioning command to Gateway
  Future<String> sendStopProvisioningCommand({
    required String userUID,
    required String gatewayMAC,
  }) async {
    final commandId = 'cmd-${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final commandData = {
      'id': commandId,
      'type': 'stop_provisioning',
      'params': {},
      'timestamp': timestamp,
      'priority': 10, // Higher priority to stop immediately
    };

    final commandPath =
        'users/$userUID/commands/$gatewayMAC/pending/$commandId';
    await _database.child(commandPath).set(commandData);

    debugPrint('📤 Sent stop_provisioning command: $commandId');
    return commandId;
  }

  /// Send netkey assignment command to Gateway
  /// This tells the gateway to distribute netkey to newly discovered nodes
  Future<String> sendNetkeyCommand({
    required String userUID,
    required String gatewayMAC,
  }) async {
    final commandId = 'cmd-${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final commandData = {
      'id': commandId,
      'type': 'assign_netkey',
      'params': {},
      'timestamp': timestamp,
      'priority': 8, // High priority for netkey assignment
    };

    final commandPath =
        'users/$userUID/commands/$gatewayMAC/pending/$commandId';
    await _database.child(commandPath).set(commandData);

    debugPrint('📤 Sent assign_netkey command: $commandId');
    return commandId;
  }

  /// Listen to command results from Gateway
  ///
  /// Returns a stream of command result updates
  Stream<CommandResult> listenToCommandResults({
    required String userUID,
    required String gatewayMAC,
  }) {
    final resultPath = 'users/$userUID/command_results/$gatewayMAC';

    return _database.child(resultPath).onValue.map((event) {
      if (event.snapshot.value == null) {
        return CommandResult(
          commandId: '',
          status: 'unknown',
          message: 'No data',
          gatewayOnline: false,
        );
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      return CommandResult(
        commandId: data['last_command_id'] ?? '',
        commandType: data['last_command_type'] ?? '',
        status: data['status'] ?? 'unknown',
        message: data['message'] ?? '',
        timestamp: data['timestamp'] ?? 0,
        gatewayOnline: data['gateway_online'] ?? false,
        lastPoll: data['last_poll'] ?? 0,
        progress: data['progress'] != null
            ? ProvisioningProgress.fromMap(
                Map<String, dynamic>.from(data['progress'] as Map),
              )
            : null,
        result: data['result'] != null
            ? Map<String, dynamic>.from(data['result'] as Map)
            : null,
      );
    });
  }

  /// Check if command is completed (moved to completed/ or failed/)
  Future<CommandStatus?> checkCommandStatus({
    required String userUID,
    required String gatewayMAC,
    required String commandId,
  }) async {
    // Check completed
    final completedPath =
        'users/$userUID/commands/$gatewayMAC/completed/$commandId';
    final completedSnapshot = await _database.child(completedPath).get();

    if (completedSnapshot.exists) {
      final data = Map<String, dynamic>.from(completedSnapshot.value as Map);
      return CommandStatus(
        commandId: commandId,
        status: 'completed',
        result: data['result'] ?? 'success',
        message: data['message'] ?? '',
        completedAt: data['completedAt'] ?? 0,
        details: data['details'],
      );
    }

    // Check failed
    final failedPath = 'users/$userUID/commands/$gatewayMAC/failed/$commandId';
    final failedSnapshot = await _database.child(failedPath).get();

    if (failedSnapshot.exists) {
      final data = Map<String, dynamic>.from(failedSnapshot.value as Map);
      return CommandStatus(
        commandId: commandId,
        status: 'failed',
        result: 'failed',
        message: data['message'] ?? '',
        errorCode: data['errorCode'] ?? '',
        failedAt: data['failedAt'] ?? 0,
      );
    }

    // Check processing
    final processingPath =
        'users/$userUID/commands/$gatewayMAC/processing/$commandId';
    final processingSnapshot = await _database.child(processingPath).get();

    if (processingSnapshot.exists) {
      return CommandStatus(
        commandId: commandId,
        status: 'processing',
        result: 'processing',
        message: 'Command is being executed',
      );
    }

    // Still pending or not found
    return null;
  }

  /// Cleanup old commands
  Future<void> cleanupOldCommands({
    required String userUID,
    required String gatewayMAC,
    int keepLastN = 10,
  }) async {
    // Get completed commands
    final completedPath = 'users/$userUID/commands/$gatewayMAC/completed';
    final completedSnapshot = await _database.child(completedPath).get();

    if (completedSnapshot.exists) {
      final commands = Map<String, dynamic>.from(
        completedSnapshot.value as Map,
      );

      // Sort by timestamp (oldest first)
      final sortedKeys = commands.keys.toList()
        ..sort((a, b) {
          final aTime = (commands[a] as Map)['completedAt'] ?? 0;
          final bTime = (commands[b] as Map)['completedAt'] ?? 0;
          return (aTime as int).compareTo(bTime as int);
        });

      // Delete old commands (keep only last N)
      if (sortedKeys.length > keepLastN) {
        final toDelete = sortedKeys.take(sortedKeys.length - keepLastN);
        for (final key in toDelete) {
          await _database.child('$completedPath/$key').remove();
        }
        debugPrint('🧹 Cleaned up ${toDelete.length} old commands');
      }
    }
  }

  /// Fetch routing table nodes with real RSSI/SNR data from Gateway
  ///
  /// [userUID] - Current user's Firebase UID
  /// [gatewayMAC] - Gateway MAC address (e.g., "AA:BB:CC:DD:EE:FF")
  ///
  /// Returns list of discovered nodes with address, RSSI, SNR
  Future<List<DiscoveredNode>> fetchRoutingTableNodes({
    required String userUID,
    required String gatewayMAC,
  }) async {
    try {
      final routingTablePath = 'gateways/$userUID/$gatewayMAC/routing_table';

      final snapshot = await _database.child(routingTablePath).get();

      if (!snapshot.exists) {
        debugPrint('⚠️ No routing table found at $routingTablePath');
        return [];
      }

      final routingData = Map<String, dynamic>.from(snapshot.value as Map);

      if (!routingData.containsKey('nodes')) {
        debugPrint('⚠️ No nodes found in routing table');
        return [];
      }

      final nodesMap = Map<String, dynamic>.from(routingData['nodes'] as Map);
      final nodes = <DiscoveredNode>[];

      for (final entry in nodesMap.entries) {
        final nodeData = Map<String, dynamic>.from(entry.value as Map);
        try {
          nodes.add(DiscoveredNode.fromMap(nodeData));
        } catch (e) {
          debugPrint('⚠️ Failed to parse node ${entry.key}: $e');
        }
      }

      debugPrint('✅ Fetched ${nodes.length} nodes from routing table');
      return nodes;
    } catch (e) {
      debugPrint('❌ Error fetching routing table: $e');
      return [];
    }
  }

  /// Listen to routing table changes in real-time
  ///
  /// [userUID] - Current user's Firebase UID
  /// [gatewayMAC] - Gateway MAC address
  ///
  /// Returns a stream of node lists that updates whenever routing table changes
  Stream<List<DiscoveredNode>> listenToRoutingTableNodes({
    required String userUID,
    required String gatewayMAC,
  }) {
    final routingTablePath = 'gateways/$userUID/$gatewayMAC/routing_table';

    return _database.child(routingTablePath).onValue.map((event) {
      if (event.snapshot.value == null) {
        return [];
      }

      final routingData = Map<String, dynamic>.from(
        event.snapshot.value as Map,
      );

      if (!routingData.containsKey('nodes')) {
        return [];
      }

      final nodesMap = Map<String, dynamic>.from(routingData['nodes'] as Map);
      final nodes = <DiscoveredNode>[];

      for (final entry in nodesMap.entries) {
        final nodeData = Map<String, dynamic>.from(entry.value as Map);
        try {
          nodes.add(DiscoveredNode.fromMap(nodeData));
        } catch (e) {
          debugPrint('⚠️ Failed to parse node ${entry.key}: $e');
        }
      }

      return nodes;
    });
  }

  /// Cancel listening to results
  void dispose() {
    _resultSubscription?.cancel();
  }
}

/// Command result from Gateway (real-time updates)
class CommandResult {
  final String commandId;
  final String commandType;
  final String status; // processing, completed, failed
  final String message;
  final int timestamp;
  final bool gatewayOnline;
  final int lastPoll;
  final ProvisioningProgress? progress;
  final Map<String, dynamic>? result;

  CommandResult({
    required this.commandId,
    this.commandType = '',
    required this.status,
    required this.message,
    this.timestamp = 0,
    this.gatewayOnline = false,
    this.lastPoll = 0,
    this.progress,
    this.result,
  });

  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}

/// Provisioning progress data
class ProvisioningProgress {
  final int nodesDiscovered;
  final int timeRemainingMs;

  ProvisioningProgress({
    required this.nodesDiscovered,
    required this.timeRemainingMs,
  });

  factory ProvisioningProgress.fromMap(Map<String, dynamic> map) {
    return ProvisioningProgress(
      nodesDiscovered: map['nodes_discovered'] ?? 0,
      timeRemainingMs: map['time_remaining_ms'] ?? 0,
    );
  }

  int get timeRemainingSec => (timeRemainingMs / 1000).ceil();

  String get timeRemainingFormatted {
    final seconds = timeRemainingSec;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// Command final status (from completed/failed paths)
class CommandStatus {
  final String commandId;
  final String status;
  final String result;
  final String message;
  final String? errorCode;
  final int? completedAt;
  final int? failedAt;
  final dynamic details;

  CommandStatus({
    required this.commandId,
    required this.status,
    required this.result,
    required this.message,
    this.errorCode,
    this.completedAt,
    this.failedAt,
    this.details,
  });

  bool get isSuccess => result == 'success';
}

/// Discovered node from routing table
class DiscoveredNode {
  final String address; // e.g., "0xCC64"
  final String? via; // e.g., "0xFFFF" for direct connection
  final int metric; // hop count (1 = direct, 2+ = multi-hop)
  final int rssi; // Received signal strength in dBm (-120 to -30)
  final double snr; // Signal-to-noise ratio in dB
  final int role; // Node role bitmask
  final int? lastSeen; // Timestamp of last connection
  final bool isDirect; // True if metric == 1 (direct connection)

  DiscoveredNode({
    required this.address,
    this.via,
    required this.metric,
    required this.rssi,
    required this.snr,
    required this.role,
    this.lastSeen,
  }) : isDirect = metric == 1;

  /// Parse node from routing table JSON
  factory DiscoveredNode.fromMap(Map<String, dynamic> map) {
    return DiscoveredNode(
      address: map['address'] ?? '0x0000',
      via: map['via'] ?? '0xFFFF',
      metric: map['metric'] ?? 0,
      rssi: (map['rssi'] as num?)?.toInt() ?? 0,
      snr: (map['snr'] as num?)?.toDouble() ?? 0.0,
      role: (map['role'] as num?)?.toInt() ?? 0,
      lastSeen: (map['last_seen'] as num?)?.toInt(),
    );
  }

  /// Get signal strength indicator (0-4 bars)
  int getSignalBars() {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    if (rssi >= -90) return 1;
    return 0;
  }

  /// Get signal quality description
  String getSignalQuality() {
    if (rssi >= -60) return 'Excellent';
    if (rssi >= -70) return 'Good';
    if (rssi >= -80) return 'Fair';
    if (rssi >= -90) return 'Weak';
    return 'Poor';
  }

  /// Get connection type description
  String getConnectionType() {
    if (metric == 1) return 'Direct (1-hop)';
    return 'Indirect ($metric-hops)';
  }

  @override
  String toString() {
    return 'DiscoveredNode(address=$address, rssi=$rssi dBm, snr=$snr dB, '
        'metric=$metric, quality=${getSignalQuality()})';
  }
}
