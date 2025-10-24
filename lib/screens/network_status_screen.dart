import 'package:flutter/material.dart';
import '../models/routing_table.dart';
import '../models/gateway_status.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';

class NetworkStatusScreen extends StatefulWidget {
  const NetworkStatusScreen({super.key});

  @override
  State<NetworkStatusScreen> createState() => _NetworkStatusScreenState();
}

class _NetworkStatusScreenState extends State<NetworkStatusScreen> {
  final DataService _dataService = DataService();
  String? _selectedGatewayId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trạng thái mạng LoRa Mesh'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Gateway selector
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingMedium),
            color: AppColors.primary.withValues(alpha: 0.1),
            child: StreamBuilder<List<String>>(
              stream: _dataService.getGatewaysStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final gateways = snapshot.data!;
                if (gateways.isEmpty) {
                  return const Text('Không có gateway nào');
                }

                // Auto-select first gateway
                if (_selectedGatewayId == null && gateways.isNotEmpty) {
                  _selectedGatewayId = gateways.first;
                }

                return Row(
                  children: [
                    const Icon(Icons.router, color: AppColors.primary),
                    const SizedBox(width: AppSizes.paddingSmall),
                    const Text('Gateway:', style: AppTextStyles.body1),
                    const SizedBox(width: AppSizes.paddingSmall),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedGatewayId,
                        isExpanded: true,
                        items: gateways.map((gatewayId) {
                          return DropdownMenuItem<String>(
                            value: gatewayId,
                            child: Text(gatewayId),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGatewayId = value;
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Gateway Status
          if (_selectedGatewayId != null)
            StreamBuilder<GatewayStatus?>(
              stream: _dataService.getGatewayStatusStream(_selectedGatewayId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return const SizedBox.shrink();
                }

                final status = snapshot.data!;
                return Card(
                  margin: const EdgeInsets.all(AppSizes.marginMedium),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              status.isHealthy
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: status.isHealthy
                                  ? AppColors.online
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Gateway Status',
                              style: AppTextStyles.heading3,
                            ),
                          ],
                        ),
                        const Divider(),
                        _buildStatusRow(
                          'Connected Nodes',
                          '${status.connectedNodes}',
                        ),
                        _buildStatusRow(
                          'Packets Received',
                          '${status.totalPacketsReceived}',
                        ),
                        _buildStatusRow(
                          'Packets Sent',
                          '${status.totalPacketsSent}',
                        ),
                        _buildStatusRow(
                          'WiFi',
                          status.wifiConnected ? 'Connected' : 'Disconnected',
                        ),
                        _buildStatusRow('WiFi RSSI', '${status.wifiRssi} dBm'),
                        _buildStatusRow(
                          'Firebase',
                          status.firebaseConnected
                              ? 'Connected'
                              : 'Disconnected',
                        ),
                        _buildStatusRow('Uptime', status.uptimeText),
                        _buildStatusRow(
                          'Free Heap',
                          '${status.freeHeapKB.toStringAsFixed(2)} KB',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Routing Table
          if (_selectedGatewayId != null)
            Expanded(
              child: StreamBuilder<RoutingTable?>(
                stream: _dataService.getRoutingTableStream(_selectedGatewayId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.device_hub, size: 64, color: Colors.grey),
                          SizedBox(height: AppSizes.paddingMedium),
                          Text(
                            'Không có routing table',
                            style: AppTextStyles.heading2,
                          ),
                        ],
                      ),
                    );
                  }

                  final routingTable = snapshot.data!;
                  final nodes = routingTable.nodes.values.toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSizes.paddingMedium),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.device_hub,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Routing Table (${routingTable.nodeCount} nodes)',
                              style: AppTextStyles.heading3,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: nodes.length,
                          itemBuilder: (context, index) {
                            final node = nodes[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: AppSizes.marginMedium,
                                vertical: AppSizes.marginSmall,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  node.isDirect
                                      ? Icons.cell_tower
                                      : Icons.router,
                                  color: node.isDirect
                                      ? AppColors.online
                                      : AppColors.warning,
                                ),
                                title: Text(
                                  node.address,
                                  style: AppTextStyles.heading3,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Via: ${node.via}'),
                                    Text('Metric: ${node.hopCountText}'),
                                    if (node.rssi != null)
                                      Text('RSSI: ${node.rssi} dBm'),
                                    if (node.snr != null)
                                      Text(
                                        'SNR: ${node.snr!.toStringAsFixed(1)} dB',
                                      ),
                                  ],
                                ),
                                trailing: Chip(
                                  label: Text(
                                    node.isDirect
                                        ? 'Direct'
                                        : '${node.metric} hops',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: node.isDirect
                                      ? AppColors.online.withValues(alpha: 0.2)
                                      : AppColors.warning.withValues(
                                          alpha: 0.2,
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body2),
          Text(value, style: AppTextStyles.body1),
        ],
      ),
    );
  }
}
