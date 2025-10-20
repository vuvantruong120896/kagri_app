import 'package:flutter/material.dart';

/// Soil parameter thresholds and color coding for optimal agriculture
/// Based on standard agricultural guidelines
class SoilThresholds {
  // ===== Soil Moisture Thresholds (%) =====
  static const double soilMoistureLow = 30.0;
  static const double soilMoistureOptimalMin = 40.0;
  static const double soilMoistureOptimalMax = 70.0;
  static const double soilMoistureHigh = 80.0;

  // ===== Soil Temperature Thresholds (°C) =====
  static const double soilTempLow = 10.0;
  static const double soilTempOptimalMin = 15.0;
  static const double soilTempOptimalMax = 30.0;
  static const double soilTempHigh = 35.0;

  // ===== pH Thresholds =====
  static const double phAcidic = 5.5;
  static const double phOptimalMin = 6.0;
  static const double phOptimalMax = 7.5;
  static const double phAlkaline = 8.0;

  // ===== EC (Electrical Conductivity) Thresholds (mS/cm) =====
  static const double ecLow = 0.5;
  static const double ecOptimalMin = 1.0;
  static const double ecOptimalMax = 3.0;
  static const double ecHigh = 4.0;

  // ===== Nitrogen (N) Thresholds (mg/kg) =====
  static const double nitrogenLow = 50.0;
  static const double nitrogenOptimalMin = 80.0;
  static const double nitrogenOptimalMax = 150.0;
  static const double nitrogenHigh = 200.0;

  // ===== Phosphorus (P) Thresholds (mg/kg) =====
  static const double phosphorusLow = 20.0;
  static const double phosphorusOptimalMin = 30.0;
  static const double phosphorusOptimalMax = 80.0;
  static const double phosphorusHigh = 120.0;

  // ===== Potassium (K) Thresholds (mg/kg) =====
  static const double potassiumLow = 80.0;
  static const double potassiumOptimalMin = 120.0;
  static const double potassiumOptimalMax = 200.0;
  static const double potassiumHigh = 250.0;

  // ===== Color Coding =====
  static const Color colorCritical = Color(0xFFD32F2F); // Red
  static const Color colorWarning = Color(0xFFF57C00); // Orange
  static const Color colorOptimal = Color(0xFF388E3C); // Green
  static const Color colorGood = Color(0xFF1976D2); // Blue
  static const Color colorNeutral = Color(0xFF757575); // Grey

  /// Get color for soil moisture value
  static Color getSoilMoistureColor(double? value) {
    if (value == null) return colorNeutral;
    if (value < soilMoistureLow) return colorCritical;
    if (value < soilMoistureOptimalMin) return colorWarning;
    if (value <= soilMoistureOptimalMax) return colorOptimal;
    if (value <= soilMoistureHigh) return colorWarning;
    return colorCritical;
  }

  /// Get color for soil temperature value
  static Color getSoilTemperatureColor(double? value) {
    if (value == null) return colorNeutral;
    if (value < soilTempLow) return colorCritical;
    if (value < soilTempOptimalMin) return colorWarning;
    if (value <= soilTempOptimalMax) return colorOptimal;
    if (value <= soilTempHigh) return colorWarning;
    return colorCritical;
  }

  /// Get color for pH value
  static Color getPhColor(double? value) {
    if (value == null) return colorNeutral;
    if (value < phAcidic) return colorCritical;
    if (value < phOptimalMin) return colorWarning;
    if (value <= phOptimalMax) return colorOptimal;
    if (value <= phAlkaline) return colorWarning;
    return colorCritical;
  }

  /// Get color for EC value
  static Color getEcColor(double? value) {
    if (value == null) return colorNeutral;
    if (value < ecLow) return colorWarning;
    if (value < ecOptimalMin) return colorGood;
    if (value <= ecOptimalMax) return colorOptimal;
    if (value <= ecHigh) return colorWarning;
    return colorCritical;
  }

