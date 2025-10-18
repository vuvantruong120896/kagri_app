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

  String? _commandId;
  bool _isStarting = true;
  bool _isActive = false;
  bool _isCompleted = false;
  bool _isFailed = false;

  int _nodesDiscovered = 0;
  int _timeRemainingMs = 0;
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
    super.dispose();
  }

  Future<void> _startProvisioning() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isFailed = true;
          _errorMessage = 'Not logged in';
          _statusMessage = 'Authentication error';
        });
        return;
      }

      setState(() {
        _isStarting = true;
        _statusMessage = 'Sending command to Gateway...';
      });

      // Send start provisioning command
      final durationMs = widget.durationMinutes * 60 * 1000;
      _commandId = await _commandService.sendStartProvisioningCommand(
        userUID: user.uid,
        gatewayMAC: widget.gateway.mac,
        durationMs: durationMs,
      );

      setState(() {
        _isStarting = false;
        _isActive = true;
        _timeRemainingMs = durationMs;
        _statusMessage = 'Provisioning started';
      });

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
                  _timeRemainingMs = result.progress!.timeRemainingMs;
                }

                _statusMessage = result.message;

                // Check if completed
                if (result.isCompleted) {
                  _isActive = false;
                  _isCompleted = true;
                  _statusMessage = 'Provisioning completed successfully';
                } else if (result.isFailed) {
                  _isActive = false;
                  _isFailed = true;
                  _errorMessage = result.message;
                  _statusMessage = 'Provisioning failed';
                }
              });
            },
            onError: (error) {
              if (!mounted) return;
              setState(() {
                _isFailed = true;
                _errorMessage = error.toString();
                _statusMessage = 'Connection error';
              });
            },
          );
    } catch (e) {
      setState(() {
        _isStarting = false;
        _isFailed = true;
        _errorMessage = e.toString();
        _statusMessage = 'Failed to start provisioning';
      });
    }
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
          title: const Text('Add Nodes'),
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
                value: _timeRemainingMs > 0
                    ? 1 - (_timeRemainingMs / (widget.durationMinutes * 60000))
                    : 0,
                strokeWidth: 8,
                backgroundColor: Colors.grey[300],
              ),
            ),
            Column(
              children: [
                Text(
                  _formatTime(_timeRemainingMs),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('remaining', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('🔍 Scanning for nodes...', style: TextStyle(fontSize: 18)),
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
          '✅ Provisioning Complete',
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
          '❌ Provisioning Failed',
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
                  label: 'Nodes Discovered',
                  value: _nodesDiscovered.toString(),
                  color: Colors.blue,
                ),
                if (_isActive)
                  _buildStatItem(
                    icon: Icons.timer,
                    label: 'Time Left',
                    value: _formatTime(_timeRemainingMs),
                    color: Colors.orange,
                  ),
              ],
            ),
            if (_nodesDiscovered > 0 && _isCompleted) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '🎉 $_nodesDiscovered new node${_nodesDiscovered > 1 ? 's' : ''} joined the network!',
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
            '💡 Turn on your nodes now',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gateway is broadcasting in fast discovery mode',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _stopProvisioning,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                'Stop Provisioning',
                style: TextStyle(fontSize: 16),
              ),
            ),
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
        child: const Text('Done', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  String _formatTime(int milliseconds) {
    final seconds = (milliseconds / 1000).ceil();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<bool?> _showStopConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Provisioning?'),
        content: const Text(
          'Provisioning is still in progress. Do you want to stop and go back?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}
