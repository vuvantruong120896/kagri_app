import 'package:flutter/material.dart';

/// Error dialog with retry option
///
/// Usage:
/// ```dart
/// showErrorDialogWidget(
///   context: context,
///   title: 'Firebase Error',
///   message: 'Failed to fetch data from Firebase',
///   onRetry: () => refetchData(),
/// )
/// ```
void showErrorDialogWidget({
  required BuildContext context,
  required String title,
  required String message,
  String? errorDetails,
  VoidCallback? onRetry,
  String? retryLabel,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.error_outline, color: Colors.red[600], size: 32),
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            if (errorDetails != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  errorDetails,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        if (onRetry != null)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            child: Text(retryLabel ?? 'Thử lại'),
          ),
      ],
    ),
  );
}

/// Info dialog
void showInfoDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.info_outline, color: Colors.blue[600], size: 32),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
        if (onAction != null && actionLabel != null)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onAction();
            },
            child: Text(actionLabel),
          ),
      ],
    ),
  );
}

/// Success dialog
void showSuccessDialog({
  required BuildContext context,
  required String title,
  required String message,
  VoidCallback? onDismiss,
  Duration? autoCloseDuration,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        Icons.check_circle_outline,
        color: Colors.green[600],
        size: 32,
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onDismiss?.call();
          },
          child: const Text('OK'),
        ),
      ],
    ),
  ).then((_) {
    onDismiss?.call();
  });

  if (autoCloseDuration != null) {
    Future.delayed(autoCloseDuration, () {
      if (context.mounted) {
        Navigator.pop(context);
        onDismiss?.call();
      }
    });
  }
}

/// Confirmation dialog
Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  Color? confirmButtonColor,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.help_outline, color: Colors.orange[600], size: 32),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel ?? 'Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmButtonColor ?? Colors.red,
          ),
          child: Text(confirmLabel ?? 'Xác nhận'),
        ),
      ],
    ),
  );
}

/// Snackbar with custom styling
void showSnackbar({
  required BuildContext context,
  required String message,
  SnackbarType type = SnackbarType.info,
  Duration duration = const Duration(seconds: 4),
  VoidCallback? onAction,
  String? actionLabel,
}) {
  final colors = {
    SnackbarType.success: Colors.green,
    SnackbarType.error: Colors.red,
    SnackbarType.warning: Colors.orange,
    SnackbarType.info: Colors.blue,
  };

  final icons = {
    SnackbarType.success: Icons.check_circle_outline,
    SnackbarType.error: Icons.error_outline,
    SnackbarType.warning: Icons.warning_amber,
    SnackbarType.info: Icons.info_outline,
  };

  final color = colors[type];
  final icon = icons[type];

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: color,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
      action: onAction != null && actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction,
            )
          : null,
    ),
  );
}

enum SnackbarType { success, error, warning, info }

/// Toast-like notification (simpler snackbar)
void showToast({
  required BuildContext context,
  required String message,
  ToastType type = ToastType.info,
  Duration duration = const Duration(seconds: 2),
}) {
  showSnackbar(
    context: context,
    message: message,
    type: SnackbarType.values[type.index],
    duration: duration,
  );
}

enum ToastType { success, error, warning, info }

/// Error handler wrapper for async operations
Future<T?> handleAsync<T>({
  required BuildContext context,
  required Future<T> Function() operation,
  String? loadingMessage,
  String? successMessage,
  String? errorTitle,
  bool showSuccessMessage = true,
  bool showErrorDialog = true,
  bool showLoadingDialog = true,
}) async {
  try {
    if (showLoadingDialog) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(child: Text(loadingMessage ?? 'Đang xử lý...')),
              ],
            ),
          ),
        ),
      );
    }

    final result = await operation();

    if (showLoadingDialog && context.mounted) {
      Navigator.pop(context);
    }

    if (showSuccessMessage && successMessage != null && context.mounted) {
      showToast(
        context: context,
        message: successMessage,
        type: ToastType.success,
      );
    }

    return result;
  } catch (e) {
    if (showLoadingDialog && context.mounted) {
      Navigator.pop(context);
    }

    if (showErrorDialog && context.mounted) {
      showErrorDialogWidget(
        context: context,
        title: errorTitle ?? 'Lỗi',
        message: e.toString(),
      );
    } else if (context.mounted) {
      showToast(context: context, message: e.toString(), type: ToastType.error);
    }

    return null;
  }
}

/// Result wrapper for better error handling
class Result<T> {
  final T? data;
  final String? error;
  final StackTrace? stackTrace;

  Result.success(this.data) : error = null, stackTrace = null;
  Result.error(this.error, [this.stackTrace]) : data = null;

  bool get isSuccess => error == null;
  bool get isError => error != null;

  Future<R> mapResult<R>({
    required Future<R> Function(T) onSuccess,
    required Future<R> Function(String) onError,
  }) async {
    if (isSuccess) {
      return onSuccess(data as T);
    } else {
      return onError(error!);
    }
  }

  T? getOrNull() => data;

  T getOrThrow() {
    if (isSuccess) return data as T;
    throw Exception(error);
  }
}

/// Firebase error handler
String handleFirebaseError(dynamic error) {
  final errorString = error.toString().toLowerCase();

  if (errorString.contains('permission-denied')) {
    return 'Bạn không có quyền truy cập tài nguyên này';
  } else if (errorString.contains('not-found')) {
    return 'Không tìm thấy dữ liệu yêu cầu';
  } else if (errorString.contains('network-error') ||
      errorString.contains('failed')) {
    return 'Lỗi kết nối mạng. Vui lòng kiểm tra internet';
  } else if (errorString.contains('authentication')) {
    return 'Lỗi xác thực. Vui lòng đăng nhập lại';
  } else if (errorString.contains('invalid-argument')) {
    return 'Dữ liệu không hợp lệ';
  } else if (errorString.contains('unauthenticated')) {
    return 'Bạn cần đăng nhập để tiếp tục';
  } else if (errorString.contains('deadline-exceeded')) {
    return 'Yêu cầu quá lâu. Vui lòng thử lại';
  } else {
    return 'Có lỗi xảy ra: $error';
  }
}

/// BLE error handler
String handleBLEError(dynamic error) {
  final errorString = error.toString().toLowerCase();

  if (errorString.contains('bluetooth is not available')) {
    return 'Thiết bị không hỗ trợ Bluetooth';
  } else if (errorString.contains('bluetooth is not turned on')) {
    return 'Vui lòng bật Bluetooth';
  } else if (errorString.contains('location permission')) {
    return 'Ứng dụng cần quyền vị trí để quét Bluetooth';
  } else if (errorString.contains('connection failed')) {
    return 'Không thể kết nối với thiết bị. Vui lòng thử lại';
  } else if (errorString.contains('disconnected')) {
    return 'Thiết bị đã bị ngắt kết nối';
  } else if (errorString.contains('timeout')) {
    return 'Kết nối hết thời gian chờ';
  } else {
    return 'Lỗi Bluetooth: $error';
  }
}
