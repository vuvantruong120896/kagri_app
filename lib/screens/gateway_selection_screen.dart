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
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      // Load gateways from Firebase
      final gatewaysPath = 'users/${user.uid}/gateways';
      final snapshot = await _database.child(gatewaysPath).get();

      if (!snapshot.exists) {
        setState(() {
          _gateways = [];
          _isLoading = false;
        });
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final gateways = <GatewayInfo>[];

      for (final entry in data.entries) {
        final gatewayData = Map<String, dynamic>.from(entry.value as Map);
        gateways.add(GatewayInfo.fromMap(entry.key, gatewayData));
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
        builder: (context) => ProvisioningProgressScreen(
          gateway: gateway,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Gateway'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGateways,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGateways,
              child: const Text('Retry'),
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
              'No Gateways Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please add a Gateway first',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Gateway'),
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
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOnline ? Colors.green : Colors.grey,
          child: Icon(
            isOnline ? Icons.router : Icons.router_outlined,
            color: Colors.white,
          ),
        ),
        title: Text(
          gateway.name ?? gateway.mac,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MAC: ${gateway.mac}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: isOnline ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: isOnline ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  lastSeenText,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            if (gateway.nodeCount != null && gateway.nodeCount! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${gateway.nodeCount} nodes connected',
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: isOnline ? () => _startProvisioning(gateway) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Provision'),
        ),
        isThreeLine: true,
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

  bool get isOnline {
    if (online != null) return online!;
    if (lastSeen == null) return false;

    // Consider online if last seen within 2 minutes
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSeen!) < 120000; // 2 minutes
  }

  String get lastSeenFormatted {
    if (lastSeen == null) return 'Never';

    final now = DateTime.now();
    final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen!);
    final difference = now.difference(lastSeenDate);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
