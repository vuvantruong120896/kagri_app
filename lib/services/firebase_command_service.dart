import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Service to send commands to Gateway via Firebase and listen for results
class FirebaseCommandService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  StreamSubscription? _resultSubscription;
  
  /// Send start provisioning command to Gateway
  /// 
  /// [userUID] - Current user's Firebase UID
  /// [gatewayMAC] - Gateway MAC address (e.g., "AA:BB:CC:DD:EE:FF")
  /// [durationMs] - Provisioning duration in milliseconds
  /// 
  /// Returns command ID for tracking
  Future<String> sendStartProvisioningCommand({
    required String userUID,
    required String gatewayMAC,
    required int durationMs,
  }) async {
    // Generate unique command ID
    final commandId = 'cmd-${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Create command data
    final commandData = {
      'id': commandId,
      'type': 'start_provisioning',
      'params': {
        'durationMs': durationMs,
      },
      'timestamp': timestamp,
      'priority': 5,
    };
    
    // Write to pending queue
    final commandPath = 'users/$userUID/commands/$gatewayMAC/pending/$commandId';
    await _database.child(commandPath).set(commandData);
    
    debugPrint('📤 Sent start_provisioning command: $commandId');
    return commandId;
  }
  
  /// Send stop provisioning command to Gateway
  Future<String> sendStopProvisioningCommand({
    required String userUID,
    required String gatewayMAC,
  }) async {
    final commandId = 'cmd-${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final commandData = {
      'id': commandId,
      'type': 'stop_provisioning',
      'params': {},
      'timestamp': timestamp,
      'priority': 10, // Higher priority to stop immediately
    };
    
    final commandPath = 'users/$userUID/commands/$gatewayMAC/pending/$commandId';
    await _database.child(commandPath).set(commandData);
    
    debugPrint('📤 Sent stop_provisioning command: $commandId');
    return commandId;
  }
  
  /// Listen to command results from Gateway
  /// 
  /// Returns a stream of command result updates
  Stream<CommandResult> listenToCommandResults({
    required String userUID,
    required String gatewayMAC,
  }) {
    final resultPath = 'users/$userUID/command_results/$gatewayMAC';
    
    return _database.child(resultPath).onValue.map((event) {
      if (event.snapshot.value == null) {
        return CommandResult(
          commandId: '',
          status: 'unknown',
          message: 'No data',
          gatewayOnline: false,
        );
      }
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      
      return CommandResult(
        commandId: data['last_command_id'] ?? '',
        commandType: data['last_command_type'] ?? '',
        status: data['status'] ?? 'unknown',
        message: data['message'] ?? '',
        timestamp: data['timestamp'] ?? 0,
        gatewayOnline: data['gateway_online'] ?? false,
        lastPoll: data['last_poll'] ?? 0,
        progress: data['progress'] != null
            ? ProvisioningProgress.fromMap(
                Map<String, dynamic>.from(data['progress'] as Map))
            : null,
        result: data['result'] != null
            ? Map<String, dynamic>.from(data['result'] as Map)
            : null,
      );
    });
  }
  
  /// Check if command is completed (moved to completed/ or failed/)
  Future<CommandStatus?> checkCommandStatus({
    required String userUID,
    required String gatewayMAC,
    required String commandId,
  }) async {
    // Check completed
    final completedPath = 'users/$userUID/commands/$gatewayMAC/completed/$commandId';
    final completedSnapshot = await _database.child(completedPath).get();
    
    if (completedSnapshot.exists) {
      final data = Map<String, dynamic>.from(completedSnapshot.value as Map);
      return CommandStatus(
        commandId: commandId,
        status: 'completed',
        result: data['result'] ?? 'success',
        message: data['message'] ?? '',
        completedAt: data['completedAt'] ?? 0,
        details: data['details'],
      );
    }
    
    // Check failed
    final failedPath = 'users/$userUID/commands/$gatewayMAC/failed/$commandId';
    final failedSnapshot = await _database.child(failedPath).get();
    
    if (failedSnapshot.exists) {
      final data = Map<String, dynamic>.from(failedSnapshot.value as Map);
      return CommandStatus(
        commandId: commandId,
        status: 'failed',
        result: 'failed',
        message: data['message'] ?? '',
        errorCode: data['errorCode'] ?? '',
        failedAt: data['failedAt'] ?? 0,
      );
    }
    
    // Check processing
    final processingPath = 'users/$userUID/commands/$gatewayMAC/processing/$commandId';
    final processingSnapshot = await _database.child(processingPath).get();
    
    if (processingSnapshot.exists) {
      return CommandStatus(
        commandId: commandId,
        status: 'processing',
        result: 'processing',
        message: 'Command is being executed',
      );
    }
    
    // Still pending or not found
    return null;
  }
  
  /// Cleanup old commands
  Future<void> cleanupOldCommands({
    required String userUID,
    required String gatewayMAC,
    int keepLastN = 10,
  }) async {
    // Get completed commands
    final completedPath = 'users/$userUID/commands/$gatewayMAC/completed';
    final completedSnapshot = await _database.child(completedPath).get();
    
    if (completedSnapshot.exists) {
      final commands = Map<String, dynamic>.from(completedSnapshot.value as Map);
      
      // Sort by timestamp (oldest first)
      final sortedKeys = commands.keys.toList()
        ..sort((a, b) {
          final aTime = (commands[a] as Map)['completedAt'] ?? 0;
          final bTime = (commands[b] as Map)['completedAt'] ?? 0;
          return (aTime as int).compareTo(bTime as int);
        });
      
      // Delete old commands (keep only last N)
      if (sortedKeys.length > keepLastN) {
        final toDelete = sortedKeys.take(sortedKeys.length - keepLastN);
        for (final key in toDelete) {
          await _database.child('$completedPath/$key').remove();
        }
        debugPrint('🧹 Cleaned up ${toDelete.length} old commands');
      }
    }
  }
  
  /// Cancel listening to results
  void dispose() {
    _resultSubscription?.cancel();
  }
}

