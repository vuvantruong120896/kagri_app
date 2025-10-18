import 'package:flutter/material.dart';
import 'dart:async';
import '../models/sensor_data.dart';
import '../models/device.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import 'network_status_screen.dart';
import 'provisioning_screen.dart';
import 'gateway_selection_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'device_chart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  String? _selectedNodeId; // Changed from _selectedDeviceId to _selectedNodeId
  bool _justProvisioned = false; // Track if just finished provisioning
  Timer? _provisioningTimeoutTimer;
  late AnimationController _syncAnimationController;

  @override
  void initState() {
    super.initState();
    _syncAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // Repeat infinitely without rebuild
  }

  @override
  void dispose() {
    _provisioningTimeoutTimer?.cancel();
    _syncAnimationController.dispose();
    super.dispose();
  }

  String _displayName(Device device) {
    return device.displayName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KAGRI'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.device_hub),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NetworkStatusScreen(),
                ),
              );
            },
            tooltip: 'Network Status',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddDeviceOptions(context);
            },
            tooltip: 'Thêm Thiết bị',
          ),
          // Logout button
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) async {
              if (value == 'logout') {
                // Show confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await AuthService().signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                }
              } else if (value == 'settings') {
                // Navigate to Settings screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              } else if (value == 'profile') {
                // TODO: Navigate to profile screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile screen coming soon')),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person),
                    const SizedBox(width: 12),
                    Text(AuthService().currentUser?.email ?? 'User'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 12),
                    Text('Cài đặt'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            tooltip: 'Routing Table & Gateway Status',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {}); // Trigger rebuild to refresh data
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Device filter dropdown
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingMedium),
            color: AppColors.primary.withValues(alpha: 0.1),
            child: StreamBuilder<List<Device>>(
              stream: _dataService.getDevicesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final devices = snapshot.data!;
                return Row(
                  children: [
                    const Icon(Icons.filter_list, color: AppColors.primary),
                    const SizedBox(width: AppSizes.paddingSmall),
                    const Text('Thiết bị:', style: AppTextStyles.body1),
                    const SizedBox(width: AppSizes.paddingSmall),
                    Expanded(
                      child: DropdownButton<String?>(
                        value: _selectedNodeId,
                        isExpanded: true,
                        hint: const Text('Tất cả thiết bị'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tất cả thiết bị'),
                          ),
                          ...devices.map(
                            (device) => DropdownMenuItem<String?>(
                              value: device.nodeId,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 12,
                                    color: device.isOnline
                                        ? AppColors.online
                                        : AppColors.offline,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${_displayName(device)} (${device.nodeId})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedNodeId = value;
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Statistics summary
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingMedium),
            child: StreamBuilder<List<Device>>(
              stream: _dataService.getDevicesStream(),
              builder: (context, devSnapshot) {
                if (!devSnapshot.hasData || devSnapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }

                final devices = devSnapshot.data!;
                final onlineCount = devices.where((d) => d.isOnline).length;
                final totalCount = devices.length;

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Tổng số Node',
                        '$totalCount',
                        'Online: $onlineCount',
                        Icons.router,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingMedium),
                    Expanded(
                      child: _buildStatCard(
                        'Trạng thái',
                        onlineCount > 0 ? 'Hoạt động' : 'Offline',
                        '$onlineCount/$totalCount online',
                        Icons.signal_cellular_alt,
                        onlineCount > 0 ? AppColors.online : AppColors.offline,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Device/Node list with latest data
          Expanded(
            child: StreamBuilder<List<Device>>(
              stream: _dataService.getDevicesStream(),
              builder: (context, snapshot) {
                // Show loading only on first connection (no data yet)
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSizes.paddingMedium),
                        Text(
                          'Đang kết nối Firebase...',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.danger,
                        ),
                        const SizedBox(height: AppSizes.paddingMedium),
                        Text(
                          'Lỗi kết nối Firebase',
                          style: AppTextStyles.heading2,
                        ),
                        const SizedBox(height: AppSizes.paddingSmall),
                        Text(
                          snapshot.error.toString(),
                          style: AppTextStyles.body2,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSizes.paddingMedium),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Retry
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  // Only show syncing UI if just provisioned
                  if (_justProvisioned) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated syncing icon (smooth rotation without rebuild)
                          AnimatedBuilder(
                            animation: _syncAnimationController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle:
                                    _syncAnimationController.value *
                                    2 *
                                    3.14159,
                                child: child,
                              );
                            },
                            child: Icon(
                              Icons.sync,
                              size: 64,
                              color: Colors.blue.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: AppSizes.paddingMedium),
                          Text(
                            'Đang đồng bộ dữ liệu',
                            style: AppTextStyles.heading2.copyWith(
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(height: AppSizes.paddingSmall),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Gateway đang khởi động và kết nối với máy chủ.\nVui lòng đợi trong giây lát...',
                              style: AppTextStyles.body2.copyWith(
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: AppSizes.paddingMedium),
                          // Loading indicator
                          SizedBox(
                            width: 200,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.paddingSmall),
                          Text(
                            'Timeout sau 10 giây...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Normal empty state - no devices yet
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sensors_off,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: AppSizes.paddingLarge),
                          Text(
                            'Chưa có thiết bị',
                            style: AppTextStyles.heading1.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: AppSizes.paddingSmall),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Bắt đầu bằng cách thêm Gateway hoặc Node vào hệ thống của bạn',
                              style: AppTextStyles.body1.copyWith(
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: AppSizes.paddingLarge),
                          ElevatedButton.icon(
                            onPressed: () {
                              _showAddDeviceOptions(context);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm thiết bị'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.paddingMedium),
                          TextButton.icon(
                            onPressed: () {
                              // Show help or guide
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Row(
                                    children: [
                                      Icon(Icons.help_outline, color: AppColors.primary),
                                      SizedBox(width: 8),
                                      Text('Hướng dẫn'),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Có 2 cách thêm thiết bị:',
                                        style: AppTextStyles.heading3,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildHelpItem(
                                        Icons.router,
                                        'Gateway (BLE)',
                                        'Kết nối trực tiếp qua Bluetooth để provisioning WiFi và Firebase',
                                      ),
                                      const SizedBox(height: 12),
                                      _buildHelpItem(
                                        Icons.sensors,
                                        'Node (qua Gateway)',
                                        'Sử dụng Gateway đã có để provisioning nhiều Node từ xa qua Firebase',
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Đóng'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showAddDeviceOptions(context);
                                      },
                                      child: const Text('Thêm ngay'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.help_outline),
                            label: const Text('Cách thêm thiết bị?'),
                          ),
                        ],
                      ),
                    );
                  }
                }

                // Data exists - cancel timeout and clear provisioning flag
                if (_justProvisioned) {
                  // Cancel timeout when data arrives
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _provisioningTimeoutTimer?.cancel();
                    if (mounted) {
                      setState(() {
                        _justProvisioned = false;
                      });
                    }
                  });
                }

                var devices = snapshot.data!;

                // Filter by selected node if any
                if (_selectedNodeId != null) {
                  devices = devices
                      .where((d) => d.nodeId == _selectedNodeId)
                      .toList();
                }

                if (devices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_alt_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: AppSizes.paddingMedium),
                        Text(
                          'Không tìm thấy node',
                          style: AppTextStyles.heading2,
                        ),
                        const SizedBox(height: AppSizes.paddingSmall),
                        Text(
                          'Node được chọn không có dữ liệu',
                          style: AppTextStyles.body2,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {}); // Trigger rebuild
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSizes.paddingMedium),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return _buildDeviceCard(context, device);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<List<Device>>(
        stream: _dataService.getDevicesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }

          final devices = snapshot.data!;

          return FloatingActionButton(
            onPressed: () {
              if (devices.length == 1) {
                // Nếu chỉ có 1 device, mở trực tiếp
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DeviceChartScreen(device: devices.first),
                  ),
                );
              } else {
                // Nếu có nhiều devices, hiển thị dialog chọn
                _showChartDeviceSelector(context, devices);
              }
            },
            backgroundColor: AppColors.accent,
            child: const Icon(Icons.analytics),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingMedium),
        child: Column(
          children: [
            Icon(icon, color: color, size: AppSizes.iconLarge),
            const SizedBox(height: AppSizes.paddingSmall),
            Text(value, style: AppTextStyles.heading2.copyWith(color: color)),
            Text(
              title,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, Device device) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingMedium),
      elevation: 2,
      child: InkWell(
        onTap: () => _showDeviceDetails(context, device),
        onLongPress: () => _showDeviceOptionsMenu(context, device),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Device name and status
              Row(
                children: [
                  Icon(
                    device.isGateway ? Icons.router : Icons.sensors,
                    color: device.isOnline
                        ? AppColors.online
                        : AppColors.offline,
                    size: 32,
                  ),
                  const SizedBox(width: AppSizes.paddingSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                device.displayName,
                                style: AppTextStyles.heading3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (device.isGateway) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'GW',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          device.isGateway
                              ? 'MAC: ${device.gatewayMAC ?? device.nodeId}'
                              : 'Node: ${device.nodeId}',
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: device.isOnline
                              ? AppColors.online.withValues(alpha: 0.2)
                              : AppColors.offline.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          device.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: device.isOnline
                                ? AppColors.online
                                : AppColors.offline,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(device.lastSeenText, style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),

              const Divider(height: 24),

              // Latest sensor data
              StreamBuilder<List<SensorData>>(
                stream: _dataService.getSensorDataStream(nodeId: device.nodeId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Chưa có dữ liệu sensor',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }

                  final latestData = snapshot.data!.first;

                  return Column(
                    children: [
                      // Temperature and Humidity
                      Row(
                        children: [
                          Expanded(
                            child: _buildSensorValue(
                              Icons.thermostat,
                              'Nhiệt độ',
                              '${latestData.temperature.toStringAsFixed(1)}°C',
                              AppColors.temperatureNormal,
                            ),
                          ),
                          const SizedBox(width: AppSizes.paddingMedium),
                          Expanded(
                            child: _buildSensorValue(
                              Icons.water_drop,
                              'Độ ẩm',
                              '${latestData.humidity.toStringAsFixed(1)}%',
                              AppColors.humidityNormal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingSmall),
                      // Battery and Signal
                      Row(
                        children: [
                          Expanded(
                            child: _buildSensorValue(
                              latestData.isBatteryLow
                                  ? Icons.battery_alert
                                  : Icons.battery_full,
                              'Pin',
                              '${latestData.battery.toStringAsFixed(2)}V (${latestData.batteryPercentage.toStringAsFixed(0)}%)',
                              latestData.isBatteryLow
                                  ? AppColors.danger
                                  : AppColors.online,
                            ),
                          ),
                          if (latestData.rssi != null) ...[
                            const SizedBox(width: AppSizes.paddingMedium),
                            Expanded(
                              child: _buildSensorValue(
                                Icons.signal_cellular_alt,
                                'RSSI',
                                '${latestData.rssi} dBm',
                                latestData.isSignalWeak
                                    ? AppColors.danger
                                    : AppColors.online,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingSmall),
                      // Counter and timestamp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Counter: ${latestData.counter}',
                            style: AppTextStyles.caption,
                          ),
                          Text(
                            DateFormat('HH:mm:ss').format(latestData.timestamp),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorValue(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
                Text(
                  value,
                  style: AppTextStyles.body2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetails(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.router,
                    color: device.isOnline
                        ? AppColors.online
                        : AppColors.offline,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName(device),
                          style: AppTextStyles.heading2,
                        ),
                        Text(
                          'Node ID: ${device.nodeId}',
                          style: AppTextStyles.body2,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Node Info Section
              Text('Thông tin Node', style: AppTextStyles.heading3),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildDetailRow('Loại:', device.type),
                      _buildDetailRow(
                        'Trạng thái:',
                        device.isOnline ? '🟢 Online' : '🔴 Offline',
                      ),
                      _buildDetailRow('Lần cuối:', device.lastSeenText),
                      _buildDetailRow(
                        'Tạo lúc:',
                        DateFormat('dd/MM/yyyy HH:mm').format(device.createdAt),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Historical Data Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lịch sử dữ liệu', style: AppTextStyles.heading3),
                  StreamBuilder<List<SensorData>>(
                    stream: _dataService.getSensorDataStream(
                      nodeId: device.nodeId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          '${snapshot.data!.length} bản ghi',
                          style: AppTextStyles.caption,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Data List
              Expanded(
                child: StreamBuilder<List<SensorData>>(
                  stream: _dataService.getSensorDataStream(
                    nodeId: device.nodeId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text('Chưa có dữ liệu sensor'),
                          ],
                        ),
                      );
                    }

                    final dataList = snapshot.data!;

                    return ListView.builder(
                      itemCount: dataList.length,
                      itemBuilder: (context, index) {
                        final data = dataList[index];
                        final isLatest = index == 0;

                        return Card(
                          color: isLatest
                              ? AppColors.primary.withValues(alpha: 0.05)
                              : null,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            leading: Icon(
                              isLatest ? Icons.fiber_new : Icons.history,
                              color: isLatest ? AppColors.primary : Colors.grey,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    DateFormat(
                                      'dd/MM HH:mm:ss',
                                    ).format(data.timestamp),
                                    style: AppTextStyles.body1.copyWith(
                                      fontWeight: isLatest
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isLatest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'MỚI NHẤT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              'Counter: ${data.counter} | '
                              'Temp: ${data.temperature.toStringAsFixed(1)}°C | '
                              'Hum: ${data.humidity.toStringAsFixed(1)}%',
                              style: AppTextStyles.caption,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailValue(
                                            Icons.thermostat,
                                            'Nhiệt độ',
                                            '${data.temperature.toStringAsFixed(1)}°C',
                                            AppColors.temperatureNormal,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildDetailValue(
                                            Icons.water_drop,
                                            'Độ ẩm',
                                            '${data.humidity.toStringAsFixed(1)}%',
                                            AppColors.humidityNormal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailValue(
                                            data.isBatteryLow
                                                ? Icons.battery_alert
                                                : Icons.battery_full,
                                            'Pin',
                                            '${data.battery.toStringAsFixed(2)}V\n${data.batteryPercentage.toStringAsFixed(0)}%',
                                            data.isBatteryLow
                                                ? AppColors.danger
                                                : AppColors.online,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (data.rssi != null)
                                          Expanded(
                                            child: _buildDetailValue(
                                              Icons.signal_cellular_alt,
                                              'RSSI',
                                              '${data.rssi} dBm',
                                              data.isSignalWeak
                                                  ? AppColors.danger
                                                  : AppColors.online,
                                            ),
                                          )
                                        else
                                          const Expanded(child: SizedBox()),
                                      ],
                                    ),
                                    if (data.snr != null) ...[
                                      const SizedBox(height: 8),
                                      _buildDetailValue(
                                        Icons.network_check,
                                        'SNR',
                                        '${data.snr!.toStringAsFixed(1)} dB',
                                        AppColors.primary,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DeviceChartScreen(device: device),
                        ),
                      );
                    },
                    icon: const Icon(Icons.analytics),
                    label: const Text('Xem biểu đồ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailValue(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.body2.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value, style: AppTextStyles.body2)),
        ],
      ),
    );
  }

  void _showChartDeviceSelector(BuildContext context, List<Device> devices) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn Node để xem biểu đồ'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                leading: Icon(
                  device.isGateway ? Icons.router : Icons.sensors,
                  color: device.isOnline ? AppColors.online : AppColors.offline,
                ),
                title: Row(
                  children: [
                    Text(_displayName(device)),
                    const SizedBox(width: 8),
                    if (device.isGateway)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Gateway',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  device.isGateway
                      ? 'MAC: ${device.gatewayMAC ?? device.nodeId}'
                      : 'Node ID: ${device.nodeId}',
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceChartScreen(device: device),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  /// Show device options menu (rename + firmware update)
  void _showDeviceOptionsMenu(BuildContext context, Device device) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.router,
                  color: device.isOnline ? AppColors.online : AppColors.offline,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName(device), style: AppTextStyles.heading3),
                      Text(
                        'Node ID: ${device.nodeId}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // Option 1: Rename
            ListTile(
              leading: const Icon(
                Icons.edit,
                color: AppColors.primary,
                size: 28,
              ),
              title: const Text('Đổi tên thiết bị', style: AppTextStyles.body1),
              subtitle: const Text(
                'Thay đổi tên hiển thị',
                style: AppTextStyles.caption,
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, device);
              },
            ),

            const SizedBox(height: 8),

            // Option 2: Firmware Update
            ListTile(
              leading: const Icon(
                Icons.system_update,
                color: AppColors.accent,
                size: 28,
              ),
              title: const Text(
                'Cập nhật firmware',
                style: AppTextStyles.body1,
              ),
              subtitle: const Text(
                'Over-The-Air update',
                style: AppTextStyles.caption,
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _showFirmwareUpdatePlaceholder(context);
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Show rename device dialog
  void _showRenameDialog(BuildContext context, Device device) {
    final TextEditingController nameController = TextEditingController(
      text: device.name,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Đổi tên thiết bị'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Node ID: ${device.nodeId}', style: AppTextStyles.caption),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tên thiết bị',
                hintText: 'Nhập tên mới...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.router),
              ),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context);
                  _updateDeviceName(context, device, value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(context);
                _updateDeviceName(context, device, newName);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  /// Update device name in Firebase
  Future<void> _updateDeviceName(
    BuildContext context,
    Device device,
    String newName,
  ) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Đang cập nhật tên...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Update in Firebase
      await _dataService.updateNodeInfo(device.nodeId, {
        'name': newName,
      }, gatewayMAC: device.gatewayMAC);

      // Show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 16),
                Text('Đã đổi tên thành "$newName"'),
              ],
            ),
            backgroundColor: AppColors.online,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Trigger rebuild to show new name
      setState(() {});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 16),
                Text('Lỗi: ${e.toString()}'),
              ],
            ),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Show firmware update placeholder
  void _showFirmwareUpdatePlaceholder(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: AppColors.accent),
            const SizedBox(width: 8),
            const Text('Cập nhật Firmware'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Tính năng đang phát triển',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Over-The-Air (OTA) firmware update sẽ được hỗ trợ trong phiên bản tiếp theo.',
              style: AppTextStyles.body2,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  /// Show device type selection bottom sheet
  void _showAddDeviceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Chọn loại thiết bị',
                  style: AppTextStyles.heading2,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.router, color: AppColors.primary),
                title: const Text('Gateway (BLE)'),
                subtitle: const Text('Kết nối trực tiếp qua Bluetooth'),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet

                  // Navigate to BLE provisioning
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProvisioningScreen(),
                    ),
                  );

                  // If provision succeeded, start timeout timer and show syncing UI
                  if (result == true && mounted) {
                    setState(() {
                      _justProvisioned = true;
                    });

                    // Set 10 second timeout
                    _provisioningTimeoutTimer?.cancel();
                    _provisioningTimeoutTimer = Timer(
                      const Duration(seconds: 10),
                      () {
                        if (mounted) {
                          setState(() {
                            _justProvisioned = false;
                          });
                        }
                      },
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.sensors, color: AppColors.accent),
                title: const Text('Node (qua Gateway)'),
                subtitle: const Text('Provisioning từ xa qua Firebase'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet

                  // Navigate to gateway selection
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GatewaySelectionScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Build help item widget
  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.body2.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
