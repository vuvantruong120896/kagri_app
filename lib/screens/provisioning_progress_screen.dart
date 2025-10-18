import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class _ProvisioningProgressScreenState
    extends State<ProvisioningProgressScreen> {
  final FirebaseCommandService _commandService = FirebaseCommandService();
  StreamSubscription? _resultSubscription;
  Timer? _countdownTimer;

  String? _commandId; // Used for identifying the provisioning command
  bool _isStarting = true;
  bool _isActive = false;
  bool _isNetkeyPhase = false; // 2nd phase - netkey assignment
  bool _isCompleted = false;
  bool _isFailed = false;

  int _nodesDiscovered = 0;
  double _timeRemainingSeconds = 0; // Changed to double for smooth countdown
  int _totalDurationSeconds = 300; // 5 minutes
  String _statusMessage = 'Initializing...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startProvisioning();
  }

  @override
  void dispose() {
    _resultSubscription?.cancel();
    _commandService.dispose();
    _countdownTimer?.cancel();
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

      // Listen to command results
      _resultSubscription = _commandService
          .listenToCommandResults(
            userUID: user.uid,
            gatewayMAC: widget.gateway.mac,
          )
          .listen(
            (result) {
              if (!mounted) return;

              // Update UI with latest progress
              setState(() {
                if (result.progress != null) {
                  _nodesDiscovered = result.progress!.nodesDiscovered;
                  // Don't override timeRemainingSeconds - use countdown timer instead
                }

                _statusMessage = result.message;

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
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _timeRemainingSeconds -= 0.1;
        
        // Phase transition at 4 minutes (240 seconds)
        if (!_isNetkeyPhase && _timeRemainingSeconds <= 240) {
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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() {
        _statusMessage = 'Stopping provisioning...';
      });

      await _commandService.sendStopProvisioningCommand(
        userUID: user.uid,
        gatewayMAC: widget.gateway.mac,
      );

      setState(() {
        _isActive = false;
        _isCompleted = true;
        _statusMessage = 'Provisioning stopped manually';
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to stop: $e')));
    }
  }

  Future<void> _sendNetkeyCommand() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() {
        _statusMessage = 'Sending netkey assignment command...';
      });

      await _commandService.sendNetkeyCommand(
        userUID: user.uid,
        gatewayMAC: widget.gateway.mac,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Netkey assignment command sent'),
          duration: Duration(seconds: 2),
        ),
      );

      setState(() {
        _statusMessage = 'Netkey command sent. Waiting for nodes...';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi gửi lệnh: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _finish() {
    Navigator.pop(context);
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
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gateway info
          _buildGatewayInfo(),
          const SizedBox(height: 32),

          // Status indicator
          if (_isStarting) _buildStartingIndicator(),
          if (_isActive) _buildActiveIndicator(),
          if (_isCompleted) _buildCompletedIndicator(),
          if (_isFailed) _buildFailedIndicator(),

          const SizedBox(height: 32),

          // Progress info
          if (_isActive || _isCompleted) _buildProgressInfo(),

          const Spacer(),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildGatewayInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.router, size: 40, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.gateway.name ?? 'Gateway',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.gateway.mac,
                    style: const TextStyle(color: Colors.grey),
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
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: _timeRemainingSeconds > 0
                    ? 1 - (_timeRemainingSeconds / _totalDurationSeconds)
                    : 0,
                strokeWidth: 8,
                backgroundColor: Colors.grey[300],
              ),
            ),
            Column(
              children: [
                Text(
                  _formatTimeFromSeconds(_timeRemainingSeconds),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('còn lại', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('🔍 Đang quét các Node...', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildCompletedIndicator() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 60, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text(
          '✅ Cấu hình hoàn tất',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.devices,
                  label: 'Nodes Khám phá',
                  value: _nodesDiscovered.toString(),
                  color: Colors.blue,
                ),
                if (_isActive)
                  _buildStatItem(
                    icon: Icons.timer,
                    label: 'Thời gian còn lại',
                    value: _formatTimeFromSeconds(_timeRemainingSeconds),
                    color: Colors.orange,
                  ),
              ],
            ),
            if (_nodesDiscovered > 0 && _isCompleted) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '🎉 $_nodesDiscovered Node mới${_nodesDiscovered > 1 ? 's' : ''} đã tham gia mạng!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_isStarting) {
      return const SizedBox.shrink();
    }

    if (_isActive) {
      return Column(
        children: [
          const Text(
            '💡 Bật các Node của bạn ngay bây giờ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gateway đang phát sóng ở chế độ khám phá nhanh',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _sendNetkeyCommand,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text(
                    'Cấp Netkey',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _finish,
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
        child: const Text('Hoàn tất', style: TextStyle(fontSize: 16)),
      ),
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
