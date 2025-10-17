import 'package:flutter/material.dart';

class AppConstants {
  // Firebase Database Paths (matching firmware schema)
  static const String nodesPath = 'nodes';
  static const String sensorDataPath = 'sensor_data';
  static const String gatewaysPath = 'gateways';

  // Legacy paths (deprecated, use above instead)
  static const String devicesCollection = 'devices';
  static const String sensorDataCollection = 'sensor_data';
  static const String realtimeDataPath = 'sensor_readings';

  // Refresh intervals
  static const Duration dataRefreshInterval = Duration(seconds: 30);
  static const Duration deviceStatusCheckInterval = Duration(minutes: 1);

  // Chart settings
  static const int maxChartDataPoints = 50;
  static const Duration defaultChartTimeRange = Duration(hours: 24);

  // Temperature and humidity thresholds
  static const double temperatureMin = -40.0;
  static const double temperatureMax = 100.0;
  static const double humidityMin = 0.0;
  static const double humidityMax = 100.0;

  // Temperature warning thresholds
  static const double temperatureWarningLow = 5.0;
  static const double temperatureWarningHigh = 35.0;

  // Humidity warning thresholds
  static const double humidityWarningLow = 30.0;
  static const double humidityWarningHigh = 80.0;

  // Battery level thresholds
  static const double batteryLowThreshold = 20.0;
  static const double batteryCriticalThreshold = 10.0;
}

class AppColors {
  // Primary colors
  static const Color primary = Colors.blue;
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color accent = Colors.orange;

  // Status colors
  static const Color online = Colors.green;
  static const Color offline = Colors.red;
  static const Color warning = Colors.orange;
  static const Color danger = Colors.red;

  // Temperature colors
  static const Color temperatureCold = Colors.blue;
  static const Color temperatureNormal = Colors.green;
  static const Color temperatureHot = Colors.red;

  // Humidity colors
  static const Color humidityLow = Colors.orange;
  static const Color humidityNormal = Colors.blue;
  static const Color humidityHigh = Colors.purple;

  // Chart colors
  static const List<Color> chartColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCardBackground = Color(0xFF1E1E1E);
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body1 = TextStyle(fontSize: 16);

  static const TextStyle body2 = TextStyle(fontSize: 14);

  static const TextStyle caption = TextStyle(fontSize: 12, color: Colors.grey);

  static const TextStyle sensorValue = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle sensorUnit = TextStyle(
    fontSize: 16,
    color: Colors.grey,
  );
}

class AppSizes {
  // Padding
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Margins
  static const double marginSmall = 8.0;
  static const double marginMedium = 16.0;
  static const double marginLarge = 24.0;

  // Border radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 16.0;

  // Icon sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;

  // Card sizes
  static const double cardHeight = 120.0;
  static const double chartCardHeight = 250.0;
}
