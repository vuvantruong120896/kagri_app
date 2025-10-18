import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'provisioning_progress_screen.dart';

/// Screen to select Gateway for provisioning nodes
class GatewaySelectionScreen extends StatefulWidget {
  const GatewaySelectionScreen({super.key});

  @override
  State<GatewaySelectionScreen> createState() => _GatewaySelectionScreenState();
}

class _GatewaySelectionScreenState extends State<GatewaySelectionScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<GatewayInfo> _gateways = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGateways();
  }

  Future<void> _loadGateways() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Chưa đăng nhập';
          _isLoading = false;
        });
        return;
      }

      // Load gateways from Firebase - path: nodes/{userUID}/{gatewayMAC}/{nodeId}/
      final nodesPath = 'nodes/${user.uid}';
      final snapshot = await _database.child(nodesPath).get();

      if (!snapshot.exists) {
        setState(() {
          _gateways = [];
          _isLoading = false;
        });
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final gateways = <GatewayInfo>[];

      print('🔍 [Gateway Selection] Loading gateways from: nodes/${user.uid}');
      print('🔍 [Gateway Selection] Data keys: ${data.keys.toList()}');

      // Iterate through gateway MACs (first level under nodes/{userUID})
      for (final gatewayEntry in data.entries) {
        final gatewayMAC = gatewayEntry.key;
        final gatewayData = gatewayEntry.value;

        print('🔍 [Gateway Selection] Processing gatewayMAC: $gatewayMAC');

        if (gatewayData is Map) {
          final gatewayMap = Map<String, dynamic>.from(gatewayData);

          // Look for gateway device (usually has same MAC as nodeId or isGateway flag)
          Map<String, dynamic>? gatewayInfo;
          int nodeCount = 0;
          int? latestTimestamp;

          // Count nodes and find gateway device info
          for (final nodeEntry in gatewayMap.entries) {
            final nodeId = nodeEntry.key;
            final nodeData = nodeEntry.value;

            if (nodeData is Map) {
              final nodeMap = Map<String, dynamic>.from(nodeData);
              nodeCount++;

              // Check if this is the gateway device
              final info = nodeMap['info'];
              if (info is Map) {
                final infoMap = Map<String, dynamic>.from(info);
                final isGateway =
                    infoMap['isGateway'] == true ||
                    nodeId.toUpperCase() == gatewayMAC.toUpperCase();

                if (isGateway) {
                  gatewayInfo = infoMap;
                  // Use lastSeen from gateway info if available
                  final infoLastSeen = infoMap['lastSeen'] as int?;
                  if (infoLastSeen != null) {
                    latestTimestamp = infoLastSeen;
                  }
                }
              }

              // Track latest timestamp from latest_data (only if gateway lastSeen not found)
              if (latestTimestamp == null) {
                final latestData = nodeMap['latest_data'];
                if (latestData is Map) {
                  final latestMap = Map<String, dynamic>.from(latestData);
                  final timestamp = latestMap['timestamp'] as int?;
                  if (timestamp != null) {
                    if (latestTimestamp == null ||
                        timestamp > latestTimestamp) {
                      latestTimestamp = timestamp;
                    }
                  }
                }
              }
            }
          }

          // Create gateway info from collected data
          final gateway = GatewayInfo(
            mac: gatewayMAC,
            name: gatewayInfo?['name'] as String?,
            lastSeen: latestTimestamp,
            online: gatewayInfo?['online'] as bool?,
            nodeCount: nodeCount,
            status: gatewayInfo,
          );

          print('📊 [Gateway Selection] Gateway created:');
          print('   MAC: $gatewayMAC');
          print('   Name: ${gateway.name}');
          print('   LastSeen: $latestTimestamp');
          print('   Online flag: ${gatewayInfo?['online']}');
          print('   NodeCount: $nodeCount');
          print('   IsOnline: ${gateway.isOnline}');

          gateways.add(gateway);
        }
      }

      // Sort by last seen (most recent first)
      gateways.sort((a, b) => (b.lastSeen ?? 0).compareTo(a.lastSeen ?? 0));

      setState(() {
        _gateways = gateways;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startProvisioning(GatewayInfo gateway) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProvisioningProgressScreen(gateway: gateway),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn Gateway'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadGateways),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Lỗi: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGateways,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_gateways.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.router_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Không tìm thấy Gateway',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vui lòng thêm Gateway trước',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add),
              label: const Text('Thêm Gateway'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _gateways.length,
      itemBuilder: (context, index) {
        final gateway = _gateways[index];
        return _buildGatewayCard(gateway);
      },
    );
  }

  Widget _buildGatewayCard(GatewayInfo gateway) {
    final isOnline = gateway.isOnline;
    final lastSeenText = gateway.lastSeenFormatted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon, Name, Status
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isOnline ? Colors.green : Colors.grey,
                  child: Icon(
                    isOnline ? Icons.router : Icons.router_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gateway.name ?? 'Gateway',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isOnline ? Icons.wifi : Icons.wifi_off,
                            size: 14,
                            color: isOnline ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: isOnline ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: isOnline
                      ? () => _startProvisioning(gateway)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cấu hình'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Details: MAC, Last seen, Node count
            Row(
              children: [
                const Icon(Icons.badge, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'MAC: ${gateway.mac}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  lastSeenText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            if (gateway.nodeCount != null && gateway.nodeCount! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.devices, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '${gateway.nodeCount} Node${gateway.nodeCount! > 1 ? 's' : ''} đã kết nối',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Gateway information model
class GatewayInfo {
  final String mac;
  final String? name;
  final int? lastSeen;
  final bool? online;
  final int? nodeCount;
  final Map<String, dynamic>? status;

  GatewayInfo({
    required this.mac,
    this.name,
    this.lastSeen,
    this.online,
    this.nodeCount,
    this.status,
  });

  factory GatewayInfo.fromMap(String mac, Map<String, dynamic> map) {
    return GatewayInfo(
      mac: mac,
      name: map['name'] as String?,
      lastSeen: map['lastSeen'] as int?,
      online: map['online'] as bool?,
      nodeCount: map['nodeCount'] as int?,
      status: map['status'] != null
          ? Map<String, dynamic>.from(map['status'] as Map)
          : null,
    );
  }

  // Helper to convert timestamp to milliseconds (handles both seconds and milliseconds)
  int? get _lastSeenMillis {
    if (lastSeen == null) return null;

    // If timestamp is less than year 2000 in milliseconds (946684800000),
    // it's likely in seconds, so convert to milliseconds
    if (lastSeen! < 946684800000) {
      return lastSeen! * 1000;
    }
    return lastSeen;
  }

  bool get isOnline {
    // If online flag is explicitly set, use it
    if (online != null) return online!;

    // If we have recent lastSeen data, consider online
    if (_lastSeenMillis != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Consider online if last seen within 5 minutes
      return (now - _lastSeenMillis!) < 300000; // 5 minutes
    }

    // If no lastSeen data but nodeCount > 0, assume online
    // (Gateway must be online to have connected nodes)
    if (nodeCount != null && nodeCount! > 0) {
      return true;
    }

    return false;
  }

  String get lastSeenFormatted {
    if (_lastSeenMillis == null) return 'Chưa xem';

    final now = DateTime.now();
    final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(_lastSeenMillis!);
    final difference = now.difference(lastSeenDate);

    if (difference.inSeconds < 60) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}p trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h trước';
    } else {
      return '${difference.inDays}d trước';
    }
  }
}
