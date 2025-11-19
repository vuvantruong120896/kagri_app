import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_provisioning_service.dart';
import '../services/provisioning_storage.dart';

/// Gateway Provisioning Screen (Cellular Only)
///
/// Provisions Gateway devices in Cellular mode
/// Saves Gateway MAC for future Node provisioning
///
/// Updated: November 2025

class GatewayProvisioningScreen extends StatefulWidget {
  final BluetoothDevice device;

  const GatewayProvisioningScreen({super.key, required this.device});

  @override
  State<GatewayProvisioningScreen> createState() =>
      _GatewayProvisioningScreenState();
}

class _GatewayProvisioningScreenState extends State<GatewayProvisioningScreen> {
  final BleProvisioningService _bleService = BleProvisioningService();
  final ProvisioningStorage _storage = ProvisioningStorage();

  // State
  bool _isProvisioning = false;
  String _statusMessage = '';
  bool _provisioningSuccess = false;

  @override
  void dispose() {
    super.dispose();
  }

  // ============================================================================
  // PROVISIONING
  // ============================================================================

  Future<void> _provision() async {
    setState(() {
      _isProvisioning = true;
      _statusMessage = 'Bắt đầu provisioning...';
      _provisioningSuccess = false;
    });

    try {
      // Connect to device
      await _bleService.connect(widget.device);

      // Cellular mode provisioning
      final gatewayMAC = await _bleService.provisionGatewayCellular(
        device: widget.device,
        onProgress: (message) {
          setState(() => _statusMessage = message);
        },
      );

      // Save session info
      await _storage.saveLastProvisioningSession(
        deviceType: 'Gateway',
        deviceName: widget.device.platformName,
      );

      setState(() {
        _provisioningSuccess = true;
        _statusMessage = 'Provisioning thành công!';
      });

      // Show success dialog
      if (!mounted) return;
      _showSuccessDialog(gatewayMAC);
    } catch (e) {
      print('[GatewayProvisioning] Error: $e');
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

  void _showSuccessDialog(String gatewayMAC) {
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
              'Gateway đã được provisioning thành công.',
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
                    'Gateway MAC:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    gatewayMAC,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'MAC này sẽ được sử dụng khi provisioning Node.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
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
              backgroundColor: Colors.blue,
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
      appBar: AppBar(title: const Text('Provisioning Gateway')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device info
            _buildDeviceInfo(),
            const SizedBox(height: 24),

            // Info card
            _buildInfoCard(),
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
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('🌐', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gateway',
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

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cell_tower, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              Text(
                'Chế độ: Kết nối Cellular',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Gateway sẽ được cấu hình để kết nối qua mạng Cellular (SIM card). Không cần cung cấp thông tin WiFi.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue[800],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvisionButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isProvisioning ? null : _provision,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
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
                'Provision Gateway (Cellular)',
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
