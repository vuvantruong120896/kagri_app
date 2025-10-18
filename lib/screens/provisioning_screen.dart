import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../utils/constants.dart';

class ProvisioningScreen extends StatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  State<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends State<ProvisioningScreen>
    with TickerProviderStateMixin {
  final BleProvisioningService _bleService = BleProvisioningService();

  final List<ScanResult> _results = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _startScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _results.clear();
      _scanning = true;
    });
    _scanSub?.cancel();
    _scanSub = _bleService.scanGateways().listen((list) {
      setState(() {
        // Only show devices with "KAGRI-" prefix
        _results
          ..clear()
          ..addAll(
            list.where(
              (r) =>
                  r.advertisementData.advName.isNotEmpty &&
                  r.advertisementData.advName.startsWith('KAGRI-'),
            ),
          );
        _scanning = false;
      });
    });
  }

  Future<void> _provision(ScanResult gateway, String ssid, String pass) async {
    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Đang cấu hình Gateway...',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Đang gửi WiFi credentials và User ID',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );

    BluetoothDevice? device;
    bool success = false;

    try {
      device = await _bleService.connect(gateway);

      // Gateway will derive netkey from userUID + its own MAC address
      // Show progress dialog with animated steps
      if (!mounted) return;
      Navigator.pop(context); // Close initial loading

      await _showProvisioningProgress(
        context: context,
        ssid: ssid,
        gateway: gateway,
        onProvision: () async {
          success = await _bleService.provisionGateway(
            device: device!,
            ssid: ssid,
            password: pass,
          );
        },
      );

      if (!mounted) return;

      if (success) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Provision Thành Công!',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gateway đã được cấu hình thành công:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.wifi, 'WiFi', ssid),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.devices,
                  'Gateway',
                  gateway.advertisementData.advName,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[50]!, Colors.green[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.celebration,
                            size: 24,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Hoàn tất!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Gateway đang khởi động lại và kết nối WiFi. Dữ liệu sẽ xuất hiện trên màn hình chính trong giây lát.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close success dialog
                  Navigator.pop(
                    context,
                    true,
                  ); // Back to home with success flag
                },
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gateway không phản hồi hoặc có lỗi xảy ra'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Close loading dialog if still open
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (device != null) {
        await _bleService.disconnect(device);
      }
    }
  }

  // Show provisioning progress dialog with animated steps
  Future<void> _showProvisioningProgress({
    required BuildContext context,
    required String ssid,
    required ScanResult gateway,
    required Future<void> Function() onProvision,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProvisioningProgressDialog(
        ssid: ssid,
        gatewayName: gateway.advertisementData.advName,
        onProvision: onProvision,
      ),
    );
  }

  void _showWifiDialog(ScanResult gateway) {
    final ssidController = TextEditingController();
    final passController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true; // Track password visibility

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Cấu hình WiFi', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Gateway: ${gateway.advertisementData.advName}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: ssidController,
                    decoration: const InputDecoration(
                      labelText: 'WiFi SSID',
                      hintText: 'Nhập tên WiFi',
                      prefixIcon: Icon(Icons.wifi),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập SSID'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passController,
                    decoration: InputDecoration(
                      labelText: 'WiFi Password',
                      hintText: 'Nhập mật khẩu WiFi',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: obscurePassword,
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Mật khẩu tối thiểu 8 ký tự'
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final ssid = ssidController.text.trim();
                final pass = passController.text;
                Navigator.pop(context); // Close WiFi dialog

                // Wait for dialog animation to complete before showing loading
                await Future.delayed(const Duration(milliseconds: 300));

                if (mounted) {
                  _provision(gateway, ssid, pass); // Start provisioning
                }
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Provision'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provision Gateway')),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radar scanner animation
            Center(
              child: SizedBox(
                height: 200,
                width: 200,
                child: AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(200, 200), // Force square size
                      painter: _RadarPainter(
                        sweepAngle: _radarController.value * 2 * math.pi,
                        scanning: _scanning,
                        deviceCount: _results.length,
                      ),
                      child: child,
                    );
                  },
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Use router icon instead of radar to avoid visual conflict
                        Icon(
                          Icons.router,
                          size: 36,
                          color: const Color(0xFF00CCA3), // Military green
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _scanning
                              ? 'Đang quét...'
                              : '${_results.length} thiết bị',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00CCA3), // Military green
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Thiết bị khả dụng', style: AppTextStyles.heading2),
                const Spacer(),
                IconButton(
                  onPressed: _startScan,
                  icon: Icon(_scanning ? Icons.sync : Icons.refresh),
                  tooltip: 'Quét lại',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _scanning ? Icons.radar : Icons.devices_other,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _scanning
                                ? 'Đang tìm kiếm thiết bị...'
                                : 'Không tìm thấy thiết bị KAGRI',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _scanning
                                ? 'Vui lòng đợi trong giây lát'
                                : 'Nhấn nút làm mới để quét lại',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final r = _results[index];

                        // Determine signal strength color
                        Color signalColor;
                        IconData signalIcon;
                        if (r.rssi >= -60) {
                          signalColor = Colors.green;
                          signalIcon = Icons.signal_cellular_alt;
                        } else if (r.rssi >= -75) {
                          signalColor = Colors.orange;
                          signalIcon = Icons.signal_cellular_alt_2_bar;
                        } else {
                          signalColor = Colors.red;
                          signalIcon = Icons.signal_cellular_alt_1_bar;
                        }

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showWifiDialog(r),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Device icon
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue[400]!,
                                          Colors.blue[600]!,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.router,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Device info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.advertisementData.advName.isNotEmpty
                                              ? r.advertisementData.advName
                                              : r.device.remoteId.str,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.bluetooth,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              r.device.remoteId.str,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              signalIcon,
                                              size: 14,
                                              color: signalColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${r.rssi} dBm',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: signalColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Arrow icon
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for radar scanning animation
class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final bool scanning;
  final int deviceCount;

  _RadarPainter({
    required this.sweepAngle,
    required this.scanning,
    required this.deviceCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Use minimum dimension to ensure perfect circle
    final radius = math.min(size.width, size.height) / 2;

    // Military green colors (teal/cyan)
    const militaryGreen = Color(0xFF00CCA3); // Cyan-green military color

    // Draw concentric circles (radar rings) - always visible
    final circlePaint = Paint()
      ..color = militaryGreen.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * (i / 3), circlePaint);
    }

    // Draw crosshairs - always visible
    final crosshairPaint = Paint()
      ..color = militaryGreen.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      crosshairPaint,
    );

    // Draw sweeping radar beam - ALWAYS ACTIVE (removed if condition)
    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          militaryGreen.withOpacity(0.6),
          militaryGreen.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        sweepAngle - math.pi / 6, // Start angle (30 degrees before)
        math.pi / 6, // Sweep angle (30 degrees)
        false,
      )
      ..close();

    canvas.drawPath(path, sweepPaint);

    // Draw sweep line - ALWAYS ACTIVE
    final linePaint = Paint()
      ..color = militaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final lineEndX = center.dx + radius * math.cos(sweepAngle);
    final lineEndY = center.dy + radius * math.sin(sweepAngle);

    canvas.drawLine(center, Offset(lineEndX, lineEndY), linePaint);

    // Draw glow effect at sweep line end
    final glowPaint = Paint()
      ..color = militaryGreen.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lineEndX, lineEndY), 4, glowPaint);

    // Draw device indicators (dots) on the radar if devices found
    if (deviceCount > 0) {
      final devicePaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;

      // Place devices at different positions on radar
      for (int i = 0; i < deviceCount && i < 8; i++) {
        final angle = (i * 2 * math.pi / 8) + sweepAngle * 0.1;
        final distance = radius * (0.4 + (i % 3) * 0.2);
        final x = center.dx + distance * math.cos(angle);
        final y = center.dy + distance * math.sin(angle);

        canvas.drawCircle(Offset(x, y), 4, devicePaint);

        // Draw pulse effect
        final pulsePaint = Paint()
          ..color = Colors.green.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(Offset(x, y), 6, pulsePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.scanning != scanning ||
        oldDelegate.deviceCount != deviceCount;
  }
}

/// Provisioning Progress Dialog with animated steps
class _ProvisioningProgressDialog extends StatefulWidget {
  final String ssid;
  final String gatewayName;
  final Future<void> Function() onProvision;

  const _ProvisioningProgressDialog({
    required this.ssid,
    required this.gatewayName,
    required this.onProvision,
  });

  @override
  State<_ProvisioningProgressDialog> createState() =>
      _ProvisioningProgressDialogState();
}

class _ProvisioningProgressDialogState
    extends State<_ProvisioningProgressDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  int _currentStep = 0;
  bool _isComplete = false;

  final List<String> _steps = [
    'Kết nối với Gateway...',
    'Gửi thông tin WiFi...',
    'Cấu hình bảo mật...',
    'Khởi động lại thiết bị...',
    'Đang kết nối WiFi...',
    'Hoàn tất cấu hình!',
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _startProvisioning();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startProvisioning() async {
    // Simulate steps with delays for better UX - Total ~12 seconds
    for (int i = 0; i < _steps.length; i++) {
      if (!mounted) return;

      setState(() {
        _currentStep = i;
      });

      _progressController.reset();
      _progressController.forward();

      if (i == 1) {
        // Actually send provisioning data at step 2
        await widget.onProvision();
      }

      // Delay between steps - increased for better UX
      if (i < _steps.length - 1) {
        await Future.delayed(Duration(milliseconds: i == 1 ? 2500 : 2000));
      }
    }

    if (!mounted) return;
    setState(() {
      _isComplete = true;
    });

    // Auto close after showing complete
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / _steps.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated circular progress
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 10,
                      color: Colors.grey[200],
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  // Animated progress
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          color: _isComplete ? Colors.green : Colors.blue,
                          backgroundColor: Colors.transparent,
                        );
                      },
                    ),
                  ),
                  // Percentage text and icon
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isComplete ? Icons.check_circle : Icons.settings,
                        size: 44,
                        color: _isComplete ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _isComplete ? Colors.green : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Current step text
            Text(
              _steps[_currentStep],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Info container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.router, 'Gateway', widget.gatewayName),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.wifi, 'WiFi', widget.ssid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
