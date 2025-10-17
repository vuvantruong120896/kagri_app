/// Routing table node model matching Firebase schema
/// From firmware: gateways/{gatewayId}/routing_table/nodes/{nodeId}
class RouteNode {
  final String address; // Node address in hex format (e.g., "0xCC64")
  final String via; // Route via this address (same as address if direct)
  final int metric; // Hop count (1=direct, 2=via 1 hop, etc.)
  final int role; // Node role (1=node, other values reserved)
  final int? rssi; // Only present for direct connections (metric=1)
  final double? snr; // Only present for direct connections (metric=1)

  RouteNode({
    required this.address,
    required this.via,
    required this.metric,
    required this.role,
    this.rssi,
    this.snr,
  });

  /// Create from Firebase Realtime Database JSON
  factory RouteNode.fromJson(Map<String, dynamic> json, {String? address}) {
    return RouteNode(
      address: address ?? json['address'] ?? '',
      via: json['via'] ?? '',
      metric: json['metric'] ?? 0,
      role: json['role'] ?? 1,
      rssi: json['rssi'],
      snr: json['snr']?.toDouble(),
    );
  }

  /// Convert to Firebase Realtime Database JSON format
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'address': address,
      'via': via,
      'metric': metric,
      'role': role,
    };

    // Optional fields - only include if not null
    if (rssi != null) json['rssi'] = rssi!;
    if (snr != null) json['snr'] = snr!;

    return json;
  }

  /// Check if this is a direct connection
  bool get isDirect => metric == 1 && via == address;

  /// Human-readable hop count
  String get hopCountText {
    if (metric == 1) return 'Direct';
    return '$metric hops';
  }

  @override
  String toString() {
    return 'RouteNode(address: $address, via: $via, metric: $metric, isDirect: $isDirect)';
  }
}

/// Routing table model matching Firebase schema
/// From firmware: gateways/{gatewayId}/routing_table
class RoutingTable {
  final int nodeCount;
  final DateTime timestamp;
  final Map<String, RouteNode> nodes;

  RoutingTable({
    required this.nodeCount,
    required this.timestamp,
    required this.nodes,
  });

  /// Create from Firebase Realtime Database JSON
  factory RoutingTable.fromJson(Map<String, dynamic> json) {
    final nodesMap = <String, RouteNode>{};

    if (json['nodes'] != null) {
      final nodesData = Map<String, dynamic>.from(json['nodes'] as Map);
      nodesData.forEach((nodeId, nodeData) {
        if (nodeData is Map) {
          final nodeMap = Map<String, dynamic>.from(nodeData);
          nodesMap[nodeId] = RouteNode.fromJson(nodeMap, address: nodeId);
        }
      });
    }

    return RoutingTable(
      nodeCount: json['node_count'] ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['timestamp'] is int
                  ? json['timestamp'] * 1000
                  : int.parse(json['timestamp'].toString()) * 1000,
            )
          : DateTime.now(),
      nodes: nodesMap,
    );
  }

  /// Convert to Firebase Realtime Database JSON format
  Map<String, dynamic> toJson() {
    final nodesJson = <String, dynamic>{};
    nodes.forEach((key, value) {
      nodesJson[key] = value.toJson();
    });

    return {
      'node_count': nodeCount,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'nodes': nodesJson,
    };
  }

  /// Get all direct connections
  List<RouteNode> get directConnections {
    return nodes.values.where((node) => node.isDirect).toList();
  }

  /// Get nodes by hop count
  List<RouteNode> getNodesByMetric(int metric) {
    return nodes.values.where((node) => node.metric == metric).toList();
  }

  @override
  String toString() {
    return 'RoutingTable(nodeCount: $nodeCount, timestamp: $timestamp)';
  }
}
