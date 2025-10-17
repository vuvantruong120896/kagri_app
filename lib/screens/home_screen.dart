import 'package:flutter/material.dart';
import 'dart:async';
import '../models/sensor_data.dart';
import '../models/device.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import 'network_status_screen.dart';
import 'device_chart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();
  String? _selectedNodeId; // Changed from _selectedDeviceId to _selectedNodeId
  // Current list of gateway IDs (from Firebase gateways/)
  Set<String> _gatewayIds = <String>{};
  StreamSubscription<List<String>>? _gatewaySub;

  @override
  void initState() {
    super.initState();
    // Listen for gateways so we can mark devices that are actually gateways
    _gatewaySub = _dataService.getGatewaysStream().listen(
      (list) {
        setState(() {
          _gatewayIds = list.toSet();
        });
      },
      onError: (_) {
        // ignore gateway errors, leave set empty
      },
    );
  }

  @override
  void dispose() {
    _gatewaySub?.cancel();
    super.dispose();
  }

  String _displayName(Device device) {
    return _gatewayIds.contains(device.nodeId) ? 'Gateway' : device.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('KAGRI'),
            Text(
              'Nguồn: ${_dataService.dataSourceInfo}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _dataService.useMockData ? Icons.cloud_off : Icons.cloud,
            ),
            onPressed: () {
              setState(() {
                _dataService.setUseMockData(!_dataService.useMockData);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Chuyển sang ${_dataService.dataSourceInfo}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: _dataService.useMockData
                ? 'Chuyển sang Firebase'
                : 'Chuyển sang Mock Data',
          ),
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
            tooltip: 'Routing Table & Gateway Status',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {}); // Trigger rebuild to refresh data
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sensors_off, size: 64, color: Colors.grey),
                        const SizedBox(height: AppSizes.paddingMedium),
                        Text(
                          'Không có thiết bị',
                          style: AppTextStyles.heading2,
                        ),
                        const SizedBox(height: AppSizes.paddingSmall),
                        Text(
                          _dataService.useMockData
                              ? 'Đang dùng mock data nhưng chưa có devices'
                              : 'Chưa có node nào trong Firebase.\nKiểm tra gateway đã push routing_table chưa.',
                          style: AppTextStyles.body2,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
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
                    Icons.router,
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
                        Text(
                          _displayName(device),
                          style: AppTextStyles.heading3,
                        ),
                        Text(
                          'Node ID: ${device.nodeId}',
                          style: AppTextStyles.caption,
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
                  Icons.router,
                  color: device.isOnline ? AppColors.online : AppColors.offline,
                ),
                title: Text(_displayName(device)),
                subtitle: Text('Node ID: ${device.nodeId}'),
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
      await _dataService.updateNodeInfo(device.nodeId, {'name': newName});

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
}