  /// Get color for Nitrogen value
  static Color getNitrogenColor(double? value) {
    if (value == null) return colorNeutral;
    if (value < nitrogenLow) return colorCritical;
    if (value < nitrogenOptimalMin) return colorWarning;
    if (value <= nitrogenOptimalMax) return colorOptimal;
    if (value <= nitrogenHigh) return colorGood;
    return colorWarning;
  }

  /// Get color for Phosphorus value
  static Color getPhosphorusColor(double? value) {
    if (value == null) return colorNeutral;
    if (value < phosphorusLow) return colorCritical;
    if (value < phosphorusOptimalMin) return colorWarning;
    if (value <= phosphorusOptimalMax) return colorOptimal;
    if (value <= phosphorusHigh) return colorGood;
    return colorWarning;
  }

  /// Get color for Potassium value
  static Color getPotassiumColor(double? value) {
    if (value == null) return colorNeutral;
    if (value < potassiumLow) return colorCritical;
    if (value < potassiumOptimalMin) return colorWarning;
    if (value <= potassiumOptimalMax) return colorOptimal;
    if (value <= potassiumHigh) return colorGood;
    return colorWarning;
  }

  /// Get status text for soil moisture
  static String getSoilMoistureStatus(double? value) {
    if (value == null) return 'N/A';
    if (value < soilMoistureLow) return 'Rất khô';
    if (value < soilMoistureOptimalMin) return 'Khô';
    if (value <= soilMoistureOptimalMax) return 'Tối ưu';
    if (value <= soilMoistureHigh) return 'Ẩm';
    return 'Rất ẩm';
  }

  /// Get status text for soil temperature
  static String getSoilTemperatureStatus(double? value) {
    if (value == null) return 'N/A';
    if (value < soilTempLow) return 'Quá lạnh';
    if (value < soilTempOptimalMin) return 'Lạnh';
    if (value <= soilTempOptimalMax) return 'Tối ưu';
    if (value <= soilTempHigh) return 'Nóng';
    return 'Quá nóng';
  }

  /// Get status text for pH
  static String getPhStatus(double? value) {
    if (value == null) return 'N/A';
    if (value < phAcidic) return 'Quá chua';
    if (value < phOptimalMin) return 'Chua';
    if (value <= phOptimalMax) return 'Tối ưu';
    if (value <= phAlkaline) return 'Kiềm';
    return 'Quá kiềm';
  }

  /// Get status text for EC
  static String getEcStatus(double? value) {
    if (value == null) return 'N/A';
    if (value < ecLow) return 'Rất thấp';
    if (value < ecOptimalMin) return 'Thấp';
    if (value <= ecOptimalMax) return 'Tối ưu';
    if (value <= ecHigh) return 'Cao';
    return 'Quá cao';
  }

  /// Get status text for Nitrogen
  static String getNitrogenStatus(double? value) {
    if (value == null) return 'N/A';
    if (value < nitrogenLow) return 'Thiếu hụt';
    if (value < nitrogenOptimalMin) return 'Thấp';
    if (value <= nitrogenOptimalMax) return 'Tối ưu';
    if (value <= nitrogenHigh) return 'Tốt';
    return 'Cao';
  }

  /// Get status text for Phosphorus
  static String getPhosphorusStatus(double? value) {
    if (value == null) return 'N/A';
    if (value < phosphorusLow) return 'Thiếu hụt';
    if (value < phosphorusOptimalMin) return 'Thấp';
    if (value <= phosphorusOptimalMax) return 'Tối ưu';
    if (value <= phosphorusHigh) return 'Tốt';
    return 'Cao';
  }

  /// Get status text for Potassium
  static String getPotassiumStatus(double? value) {
    if (value == null) return 'N/A';
    if (value < potassiumLow) return 'Thiếu hụt';
    if (value < potassiumOptimalMin) return 'Thấp';
    if (value <= potassiumOptimalMax) return 'Tối ưu';
    if (value <= potassiumHigh) return 'Tốt';
    return 'Cao';
  }
}
