import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_constants.dart';
import '../services/ble_provisioning_service.dart';
import '../services/firebase_service.dart';

/// Device Discovery Screen
///
/// Scans for Kagri Gateway and Node devices via BLE
/// Displays discovered devices with type indicator
/// Navigates to appropriate provisioning screen
///
/// Updated: November 2025

class DeviceDiscoveryScreen extends StatefulWidget {
  final DeviceType? initialFilterType;

  const DeviceDiscoveryScreen({super.key, this.initialFilterType});

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  final BleProvisioningService _bleService = BleProvisioningService();
  final FirebaseService _firebaseService = FirebaseService();

  final List<ScanResult> _discoveredDevices = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;
  DeviceType? _filterType; // null = show all

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();

    // Set initial filter if provided
    _filterType = widget.initialFilterType;

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _checkBluetoothAndStartScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _radarController.dispose();
    _bleService.stopScan();
    super.dispose();
  }

  // ============================================================================
  // BLUETOOTH & SCANNING
  // ============================================================================

  Future<void> _checkBluetoothAndStartScan() async {
    if (!await _bleService.isBluetoothReady()) {
      if (!mounted) return;

      _showBluetoothNotReadyDialog();
      return;
    }

    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    print(
      '[DeviceDiscovery] Starting scan with filter: ${_filterType?.displayName ?? 'all'}',
    );

    try {
      await _scanSubscription?.cancel();

      _scanSubscription = _bleService
          .scanDevices(
            timeout: Duration(seconds: BleConstants.scanTimeoutSeconds),
            filterType: _filterType,
          )
          .listen(
            (results) {
              setState(() {
                // Update devices, avoiding duplicates
                for (final result in results) {
                  final existingIndex = _discoveredDevices.indexWhere(
                    (d) => d.device.remoteId == result.device.remoteId,
                  );

                  if (existingIndex >= 0) {
                    _discoveredDevices[existingIndex] = result;
                  } else {
                    _discoveredDevices.add(result);
                  }
                }

                // Sort by signal strength (RSSI)
                _discoveredDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
              });
            },
            onError: (error) {
              print('[DeviceDiscovery] Scan error: $error');
              setState(() => _isScanning = false);
            },
            onDone: () {
              print('[DeviceDiscovery] Scan completed');
              setState(() => _isScanning = false);
            },
          );

      // Auto-stop after timeout
      Future.delayed(Duration(seconds: BleConstants.scanTimeoutSeconds), () {
        if (mounted && _isScanning) {
          _stopScan();
        }
      });
    } catch (e) {
      print('[DeviceDiscovery] Error starting scan: $e');
      setState(() => _isScanning = false);
    }
  }

  Future<void> _stopScan() async {
    print('[DeviceDiscovery] _stopScan called');
    await _scanSubscription?.cancel();
    print('[DeviceDiscovery] Subscription cancelled');
    await _bleService.stopScan();
    print('[DeviceDiscovery] BLE scan stopped');
    if (mounted) {
      setState(() => _isScanning = false);
      print('[DeviceDiscovery] State updated - scan stopped');
    }
  }

  // ============================================================================
  // DEVICE SELECTION
  // ============================================================================

  void _onDeviceSelected(ScanResult result) async {
    final deviceName = result.device.platformName;
    print('[DeviceDiscovery] Device tapped: $deviceName');

    final deviceType = BleConstants.getDeviceType(deviceName);
    print('[DeviceDiscovery] Device type: $deviceType');

    if (deviceType == null) {
      print('[DeviceDiscovery] Unknown device type, ignoring');
      return;
    }

    // Stop scanning before connecting (don't wait for it to complete)
    print('[DeviceDiscovery] Stopping scan...');
    _stopScan().timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        print('[DeviceDiscovery] Stop scan timeout - continuing anyway');
      },
    );

    print('[DeviceDiscovery] Scan stop initiated, checking mounted state...');

    if (!mounted) {
      print('[DeviceDiscovery] Widget not mounted, aborting');
      return;
    }

    print('[DeviceDiscovery] Widget still mounted, continuing...');

    // Show progress dialog and start provisioning
    print(
      '[DeviceDiscovery] Starting provisioning for ${deviceType.displayName}',
    );
    _showProvisioningDialog(result.device, deviceType);
  }

  Future<void> _startProvisioning(
    BluetoothDevice device,
    DeviceType deviceType,
  ) async {
    print(
      '[DeviceDiscovery] _startProvisioning called for ${device.platformName}',
    );

    try {
      // Connect to device
      print('[DeviceDiscovery] Connecting to device...');
      await _bleService.connect(device);
      print('[DeviceDiscovery] Connected successfully');

      if (!mounted) return;

      String resultMAC = '';

      // Start provisioning based on device type
      if (deviceType == DeviceType.gateway) {
        print('[DeviceDiscovery] Starting Gateway provisioning...');
        resultMAC = await _bleService.provisionGatewayCellular(
          device: device,
          onProgress: (message) {
            print('[DeviceDiscovery] Progress: $message');
            // Update dialog progress if still mounted
            if (mounted) {
              // Could update state here to show progress
            }
          },
        );
        print('[DeviceDiscovery] Gateway MAC received: $resultMAC');
      } else {
        // For Node, get available Gateway MACs from storage
        print('[DeviceDiscovery] Starting Node provisioning...');
        final gatewayMACList = await _bleService.storage.getGatewayMACList();

        if (gatewayMACList.isEmpty) {
          print('[DeviceDiscovery] No Gateway MAC found in storage');
          if (!mounted) return;
          Navigator.pop(context);
          _showError(
            'Gateway chưa provisioning',
            'Vui lòng provisioning Gateway trước khi provisioning Node',
          );
          return;
        }

        // Select Gateway MAC
        String gatewayMAC;
        if (gatewayMACList.length == 1) {
          // Only one gateway - use it directly
          gatewayMAC = gatewayMACList.first;
          print('[DeviceDiscovery] Using only Gateway: $gatewayMAC');
        } else {
          // Multiple gateways - show selection dialog
          print(
            '[DeviceDiscovery] Found ${gatewayMACList.length} gateways, showing selection dialog',
          );
          if (!mounted) return;
          Navigator.pop(context); // Close provisioning dialog

          final selectedMAC = await _showGatewaySelectionDialog(gatewayMACList);

          if (selectedMAC == null) {
            print('[DeviceDiscovery] User cancelled gateway selection');
            return;
          }

          gatewayMAC = selectedMAC;
          print('[DeviceDiscovery] User selected Gateway: $gatewayMAC');

          // Show provisioning dialog again after selection
          if (!mounted) return;
          _showProvisioningDialog(device, deviceType);
        }

        print('[DeviceDiscovery] Using Gateway MAC: $gatewayMAC');
        final nodeAddress = await _bleService.provisionNode(
          device: device,
          gatewayMAC: gatewayMAC,
          onProgress: (message) {
            print('[DeviceDiscovery] Progress: $message');
          },
        );

        print(
          '[DeviceDiscovery] Node Address received: 0x${nodeAddress.toRadixString(16).padLeft(4, '0').toUpperCase()}',
        );
        resultMAC =
            '0x${nodeAddress.toRadixString(16).padLeft(4, '0').toUpperCase()}';
      }

      // Success!
      print('[DeviceDiscovery] Provisioning successful!');
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      // Show success
      _showSuccess(resultMAC, deviceType);
    } catch (e, stackTrace) {
      print('[DeviceDiscovery] ERROR: $e');
      print('[DeviceDiscovery] Stack trace: $stackTrace');
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog
      _showError('Provisioning Error', e.toString());
    } finally {
      print('[DeviceDiscovery] Disconnecting...');
      // Disconnect
      await _bleService.disconnect(device);

      // Resume scanning
      print('[DeviceDiscovery] Resuming scan...');
      if (mounted) _checkBluetoothAndStartScan();
    }
  }

  /// Show dialog to select Gateway when multiple gateways are available
  Future<String?> _showGatewaySelectionDialog(List<String> gateways) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chọn Gateway'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bạn có ${gateways.length} Gateway. Chọn Gateway để provision Node:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ...gateways.map(
                (mac) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, mac),
                    child: Column(
                      children: [
                        const Text('Gateway'),
                        Text(
                          mac,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Hủy'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProvisioningDialog(BluetoothDevice device, DeviceType deviceType) {
    print('[DeviceDiscovery] Showing provisioning dialog...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text(
              'Đang ${deviceType == DeviceType.gateway ? 'cấu hình Gateway' : 'cấu hình Node'}...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              device.platformName,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    // Start provisioning after dialog is shown
    print('[DeviceDiscovery] Dialog shown, starting provisioning...');
    _startProvisioning(device, deviceType);
  }

  void _showSuccess(String resultMAC, DeviceType deviceType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green[700],
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Thành công!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deviceType == DeviceType.gateway
                  ? 'Gateway đã được provisioning thành công.'
                  : 'Node đã được provisioning thành công.',
              style: const TextStyle(fontSize: 14),
            ),
            if (deviceType == DeviceType.node) ...[
              const SizedBox(height: 8),
              Text(
                'Node sẽ tự động xuất hiện trong danh sách sau khi kết nối với Gateway.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deviceType == DeviceType.gateway
                        ? 'Gateway MAC:'
                        : 'Node Address:',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    resultMAC,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              // Register Gateway in Firebase
              if (deviceType == DeviceType.gateway) {
                try {
                  await _firebaseService.registerGateway(resultMAC);
                  print(
                    '[DeviceDiscovery] Gateway registered in Firebase: $resultMAC',
                  );
                } catch (e) {
                  print(
                    '[DeviceDiscovery] Failed to register Gateway in Firebase: $e',
                  );
                }
              }

              // Navigate back to home screen
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Về màn hình chính'),
          ),
        ],
      ),
    );
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 32),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // DIALOGS
  // ============================================================================

  void _showBluetoothNotReadyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth_disabled,
                color: Colors.orange[700],
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Bluetooth chưa sẵn sàng',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Vui lòng bật Bluetooth và cấp quyền cho ứng dụng.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkBluetoothAndStartScan();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // UI BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    // Dynamic title based on filter
    String title = 'Tìm kiếm thiết bị';
    if (_filterType == DeviceType.gateway) {
      title = 'Tìm Gateway';
    } else if (_filterType == DeviceType.node) {
      title = 'Tìm Node';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // Filter dropdown
          PopupMenuButton<DeviceType?>(
            icon: Icon(
              _filterType == null ? Icons.filter_list : Icons.filter_list_alt,
              color: _filterType != null ? Colors.blue : null,
            ),
            onSelected: (type) {
              setState(() => _filterType = type);
              if (_isScanning) {
                _stopScan().then((_) => _startScan());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Tất cả thiết bị')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: DeviceType.gateway,
                child: Text('🌐 Chỉ Gateway'),
              ),
              const PopupMenuItem(
                value: DeviceType.node,
                child: Text('📡 Chỉ Node'),
              ),
            ],
          ),
          // Scan/Stop button
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: _isScanning ? _stopScan : _startScan,
            tooltip: _isScanning ? 'Dừng quét' : 'Quét lại',
          ),
        ],
      ),
      body: Column(
        children: [
          // Scan status
          _buildScanStatus(),

          // Device list
          Expanded(
            child: _discoveredDevices.isEmpty
                ? _buildEmptyState()
                : _buildDeviceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScanStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isScanning ? Colors.blue[50] : Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          if (_isScanning)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          else
            Icon(Icons.bluetooth_searching, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isScanning
                  ? 'Đang quét thiết bị ${_filterType != null ? _filterType!.displayName : ''}...'
                  : 'Tìm thấy ${_discoveredDevices.length} thiết bị',
              style: TextStyle(
                fontSize: 14,
                color: _isScanning ? Colors.blue[700] : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_filterType != null)
            Chip(
              label: Text(
                _filterType!.displayName,
                style: const TextStyle(fontSize: 12),
              ),
              avatar: Text(_filterType!.icon),
              backgroundColor: Colors.blue[100],
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () {
                setState(() => _filterType = null);
                if (_isScanning) {
                  _stopScan().then((_) => _startScan());
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_radarController.value * 0.3),
                child: Opacity(
                  opacity: 1.0 - _radarController.value,
                  child: Icon(
                    Icons.bluetooth_searching,
                    size: 80,
                    color: Colors.blue[300],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            _isScanning ? 'Đang tìm kiếm...' : 'Chưa tìm thấy thiết bị',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isScanning
                ? 'Vui lòng đợi trong ${BleConstants.scanTimeoutSeconds}s'
                : 'Nhấn nút quét để tìm kiếm',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _discoveredDevices.length,
      itemBuilder: (context, index) {
        final result = _discoveredDevices[index];
        return _buildDeviceCard(result);
      },
    );
  }

  Widget _buildDeviceCard(ScanResult result) {
    final deviceName = result.device.platformName;
    final deviceType = BleConstants.getDeviceType(deviceName);
    final rssi = result.rssi;

    // Signal strength indicator
    IconData signalIcon;
    Color signalColor;
    if (rssi > -60) {
      signalIcon = Icons.signal_cellular_alt;
      signalColor = Colors.green;
    } else if (rssi > -75) {
      signalIcon = Icons.signal_cellular_alt_2_bar;
      signalColor = Colors.orange;
    } else {
      signalIcon = Icons.signal_cellular_alt_1_bar;
      signalColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _onDeviceSelected(result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Device type icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: deviceType == DeviceType.gateway
                      ? Colors.blue[100]
                      : Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    deviceType?.icon ?? '❓',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: deviceType == DeviceType.gateway
                                ? Colors.blue[50]
                                : Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            deviceType?.displayName ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 12,
                              color: deviceType == DeviceType.gateway
                                  ? Colors.blue[700]
                                  : Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(signalIcon, size: 16, color: signalColor),
                        const SizedBox(width: 4),
                        Text(
                          '$rssi dBm',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
