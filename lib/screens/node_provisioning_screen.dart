import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_provisioning_service.dart';
import '../services/provisioning_storage.dart';
import '../constants/ble_constants.dart';

/// Node Provisioning Screen
///
/// Provisions Node devices with Gateway MAC
/// Allows selection from multiple provisioned Gateways
///
/// Updated: November 2025

class NodeProvisioningScreen extends StatefulWidget {
  final BluetoothDevice device;

  const NodeProvisioningScreen({super.key, required this.device});

  @override
  State<NodeProvisioningScreen> createState() => _NodeProvisioningScreenState();
}

class _NodeProvisioningScreenState extends State<NodeProvisioningScreen> {
  final BleProvisioningService _bleService = BleProvisioningService();
  final ProvisioningStorage _storage = ProvisioningStorage();

  // Form fields
  final _gatewayMACController = TextEditingController();

  // Gateway selection
  List<String> _availableGateways = [];
  String? _selectedGatewayMAC;
  bool _useManualMAC = false;

  // State
  bool _isProvisioning = false;
  bool _isLoadingGateways = true;
  String _statusMessage = '';
  int? _nodeAddress;
  bool _provisioningSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableGateways();
  }

  @override
  void dispose() {
    _gatewayMACController.dispose();
    super.dispose();
  }

  // ============================================================================
  // GATEWAY LOADING
  // ============================================================================

  Future<void> _loadAvailableGateways() async {
    setState(() => _isLoadingGateways = true);

    try {
      final gateways = await _storage.getGatewayMACList();
      final lastGateway = await _storage.getLastGatewayMAC();

      setState(() {
        _availableGateways = gateways;
        _selectedGatewayMAC = lastGateway;
        _isLoadingGateways = false;

        if (gateways.isEmpty) {
          _useManualMAC = true;
        }
      });
    } catch (e) {
      print('[NodeProvisioning] Error loading gateways: $e');
      setState(() {
        _isLoadingGateways = false;
        _useManualMAC = true;
      });
    }
  }

  // ============================================================================
  // PROVISIONING
  // ============================================================================

  Future<void> _provision() async {
    // Get Gateway MAC
    String gatewayMAC;
    if (_useManualMAC) {
      gatewayMAC = _gatewayMACController.text.trim();
    } else {
      gatewayMAC = _selectedGatewayMAC ?? '';
    }

    // Validation
    if (gatewayMAC.isEmpty) {
      _showError('Vui lòng chọn hoặc nhập Gateway MAC');
      return;
    }

    if (!BleConstants.isValidMacAddress(gatewayMAC)) {
      _showError(
        'Gateway MAC không đúng định dạng.\n'
        'Sử dụng: AA:BB:CC:DD:EE:FF',
      );
      return;
    }

    setState(() {
      _isProvisioning = true;
      _statusMessage = 'Bắt đầu provisioning Node...';
      _provisioningSuccess = false;
      _nodeAddress = null;
    });

    try {
      // Connect to device
      await _bleService.connect(widget.device);

      // Provision Node
      final nodeAddress = await _bleService.provisionNode(
        device: widget.device,
        gatewayMAC: gatewayMAC,
        onProgress: (message) {
          setState(() => _statusMessage = message);
        },
      );

      // Save session info
      await _storage.saveLastProvisioningSession(
        deviceType: 'Node',
        deviceName: widget.device.platformName,
      );

      setState(() {
        _nodeAddress = nodeAddress;
        _provisioningSuccess = true;
        _statusMessage = 'Provisioning thành công!';
      });

      // Show success dialog
      if (!mounted) return;
      _showSuccessDialog(nodeAddress, gatewayMAC);
    } catch (e) {
      print('[NodeProvisioning] Error: $e');
      setState(() {
        _statusMessage = 'Lỗi: ${e.toString()}';
        _provisioningSuccess = false;
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
  // DIALOGS
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

  void _showSuccessDialog(int nodeAddress, String gatewayMAC) {
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
              'Node đã được provisioning thành công.',
              style: TextStyle(fontSize: 14),
            ),
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
                  const Text(
                    'Node Address:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '0x${nodeAddress.toRadixString(16).toUpperCase().padLeft(4, '0')}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gateway MAC:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    gatewayMAC,
                    style: const TextStyle(
                      fontSize: 14,
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
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to discovery screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hoàn tất'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Provisioning Node')),
      body: _isLoadingGateways
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device info
                  _buildDeviceInfo(),
                  const SizedBox(height: 24),

                  // Gateway selection
                  _buildGatewaySelection(),
                  const SizedBox(height: 24),

                  // Provision button
                  _buildProvisionButton(),
                  const SizedBox(height: 24),

                  // Status
                  if (_statusMessage.isNotEmpty) _buildStatusCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildDeviceInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('📡', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Node',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.device.platformName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatewaySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gateway MAC',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (_availableGateways.isNotEmpty)
              TextButton.icon(
                icon: Icon(_useManualMAC ? Icons.list : Icons.edit, size: 18),
                label: Text(
                  _useManualMAC ? 'Chọn từ danh sách' : 'Nhập thủ công',
                ),
                onPressed: _isProvisioning
                    ? null
                    : () {
                        setState(() {
                          _useManualMAC = !_useManualMAC;
                          if (!_useManualMAC) {
                            _gatewayMACController.clear();
                          }
                        });
                      },
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Show gateway selector or manual input
        if (_useManualMAC)
          _buildManualMACInput()
        else if (_availableGateways.isEmpty)
          _buildNoGatewaysWarning()
        else
          _buildGatewayDropdown(),
      ],
    );
  }

  Widget _buildManualMACInput() {
    return TextField(
      controller: _gatewayMACController,
      enabled: !_isProvisioning,
      decoration: InputDecoration(
        labelText: 'Gateway MAC Address',
        hintText: 'AA:BB:CC:DD:EE:FF',
        helperText: 'Lấy từ màn hình provisioning Gateway',
        prefixIcon: const Icon(Icons.router),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      style: const TextStyle(fontFamily: 'monospace'),
    );
  }

  Widget _buildGatewayDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: _selectedGatewayMAC,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down),
        items: _availableGateways.map((mac) {
          final isLast = mac == _availableGateways.last;
          return DropdownMenuItem(
            value: mac,
            child: Row(
              children: [
                Icon(
                  Icons.router,
                  size: 18,
                  color: isLast ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 12),
                Text(
                  mac,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isLast) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Mới nhất',
                      style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        onChanged: _isProvisioning
            ? null
            : (value) {
                setState(() => _selectedGatewayMAC = value);
              },
      ),
    );
  }

  Widget _buildNoGatewaysWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange[700], size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Chưa có Gateway nào được provisioning.\n'
              'Vui lòng provision Gateway trước.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvisionButton() {
    final bool canProvision = _useManualMAC
        ? _gatewayMACController.text.isNotEmpty
        : _selectedGatewayMAC != null;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (canProvision && !_isProvisioning) ? _provision : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isProvisioning
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Đang provisioning...'),
                ],
              )
            : const Text(
                'Provision Node',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _provisioningSuccess ? Colors.green[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _provisioningSuccess ? Colors.green[200]! : Colors.blue[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _provisioningSuccess ? Icons.check_circle : Icons.info,
            color: _provisioningSuccess ? Colors.green[700] : Colors.blue[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: _provisioningSuccess
                    ? Colors.green[900]
                    : Colors.blue[900],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
