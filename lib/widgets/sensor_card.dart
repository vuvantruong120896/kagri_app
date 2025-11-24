import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class SensorCard extends StatelessWidget {
  final SensorData sensorData;
  final VoidCallback? onTap;

  const SensorCard({super.key, required this.sensorData, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.marginMedium,
        vertical: AppSizes.marginSmall,
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with device info and timestamp
              Row(
                children: [
                  Icon(
                    _getIconForDeviceType(),
                    color: AppColors.primary,
                    size: AppSizes.iconMedium,
                  ),
                  const SizedBox(width: AppSizes.paddingSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sensorData.nodeId, style: AppTextStyles.heading3),
                        Text(
                          'Type: ${sensorData.deviceType} | Counter: ${sensorData.counter}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatTime(sensorData.timestamp),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.paddingMedium),

              // Temperature and Humidity values
              Row(
                children: [
                  Expanded(
                    child: _buildSensorValue(
                      icon: _getIconForPrimaryValue(),
                      label: _getLabelForPrimaryValue(),
                      value: _getDisplayTextForPrimaryValue(),
                      color: _getColorForPrimaryValue(),
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingMedium),
                  Expanded(
                    child: _buildSensorValue(
                      icon: _getIconForSecondaryValue(),
                      label: _getLabelForSecondaryValue(),
                      value: _getDisplayTextForSecondaryValue(),
                      color: _getColorForSecondaryValue(),
                    ),
                  ),
                ],
              ),

              // Additional soil parameters (if soil sensor)
              if (sensorData.deviceType == 'soil_sensor' &&
                  (sensorData.pH != null ||
                      sensorData.conductivity != null ||
                      sensorData.nitrogen != null)) ...[
                const SizedBox(height: AppSizes.paddingSmall),
                Row(
                  children: [
                    if (sensorData.pH != null)
                      Expanded(
                        child: _buildCompactValue(
                          '⚗️ pH',
                          sensorData.pH!.toStringAsFixed(1),
                        ),
                      ),
                    if (sensorData.conductivity != null)
                      Expanded(
                        child: _buildCompactValue(
                          '⚡ EC',
                          '${sensorData.conductivity!.toStringAsFixed(1)} mS/cm',
                        ),
                      ),
                    if (sensorData.nitrogen != null)
                      Expanded(
                        child: _buildCompactValue(
                          'N',
                          '${sensorData.nitrogen!.toStringAsFixed(0)}',
                        ),
                      ),
                  ],
                ),
              ],

              // Additional info - Battery and Signal
              const SizedBox(height: AppSizes.paddingMedium),
              Row(
                children: [
                  // Battery info
                  Icon(
                    _getBatteryIcon(sensorData.batteryPercentage),
                    color: _getBatteryColor(sensorData.batteryPercentage),
                    size: AppSizes.iconSmall,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${sensorData.battery.toStringAsFixed(2)}V (${sensorData.batteryPercentage.toStringAsFixed(0)}%)',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(width: AppSizes.paddingMedium),
                  // Signal info (RSSI)
                  if (sensorData.rssi != null) ...[
                    Icon(
                      _getSignalIcon(sensorData.rssi!),
                      color: _getSignalColor(sensorData.rssi!),
                      size: AppSizes.iconSmall,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${sensorData.rssi} dBm',
                      style: AppTextStyles.caption,
                    ),
                  ],
                  // SNR info
                  if (sensorData.snr != null) ...[
                    const SizedBox(width: AppSizes.paddingSmall),
                    Text(
                      'SNR: ${sensorData.snr!.toStringAsFixed(1)} dB',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorValue({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: AppSizes.iconLarge),
        const SizedBox(height: AppSizes.paddingSmall),
        Text(value, style: AppTextStyles.sensorValue.copyWith(color: color)),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else {
      return DateFormat('dd/MM HH:mm').format(dateTime);
    }
  }

  Color _getTemperatureColor(double temperature) {
    if (temperature < AppConstants.temperatureWarningLow) {
      return AppColors.temperatureCold;
    } else if (temperature > AppConstants.temperatureWarningHigh) {
      return AppColors.temperatureHot;
    } else {
      return AppColors.temperatureNormal;
    }
  }

  Color _getHumidityColor(double humidity) {
    if (humidity < AppConstants.humidityWarningLow) {
      return AppColors.humidityLow;
    } else if (humidity > AppConstants.humidityWarningHigh) {
      return AppColors.humidityHigh;
    } else {
      return AppColors.humidityNormal;
    }
  }

  IconData _getBatteryIcon(double batteryLevel) {
    if (batteryLevel > 80) return Icons.battery_full;
    if (batteryLevel > 60) return Icons.battery_5_bar;
    if (batteryLevel > 40) return Icons.battery_4_bar;
    if (batteryLevel > 20) return Icons.battery_3_bar;
    if (batteryLevel > 10) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  Color _getBatteryColor(double batteryLevel) {
    if (batteryLevel > AppConstants.batteryLowThreshold) {
      return AppColors.online;
    } else if (batteryLevel > AppConstants.batteryCriticalThreshold) {
      return AppColors.warning;
    } else {
      return AppColors.danger;
    }
  }

  // RSSI signal strength (dBm scale: -40 to -100)
  // -40 to -60: Excellent
  // -60 to -70: Good
  // -70 to -80: Fair
  // -80+: Poor
  IconData _getSignalIcon(int rssi) {
    if (rssi > -60) return Icons.signal_cellular_4_bar;
    if (rssi > -70) return Icons.network_cell;
    if (rssi > -80) return Icons.signal_cellular_connected_no_internet_0_bar;
    return Icons.signal_cellular_0_bar;
  }

  Color _getSignalColor(int rssi) {
    if (rssi > -60) return AppColors.online;
    if (rssi > -80) return AppColors.warning;
    return AppColors.danger;
  }

  /// Get icon based on device type
  IconData _getIconForDeviceType() {
    switch (sensorData.deviceType) {
      case 'soil_sensor':
        return Icons.eco;
      case 'environment':
        return Icons.cloud;
      case 'water_sensor':
        return Icons.water;
      default:
        return Icons.sensors;
    }
  }

  /// Get primary value display based on sensor type
  IconData _getIconForPrimaryValue() {
    switch (sensorData.deviceType) {
      case 'soil_sensor':
        return Icons.water_drop;
      case 'environment':
      case 'water_sensor':
      default:
        return Icons.thermostat;
    }
  }

  String _getLabelForPrimaryValue() {
    switch (sensorData.deviceType) {
      case 'soil_sensor':
        return 'Độ ẩm đất';
      case 'environment':
      case 'water_sensor':
      default:
        return 'Nhiệt độ';
    }
  }

  String _getDisplayTextForPrimaryValue() {
    switch (sensorData.deviceType) {
      case 'soil_sensor':
        return sensorData.soilMoisture != null
            ? '${sensorData.soilMoisture!.toStringAsFixed(1)}%'
            : 'N/A';
      case 'environment':
        return sensorData.temperature != null
            ? '${sensorData.temperature!.toStringAsFixed(1)}°C'
            : 'N/A';
      case 'water_sensor':
        return sensorData.waterTemp != null
            ? '${sensorData.waterTemp!.toStringAsFixed(1)}°C'
            : 'N/A';
      default:
        return 'N/A';
    }
  }

  Color _getColorForPrimaryValue() {
    switch (sensorData.deviceType) {
      case 'soil_sensor':
        final moisture = sensorData.soilMoisture ?? 0;
        if (moisture < 20) return Colors.red;
        if (moisture < 40) return Colors.orange;
        if (moisture < 60) return Colors.green;
        if (moisture < 80) return Colors.lightBlue;
        return Colors.blue;
      case 'environment':
      case 'water_sensor':
      default:
        final temp = sensorData.temperature ?? sensorData.waterTemp ?? 25;
        if (temp < 10) return Colors.blue;
        if (temp < 20) return Colors.cyan;
        if (temp < 30) return Colors.green;
        if (temp < 40) return Colors.orange;
        return Colors.red;
    }
  }

  IconData _getIconForSecondaryValue() {
    switch (sensorData.deviceType) {
      case 'soil_sensor':
        return Icons.thermostat;
      case 'environment':
        return Icons.water_drop;
      case 'water_sensor':
        return Icons.science;
      default:
        return Icons.info;
    }
  }

  String _getLabelForSecondaryValue() {
    switch (sensorData.deviceType) {
      case 'soil_sensor':
        return 'Nhiệt độ';
      case 'environment':
        return 'Độ ẩm';
      case 'water_sensor':
        return 'pH';
      default:
        return 'Dữ liệu';
    }
  }

  String _getDisplayTextForSecondaryValue() {
    switch (sensorData.deviceType) {
      case 'soil_sensor':
        return sensorData.soilTemperature != null
            ? '${sensorData.soilTemperature!.toStringAsFixed(1)}°C'
            : 'N/A';
      case 'environment':
        return sensorData.humidity != null
            ? '${sensorData.humidity!.toStringAsFixed(1)}%'
            : 'N/A';
      case 'water_sensor':
        return sensorData.pH != null
            ? '${sensorData.pH!.toStringAsFixed(1)}'
            : 'N/A';
      default:
        return 'N/A';
    }
  }

  Color _getColorForSecondaryValue() {
    switch (sensorData.deviceType) {
      case 'soil_sensor':
        return Colors.orange;
      case 'environment':
        final humidity = sensorData.humidity ?? 50;
        if (humidity < 30) return Colors.orange;
        if (humidity < 70) return Colors.green;
        return Colors.blue;
      case 'water_sensor':
        final pH = sensorData.pH ?? 7;
        if (pH < 6) return Colors.orange;
        if (pH < 8) return Colors.green;
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCompactValue(String label, String value) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.body2.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
