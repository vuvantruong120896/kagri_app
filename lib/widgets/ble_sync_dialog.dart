import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_sync_service.dart';
import '../utils/constants.dart';

/// BLE Sync Dialog (Phase 2B)
/// Shows long-press menu and initiates sync operation
class BleSyncDialog extends StatefulWidget {
  final BluetoothDevice device;
  final String deviceName;
  final Function(List<Map<String, dynamic>> data) onSyncComplete;

  const BleSyncDialog({
    super.key,
    required this.device,
    required this.deviceName,
    required this.onSyncComplete,
  });

  @override
  State<BleSyncDialog> createState() => _BleSyncDialogState();
}

class _BleSyncDialogState extends State<BleSyncDialog> {
  late BleSyncService _syncService;
  bool _isLoading = false;
  String _status = '';
  int _progressCurrent = 0;
  int _progressTotal = 0;
  List<Map<String, dynamic>> _syncedData = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncService = BleSyncService();
  }

  Future<void> _startSync() async {
    setState(() {
      _isLoading = true;
      _status = 'Khởi tạo BLE Sync...';
      _error = null;
      _progressCurrent = 0;
      _progressTotal = 0;
      _syncedData.clear();
    });

    try {
      // Initialize BLE sync service
      print('[BleSyncDialog] Initializing BLE sync service...');
      final initialized = await _syncService.initialize(widget.device);

      if (!initialized) {
        setState(() {
          _error = 'Không thể khởi tạo BLE Sync Service';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _status = 'Gửi lệnh PING...';
      });

      // Send PING to get buffered data count
      final bufferedCount = await _syncService.ping();

      if (bufferedCount == null) {
        setState(() {
          _error = 'Không thể kết nối với gateway';
          _isLoading = false;
        });
        return;
      }

      if (bufferedCount == 0) {
        setState(() {
          _status = '✅ Không có dữ liệu mới';
          _isLoading = false;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
        return;
      }

      setState(() {
        _status = 'Tải dữ liệu ($bufferedCount items)...';
        _progressTotal = bufferedCount;
      });

      // Fetch data with pagination
      await for (final data in _syncService.fetchBufferedData(
        totalItems: bufferedCount,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _progressCurrent = current;
              _progressTotal = total;
              _status = 'Tải dữ liệu ($current/$total items)...';
            });
          }
        },
      )) {
        _syncedData = data;
      }

      if (_syncedData.isEmpty) {
        setState(() {
          _error = 'Không tải được dữ liệu';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _status = 'Xóa bộ đệm gateway...';
      });

      // Clear buffer after successful sync
      final cleared = await _syncService.clearBuffer(
        ackCount: _syncedData.length,
      );

      if (!cleared) {
        print(
          '[BleSyncDialog] ⚠️ Warning: Buffer clear failed, but data was synced',
        );
      }

      setState(() {
        _status = '✅ Đồng bộ thành công: ${_syncedData.length} items';
        _isLoading = false;
      });

      // Callback with synced data
      widget.onSyncComplete(_syncedData);

      // Close dialog after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      print('[BleSyncDialog] Error: $e');
      setState(() {
        _error = 'Lỗi: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text('BLE Offline Sync', style: AppTextStyles.heading2),
            const SizedBox(height: AppSizes.paddingSmall),
            Text(
              'Thiết bị: ${widget.deviceName}',
              style: AppTextStyles.body2.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: AppSizes.paddingLarge),

            // Status/Progress Section
            if (_isLoading)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Loading Indicator
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingMedium),

                  // Status Text
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body1,
                  ),
                  const SizedBox(height: AppSizes.paddingMedium),

                  // Progress Bar (if applicable)
                  if (_progressTotal > 0)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _progressCurrent / _progressTotal,
                            minHeight: 6,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.paddingSmall),
                        Text(
                          '${_progressCurrent} / ${_progressTotal} items',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                ],
              )
            else if (_error != null)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: AppSizes.paddingMedium),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body1.copyWith(color: Colors.red),
                  ),
                ],
              )
            else if (_status.contains('✅'))
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 40),
                  const SizedBox(height: AppSizes.paddingMedium),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body1.copyWith(color: Colors.green),
                  ),
                ],
              )
            else
              // Initial state - show menu options
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Chọn tác vụ:', style: AppTextStyles.body1),
                  const SizedBox(height: AppSizes.paddingLarge),

                  // Sync Data Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _startSync,
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Đồng bộ dữ liệu offline'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.paddingMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingSmall),

                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
