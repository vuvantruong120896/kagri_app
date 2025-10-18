import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';

class GatewayManagementScreen extends StatefulWidget {
  const GatewayManagementScreen({super.key});

  @override
  State<GatewayManagementScreen> createState() =>
      _GatewayManagementScreenState();
}

class _GatewayManagementScreenState extends State<GatewayManagementScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _gateways = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGateways();
  }

  Future<void> _loadGateways() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final snapshot = await _database.child('gateways').child(user.uid).get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> gateways = [];

        for (var entry in data.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is Map) {
            // Check if gateway is online based on status subcollection
            bool isOnline = false;
            try {
              if (value['status'] != null && value['status'] is Map) {
                final status = value['status'] as Map;

                // Check firebase_connected flag
                final firebaseConnected = status['firebase_connected'];
                if (firebaseConnected == true) {
                  // Verify timestamp is recent (within 3 minutes)
                  final timestamp = status['timestamp'];
                  if (timestamp != null) {
                    final lastUpdate = DateTime.fromMillisecondsSinceEpoch(
                      (timestamp is int
                              ? timestamp
                              : int.parse(timestamp.toString())) *
                          1000,
                    );
                    final now = DateTime.now();
                    final diffMinutes = now.difference(lastUpdate).inMinutes;

                    // Consider online if status is recent (< 3 minutes)
                    // Gateway uploads status every 60 seconds
                    isOnline = diffMinutes < 3;
                  }
                }
              }
            } catch (e) {
              // Error checking status, default to offline
              isOnline = false;
            }

            gateways.add({
              'macAddress': key,
              'wifiSSID': value['wifiSSID'] ?? 'N/A',
              'name': value['name'] ?? 'Gateway $key',
              'status': isOnline ? 'online' : 'offline',
            });
          }
        }

        setState(() {
          _gateways = gateways;
          _isLoading = false;
        });
      } else {
        setState(() {
          _gateways = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Gateway'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _gateways.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadGateways,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _gateways.length,
                itemBuilder: (context, index) {
                  final gateway = _gateways[index];
                  return _buildGatewayCard(gateway);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.router_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có Gateway nào',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy thêm Gateway từ màn hình chính',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildGatewayCard(Map<String, dynamic> gateway) {
    final status = gateway['status'] as String;
    final isOnline = status.toLowerCase() == 'online';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showGatewayOptions(gateway),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.router, color: AppColors.primary, size: 32),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gateway['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MAC: ${gateway['macAddress']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'WiFi: ${gateway['wifiSSID']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGatewayOptions(Map<String, dynamic> gateway) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Đổi tên'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(gateway);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Xóa Gateway',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(gateway);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(Map<String, dynamic> gateway) {
    final controller = TextEditingController(text: gateway['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên Gateway'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tên mới',
            hintText: 'Nhập tên Gateway',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await _renameGateway(gateway['macAddress'], newName);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> gateway) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa Gateway "${gateway['name']}"?\n\nThao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              await _deleteGateway(gateway['macAddress']);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameGateway(String macAddress, String newName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _database
          .child('gateways')
          .child(user.uid)
          .child(macAddress)
          .update({'name': newName});

      await _loadGateways();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đổi tên Gateway'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _deleteGateway(String macAddress) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _database
          .child('gateways')
          .child(user.uid)
          .child(macAddress)
          .remove();

      await _loadGateways();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa Gateway'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }
}
