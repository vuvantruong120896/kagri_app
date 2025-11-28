import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_provisioning_service.dart';
import '../services/provisioning_storage.dart';
import '../services/wifi_scan_service.dart';
import '../services/device_registry_service.dart';
import 'handheld_sensor_data_screen.dart';

/// Handheld WiFi Provisioning Screen
///
/// Provisions Handheld soil sensor devices with WiFi credentials via BLE.
/// Features:
/// - WiFi network scanning
/// - Manual SSID/password entry
/// - Real-time provisioning progress
/// - Success/error handling with user feedback
///
/// Updated: November 2025

class HandheldProvisioningScreen extends StatefulWidget {
  final BluetoothDevice device;

  const HandheldProvisioningScreen({super.key, required this.device});

  @override
  State<HandheldProvisioningScreen> createState() =>
      _HandheldProvisioningScreenState();
}

class _HandheldProvisioningScreenState
    extends State<HandheldProvisioningScreen> {
  final BleProvisioningService _bleService = BleProvisioningService();
  final ProvisioningStorage _storage = ProvisioningStorage();
  final WiFiScanService _wifiService = WiFiScanService();
  final DeviceRegistryService _deviceRegistry = DeviceRegistryService();

  // Form controllers
  late TextEditingController _ssidController;
  late TextEditingController _passwordController;

  // State
  bool _isProvisioning = false;
  bool _showPassword = false;
  String _statusMessage = '';
  bool _provisioningSuccess = false;
  int _progressPercent = 0;
  bool _shouldNavigateToSensorData = false;

  // WiFi scan
  List<String> _availableNetworks = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _ssidController = TextEditingController();
    _passwordController = TextEditingController();
    _scanNetworks();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================================
  // DEVICE PROVISIONING HELPERS
  // ============================================================================

  /// Extract last 2 bytes from BLE device name as nodeID (hex format)
  /// Example: "KAGRI-HHT-65E0" → "0x65E0"
  String _extractNodeIdFromDeviceName(String deviceName) {
    final parts = deviceName.split('-');
    if (parts.isNotEmpty) {
      final lastPart = parts.last;
      return '0x${lastPart.toUpperCase()}';
    }
    return '0xFFFF';
  }

  // ============================================================================
  // WiFi SCANNING
  // ============================================================================

  Future<void> _scanNetworks() async {
    setState(() => _isScanning = true);

    try {
      // Try to scan for available networks
      // Note: WiFiScanService.getAvailableNetworks() may not be implemented yet
      // For now, we'll just provide manual entry capability
      setState(() {
        _availableNetworks =
            []; // Can be populated from actual WiFi scan in future
        _isScanning = false;
      });
    } catch (e) {
      print('[HandheldProvisioning] WiFi scan info: $e');
      setState(() => _isScanning = false);
    }
  }

  // ============================================================================
  // PROVISIONING
  // ============================================================================

  Future<void> _provision() async {
    // Validate inputs
    if (_ssidController.text.isEmpty) {
      _showError('SSID không được để trống');
      return;
    }

    setState(() {
      _isProvisioning = true;
      _statusMessage = 'Bắt đầu provisioning...';
      _provisioningSuccess = false;
      _progressPercent = 0;
    });

    try {
      // Connect to device
      setState(() => _statusMessage = 'Kết nối với Handheld...');
      await _bleService.connect(widget.device);
      setState(() => _progressPercent = 20);

      // Provision with WiFi credentials
      setState(() => _statusMessage = 'Gửi thông tin WiFi...');
      await _bleService.provisionHandheldWiFi(
        device: widget.device,
        ssid: _ssidController.text.trim(),
        password: _passwordController.text,
        onProgress: (message) {
          setState(() => _statusMessage = message);
          // Gradually increase progress
          if (_progressPercent < 90) {
            setState(() => _progressPercent += 10);
          }
        },
      );

      setState(() => _progressPercent = 100);

      // Save session info
      await _storage.saveLastProvisioningSession(
        deviceType: 'Handheld',
        deviceName: widget.device.platformName,
      );

      // Register device in Firebase immediately after provisioning
      setState(() => _statusMessage = 'Đăng ký thiết bị trong Firebase...');
      try {
        final nodeId = _extractNodeIdFromDeviceName(widget.device.name);
        await _deviceRegistry.registerDevice(
          nodeId: nodeId,
          deviceType: 'handheld',
          displayName: 'Handheld $nodeId',
          location: null,
          notes: 'Soil sensor via BLE',
          firmwareVersion: null,
        );
        print(
          '[HandheldProvisioning] ✅ Device registered in Firebase: $nodeId',
        );
      } catch (e) {
        print('[HandheldProvisioning] ⚠️ Failed to register device: $e');
        // Continue anyway, device can be registered later when uploading data
      }

      setState(() {
        _provisioningSuccess = true;
        _statusMessage = 'Provisioning thành công!';
      });

      // Show success dialog
      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      print('[HandheldProvisioning] Error: $e');
      setState(() {
        _statusMessage = 'Lỗi: ${e.toString()}';
        _progressPercent = 0;
      });

      if (!mounted) return;
      _showError(e.toString());
    } finally {
      // Disconnect
      await _bleService.disconnect(widget.device);

      if (mounted) {
        setState(() => _isProvisioning = false);
      }
    }
  }

  // ============================================================================
  // DIALOGS & UI HELPERS
  // ============================================================================

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 32),
            const SizedBox(width: 12),
            const Text('Lỗi'),
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

  void _showSuccessDialog() {
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
            const Text(
              'Handheld đã được provisioning thành công.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'WiFi Configuration',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('SSID: ${_ssidController.text}'),
                  const SizedBox(height: 4),
                  const Text('Status: Saved to device'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Set flag for auto-navigation
              setState(() => _shouldNavigateToSensorData = true);
              // Close provisioning screen
              Future.delayed(const Duration(milliseconds: 100), () {
                Navigator.pop(context);
              });
            },
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle auto-navigation after successful provisioning
    if (_shouldNavigateToSensorData) {
      // Schedule navigation for next frame to avoid setState during build
      Future.microtask(() {
        if (mounted) {
          print(
            '[HandheldProvisioning] ✅ Navigating to sensor data screen after 2 second delay...',
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) =>
                      HandheldSensorDataScreen(device: widget.device),
                ),
              );
            }
          });
        }
      });
    }

    return PopScope(
      canPop: !_isProvisioning,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cấu hình Handheld WiFi'),
          elevation: 0,
          backgroundColor: Colors.blue[700],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.devices, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thiết bị',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.device.platformName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Form Section
              if (!_isProvisioning) ...[
                // SSID Field
                Text(
                  'Tên mạng WiFi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ssidController,
                  enabled: !_isProvisioning,
                  decoration: InputDecoration(
                    hintText: 'Nhập hoặc chọn mạng WiFi',
                    prefixIcon: Icon(Icons.router, color: Colors.blue[700]),
                    suffixIcon: _availableNetworks.isNotEmpty
                        ? PopupMenuButton<String>(
                            onSelected: (String network) {
                              _ssidController.text = network;
                            },
                            itemBuilder: (BuildContext context) {
                              return _availableNetworks
                                  .map<PopupMenuEntry<String>>((String value) {
                                    return PopupMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  })
                                  .toList();
                            },
                            child: Icon(
                              Icons.arrow_drop_down,
                              color: Colors.blue[700],
                            ),
                          )
                        : _isScanning
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.blue[700],
                                ),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: Icon(Icons.refresh, color: Colors.blue[700]),
                            onPressed: _scanNetworks,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field
                Text(
                  'Mật khẩu WiFi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  enabled: !_isProvisioning,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    hintText: 'Nhập mật khẩu (nếu có)',
                    prefixIcon: Icon(Icons.lock, color: Colors.blue[700]),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.blue[700],
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Provision Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _provision,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text(
                      'Gửi cấu hình',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Provisioning Progress
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: _progressPercent / 100,
                              strokeWidth: 8,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.blue[700],
                              ),
                              backgroundColor: Colors.grey[200],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_progressPercent}%',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Đang xử lý...',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Info Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ghi chú',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Thiết bị sẽ lưu credentials vào bộ nhớ\n'
                            '• Kết nối sẽ tự động khi khởi động\n'
                            '• Có thể cấu hình lại qua BLE bất kỳ lúc nào',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber[900],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
