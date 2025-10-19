import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/firebase_command_service.dart';
import 'gateway_selection_screen.dart';

/// Screen to show provisioning progress in real-time
class ProvisioningProgressScreen extends StatefulWidget {
  final GatewayInfo gateway;
  final int durationMinutes;

  const ProvisioningProgressScreen({
    super.key,
    required this.gateway,
    this.durationMinutes = 5,
  });

  @override
  State<ProvisioningProgressScreen> createState() =>
      _ProvisioningProgressScreenState();
}

class _ProvisioningProgressScreenState extends State<ProvisioningProgressScreen>
    with TickerProviderStateMixin {
  final FirebaseCommandService _commandService = FirebaseCommandService();
  StreamSubscription? _resultSubscription;
  Timer? _countdownTimer;
  late AnimationController _radarController;

  String? _commandId; // Used for identifying the provisioning command
  bool _isStarting = true;
  bool _isActive = false;
  bool _isNetkeyPhase = false; // 2nd phase - netkey assignment
  bool _isCompleted = false;
  bool _isFailed = false;

  int _nodesDiscovered = 0;
  List<Map<String, dynamic>> _nodesList = []; // Store nodes with RSSI data
  double _timeRemainingSeconds = 0; // Changed to double for smooth countdown
  int _totalDurationSeconds = 240; // 4 minutes (changed from 5)
  String _statusMessage = 'Initializing...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _startProvisioning();
  }

  @override
  void dispose() {
    _resultSubscription?.cancel();
    _commandService.dispose();
    _countdownTimer?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _startProvisioning() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isFailed = true;
          _errorMessage = 'Chưa đăng nhập';
          _statusMessage = 'Lỗi xác thực';
        });
        return;
      }

      setState(() {
        _isStarting = true;
        _statusMessage = 'Gửi lệnh đến Gateway...';
      });

      // CRITICAL: Clear old result before starting new provisioning
      final resultPath =
          'users/${user.uid}/command_results/${widget.gateway.mac}';
      await FirebaseDatabase.instance.ref().child(resultPath).remove();

      debugPrint('🧹 Cleared old command results');

      // Send start provisioning command (5 minutes)
      _commandId = await _commandService.sendStartProvisioningCommand(
        userUID: user.uid,
        gatewayMAC: widget.gateway.mac,
        durationMs: _totalDurationSeconds * 1000,
      );

      setState(() {
        _isStarting = false;
        _isActive = true;
        _isNetkeyPhase = false;
        _timeRemainingSeconds = _totalDurationSeconds.toDouble();
        _statusMessage = 'Đang tìm các thiết bị ở gần';
      });

      // Start smooth countdown timer (update every 100ms)
      _startCountdownTimer();

      // Start listening to real-time routing table updates
      _listenToRoutingTableNodes(user.uid, widget.gateway.mac);

      // Listen to command results
      _resultSubscription = _commandService
          .listenToCommandResults(
            userUID: user.uid,
            gatewayMAC: widget.gateway.mac,
          )
          .listen(
            (result) {
              if (!mounted) return;

              // CRITICAL: Only process results for current command
              // Ignore old results from previous commands
              if (result.commandId.isNotEmpty &&
                  result.commandId != _commandId) {
                debugPrint(
                  '⚠️ Ignoring result from old command: ${result.commandId}',
                );
                return;
              }

              // Update UI with latest progress
              setState(() {
                if (result.progress != null) {
                  _nodesDiscovered = result.progress!.nodesDiscovered;
                  // Don't override timeRemainingSeconds - use countdown timer instead
                }

                // Only update status message if it's meaningful
                if (result.message.isNotEmpty && result.message != 'No data') {
                  _statusMessage = result.message;
                }

                // Check if completed
                if (result.isCompleted) {
                  _isActive = false;
                  _isNetkeyPhase = false;
                  _isCompleted = true;
                  _statusMessage = 'Cấp phát Netkey thành công';
                  _countdownTimer?.cancel();
                } else if (result.isFailed) {
                  _isActive = false;
                  _isNetkeyPhase = false;
                  _isFailed = true;
                  _errorMessage = result.message;
                  _statusMessage = 'Cấp phát Netkey thất bại';
                  _countdownTimer?.cancel();
                }
              });
            },
            onError: (error) {
              if (!mounted) return;
              setState(() {
                _isFailed = true;
                _errorMessage = error.toString();
                _statusMessage = 'Lỗi kết nối';
              });
              _countdownTimer?.cancel();
            },
          );
    } catch (e) {
      setState(() {
        _isStarting = false;
        _isFailed = true;
        _errorMessage = e.toString();
        _statusMessage = 'Không thể bắt đầu cấp phát';
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _timeRemainingSeconds -= 0.1;

        // Auto-send netkey at 3:30 (30 seconds remaining out of 4 minutes)
        // 4 minutes = 240 seconds, so 30 seconds remaining = 210 seconds elapsed
        if (!_isNetkeyPhase && _timeRemainingSeconds <= 30) {
          _isNetkeyPhase = true;
          _statusMessage = 'Đang cấu hình mạng';
          _sendNetkeyCommandAuto();
        }

        // Stop at 0
        if (_timeRemainingSeconds <= 0) {
          _timeRemainingSeconds = 0;
          timer.cancel();
          _completeProvisioning();
        }
      });
    });
  }

  Future<void> _sendNetkeyCommandAuto() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _commandService.sendNetkeyCommand(
        userUID: user.uid,
        gatewayMAC: widget.gateway.mac,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  /// Listen to real-time routing table updates from Gateway
  void _listenToRoutingTableNodes(String userUID, String gatewayMAC) {
    _commandService
        .listenToRoutingTableNodes(userUID: userUID, gatewayMAC: gatewayMAC)
        .listen(
          (nodes) {
            if (!mounted) return;

            setState(() {
              // Update nodes list with real RSSI/SNR data
              _nodesList = nodes
                  .map(
                    (node) => {
                      'id': nodes.indexOf(node) + 1,
                      'address': node.address,
                      'rssi': node.rssi,
                      'snr': node.snr,
                      'metric': node.metric,
                      'connection_type': node.getConnectionType(),
                      'signal_quality': node.getSignalQuality(),
                    },
                  )
                  .toList();

              debugPrint('🔄 Updated nodes list: ${_nodesList.length} nodes');
            });
          },
          onError: (error) {
            debugPrint('⚠️ Error listening to routing table: $error');
          },
        );
  }

  void _completeProvisioning() {
    if (!mounted) return;
    setState(() {
      _isActive = false;
      _isNetkeyPhase = false;
      _isCompleted = true;
      _statusMessage = 'Cấp phát Netkey hoàn tất';
    });
  }

  Future<void> _stopProvisioning() async {
    // Show confirmation dialog before stopping
    if (!mounted) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text(
              '⚠️ Dừng Cấu Hình?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
            content: const Text(
              'Dừng cấu hình đột ngột có thể ảnh hưởng đến thiết bị. '
              'Nên chờ cho đến khi quá trình cấu hình hoàn tất.\n\n'
              'Bạn vẫn muốn dừng ngay bây giờ?',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Chờ',
                  style: TextStyle(color: Colors.blue, fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Dừng Ngay',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() {
        _statusMessage = 'Đang dừng cấu hình...';
      });

      await _commandService.sendStopProvisioningCommand(
        userUID: user.uid,
        gatewayMAC: widget.gateway.mac,
      );

      if (!mounted) return;

      setState(() {
        _isActive = false;
        _isCompleted = true;
        _statusMessage = 'Cấu hình đã bị dừng';
        _countdownTimer?.cancel();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _finish() {
    // If stopped manually, pop back to Gateway selection screen
    // Otherwise pop once (normal completion flow)
    final wasStoppedManually = _statusMessage == 'Cấu hình đã bị dừng';

    if (wasStoppedManually) {
      // Pop twice to get back to Gateway selection screen
      // Pop 1: provisioning progress screen
      // Pop 2: provisioning screen (back to gateway selection)
      Navigator.pop(context);
      Navigator.pop(context);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isActive) {
          final shouldStop = await _showStopConfirmDialog();
          if (shouldStop == true) {
            await _stopProvisioning();
            return true;
          }
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thêm Nodes'),
          automaticallyImplyLeading: !_isActive,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Gateway info - compact
          _buildGatewayInfo(),
          const SizedBox(height: 16),

          // Status indicator
          if (_isStarting) _buildStartingIndicator(),
          if (_isActive) _buildActiveIndicator(),
          if (_isCompleted) _buildCompletedIndicator(),
          if (_isFailed) _buildFailedIndicator(),

          const SizedBox(height: 12),

          // Progress info - wrapped in Expanded to prevent overflow
          // Only show progress info if actively provisioning or completed naturally
          // Don't show if provisioning was stopped manually
          if ((_isActive || _isCompleted) &&
              !(_isCompleted && _statusMessage == 'Cấu hình đã bị dừng'))
            Expanded(child: SingleChildScrollView(child: _buildProgressInfo())),

          const SizedBox(height: 12),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildGatewayInfo() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.router, size: 32, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.gateway.name ?? 'Gateway',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.gateway.mac,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartingIndicator() {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(_statusMessage, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildActiveIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Radar animation - reduced size (150x150)
        Center(
          child: SizedBox(
            height: 150,
            width: 150,
            child: AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(150, 150),
                  painter: _RadarPainter(
                    sweepAngle: _radarController.value * 2 * math.pi,
                    scanning: true,
                    deviceCount: _nodesDiscovered,
                    nodes: _nodesList,
                  ),
                  child: child,
                );
              },
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _nodesDiscovered > 0
                          ? _nodesDiscovered == 1
                                ? '1 Node'
                                : '$_nodesDiscovered Nodes'
                          : 'Quét...',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00CCA3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Hiển thị thời gian ở đây (tập trung ở giữa)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, color: Colors.orange, size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTimeFromSeconds(_timeRemainingSeconds),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const Text(
                  'còn lại',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Ẩn "Fast discovery mode..." message khi có nodes
        if (_nodesDiscovered == 0 && _statusMessage.contains('Fast discovery'))
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildCompletedIndicator() {
    // Check if stopped by user or completed naturally
    final wasStoppedManually = _statusMessage == 'Cấu hình đã bị dừng';

    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: wasStoppedManually ? Colors.orange : Colors.green,
            shape: BoxShape.circle,
          ),
          child: Icon(
            wasStoppedManually ? Icons.warning : Icons.check,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          wasStoppedManually ? '⚠️ Cấu hình đã dừng' : '✅ Cấu hình hoàn tất',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: wasStoppedManually ? Colors.orange : Colors.green,
          ),
        ),
        // Only show detail text when completed naturally, not when manually stopped
        if (!wasStoppedManually) ...[
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildFailedIndicator() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 60, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text(
          '❌ Cấu hình thất bại',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildProgressInfo() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact stat header
            Row(
              children: [
                Icon(Icons.router, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 6),
                Text(
                  'Tìm thấy ${_nodesDiscovered} Node',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),

            if (_nodesDiscovered > 0) ...[
              const SizedBox(height: 8),
              const Divider(height: 6),
              const SizedBox(height: 8),

              // List of nodes with signal quality
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _nodesDiscovered,
                  separatorBuilder: (_, __) =>
                      Divider(height: 0.5, color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    // Get real data from routing table
                    final nodeData = _nodesList[index];
                    final rssi = nodeData['rssi'] as int? ?? -50;
                    final snr = nodeData['snr'] as double? ?? 15.0;
                    final address = nodeData['address'] as String? ?? '0x0000';

                    // Determine signal strength color based on RSSI
                    Color signalColor;
                    if (rssi >= -60) {
                      signalColor = Colors.green;
                    } else if (rssi >= -75) {
                      signalColor = Colors.orange;
                    } else {
                      signalColor = Colors.red;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          // Node icon
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.router_rounded,
                              size: 18,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Node info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Node ${index + 1} • $address',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'RSSI: $rssi dBm | SNR: ${snr.toStringAsFixed(1)} dB',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Signal strength indicator
                          Icon(
                            Icons.signal_cellular_alt,
                            size: 18,
                            color: signalColor,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            // Success message when completed
            if (_nodesDiscovered > 0 && _isCompleted) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[700],
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '🎉 Cấp phát Netkey thành công cho tất cả ${_nodesDiscovered} node!',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isStarting) {
      return const SizedBox.shrink();
    }

    if (_isActive) {
      return Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _stopProvisioning,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text(
                    'Dừng Cấu hình',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Completed or failed
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _finish,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.blue,
            ),
            child: const Text(
              'Quay lại',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimeFromSeconds(double seconds) {
    final totalSeconds = seconds.toInt();
    final minutes = totalSeconds ~/ 60;
    final remainingSeconds = totalSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<bool?> _showStopConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dừng Cấu hình?'),
        content: const Text(
          'Cấu hình đang được thực hiện. Bạn có muốn dừng và quay lại?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Dừng'),
          ),
        ],
      ),
    );
  }
}

/// Custom radar painter for node scanning visualization
class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final bool scanning;
  final int deviceCount;
  final List<Map<String, dynamic>>? nodes; // Node list with RSSI data

  _RadarPainter({
    required this.sweepAngle,
    required this.scanning,
    required this.deviceCount,
    this.nodes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw circles
    final circlePaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius * 0.33, circlePaint);
    canvas.drawCircle(center, radius * 0.66, circlePaint);
    canvas.drawCircle(center, radius, circlePaint);

    // Draw crosshair
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      circlePaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      circlePaint,
    );

    if (scanning) {
      // Draw rotating sweep line
      final sweepPaint = Paint()
        ..color = Colors.green.withOpacity(0.6)
        ..strokeWidth = 2;

      final sweepX = center.dx + radius * math.cos(sweepAngle - math.pi / 2);
      final sweepY = center.dy + radius * math.sin(sweepAngle - math.pi / 2);

      canvas.drawLine(center, Offset(sweepX, sweepY), sweepPaint);

      // Draw sweep area as semi-transparent gradient
      final sweepAreaPaint = Paint()
        ..color = Colors.green.withOpacity(0.1)
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          sweepAngle - math.pi / 2,
          math.pi / 3,
          false,
        )
        ..close();

      canvas.drawPath(path, sweepAreaPaint);
    }

    // Draw center dot
    final centerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4, centerPaint);

    // Draw detected devices as dots with fixed positions based on RSSI
    if (deviceCount > 0) {
      final devicePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;

      for (int i = 0; i < deviceCount && i < 8; i++) {
        // Distribute nodes around the radar in fixed positions
        // Better RSSI = closer to center
        // Worse RSSI = farther from center

        // Generate mock RSSI if no node data provided
        final rssi = nodes != null && i < nodes!.length
            ? (nodes![i]['rssi'] ?? (-50 - (i * 5)))
            : (-50 - (i * 5));

        // Map RSSI to distance: stronger RSSI (closer to 0) = closer to center
        // RSSI range: -30 (excellent) to -90 (poor)
        // Normalize RSSI to distance: -30 → inner circle, -90 → outer circle
        final rssiNormalized =
            ((rssi + 90) / 60); // 0 to 1 scale (inverted, so better = closer)
        final distance = radius * 0.2 + (1 - rssiNormalized) * radius * 0.6;

        // Position nodes at fixed angles distributed around circle
        final angle = (i * (2 * math.pi / 8)); // Fixed 45° intervals
        final x = center.dx + distance * math.cos(angle);
        final y = center.dy + distance * math.sin(angle);

        canvas.drawCircle(Offset(x, y), 4, devicePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => true;
}