/// Command result from Gateway (real-time updates)
class CommandResult {
  final String commandId;
  final String commandType;
  final String status; // processing, completed, failed
  final String message;
  final int timestamp;
  final bool gatewayOnline;
  final int lastPoll;
  final ProvisioningProgress? progress;
  final Map<String, dynamic>? result;
  
  CommandResult({
    required this.commandId,
    this.commandType = '',
    required this.status,
    required this.message,
    this.timestamp = 0,
    this.gatewayOnline = false,
    this.lastPoll = 0,
    this.progress,
    this.result,
  });
  
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}

/// Provisioning progress data
class ProvisioningProgress {
  final int nodesDiscovered;
  final int timeRemainingMs;
  
  ProvisioningProgress({
    required this.nodesDiscovered,
    required this.timeRemainingMs,
  });
  
  factory ProvisioningProgress.fromMap(Map<String, dynamic> map) {
    return ProvisioningProgress(
      nodesDiscovered: map['nodes_discovered'] ?? 0,
      timeRemainingMs: map['time_remaining_ms'] ?? 0,
    );
  }
  
  int get timeRemainingSec => (timeRemainingMs / 1000).ceil();
  
  String get timeRemainingFormatted {
    final seconds = timeRemainingSec;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// Command final status (from completed/failed paths)
class CommandStatus {
  final String commandId;
  final String status;
  final String result;
  final String message;
  final String? errorCode;
  final int? completedAt;
  final int? failedAt;
  final dynamic details;
  
  CommandStatus({
    required this.commandId,
    required this.status,
    required this.result,
    required this.message,
    this.errorCode,
    this.completedAt,
    this.failedAt,
    this.details,
  });
  
  bool get isSuccess => result == 'success';
}
