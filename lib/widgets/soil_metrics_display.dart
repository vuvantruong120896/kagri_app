import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../utils/soil_thresholds.dart';

/// Widget for displaying 7 soil parameters in a beautiful grid layout
/// Shows: Soil Moisture, Soil Temperature, pH, EC, N, P, K with color coding
class SoilMetricsDisplay extends StatelessWidget {
  final SensorData sensorData;
  final bool isCompact;

  const SoilMetricsDisplay({
    super.key,
    required this.sensorData,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Check if it's a soil sensor
    if (sensorData.deviceType != 'soil_sensor') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Thiết bị này không phải là soil sensor',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
      );
    }

    return isCompact ? _buildCompactView() : _buildFullView();
  }

  /// Compact view for home screen - 2x4 grid (2 rows, 4 columns)
  Widget _buildCompactView() {
    return Column(
      children: [
        // Row 1: Moisture, Temperature, pH, EC
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.water_drop,
                label: 'Độ ẩm đất',
                value: sensorData.soilMoisture?.toStringAsFixed(1) ?? 'N/A',
                unit: '%',
                color: SoilThresholds.getSoilMoistureColor(
                  sensorData.soilMoisture,
                ),
                status: SoilThresholds.getSoilMoistureStatus(
                  sensorData.soilMoisture,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.thermostat,
                label: 'Nhiệt độ đất',
                value: sensorData.soilTemperature?.toStringAsFixed(1) ?? 'N/A',
                unit: '°C',
                color: SoilThresholds.getSoilTemperatureColor(
                  sensorData.soilTemperature,
                ),
                status: SoilThresholds.getSoilTemperatureStatus(
                  sensorData.soilTemperature,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: pH, EC
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.science,
                label: 'pH',
                value: sensorData.pH?.toStringAsFixed(1) ?? 'N/A',
                unit: '',
                color: SoilThresholds.getPhColor(sensorData.pH),
                status: SoilThresholds.getPhStatus(sensorData.pH),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.electric_bolt,
                label: 'EC',
                value: sensorData.conductivity?.toStringAsFixed(2) ?? 'N/A',
                unit: 'µS/cm',
                color: SoilThresholds.getEcColor(sensorData.conductivity),
                status: SoilThresholds.getEcStatus(sensorData.conductivity),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 3: N, P, K
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.grass,
                label: 'N',
                value: sensorData.nitrogen?.toStringAsFixed(0) ?? 'N/A',
                unit: 'mg/kg',
                color: SoilThresholds.getNitrogenColor(sensorData.nitrogen),
                status: SoilThresholds.getNitrogenStatus(sensorData.nitrogen),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.spa,
                label: 'P',
                value: sensorData.phosphorus?.toStringAsFixed(0) ?? 'N/A',
                unit: 'mg/kg',
                color: SoilThresholds.getPhosphorusColor(sensorData.phosphorus),
                status: SoilThresholds.getPhosphorusStatus(
                  sensorData.phosphorus,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.eco,
                label: 'K',
                value: sensorData.potassium?.toStringAsFixed(0) ?? 'N/A',
                unit: 'mg/kg',
                color: SoilThresholds.getPotassiumColor(sensorData.potassium),
                status: SoilThresholds.getPotassiumStatus(sensorData.potassium),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Full view for detail screen - single column with larger cards
  Widget _buildFullView() {
    return Column(
      children: [
        _buildFullMetricCard(
          icon: Icons.water_drop,
          label: 'Độ ẩm đất (Soil Moisture)',
          value: sensorData.soilMoisture?.toStringAsFixed(1) ?? 'N/A',
          unit: '%',
          color: SoilThresholds.getSoilMoistureColor(sensorData.soilMoisture),
          status: SoilThresholds.getSoilMoistureStatus(sensorData.soilMoisture),
          optimalRange: '40-70%',
        ),
        const SizedBox(height: 12),
        _buildFullMetricCard(
          icon: Icons.thermostat,
          label: 'Nhiệt độ đất (Soil Temperature)',
          value: sensorData.soilTemperature?.toStringAsFixed(1) ?? 'N/A',
          unit: '°C',
          color: SoilThresholds.getSoilTemperatureColor(
            sensorData.soilTemperature,
          ),
          status: SoilThresholds.getSoilTemperatureStatus(
            sensorData.soilTemperature,
          ),
          optimalRange: '15-30°C',
        ),
        const SizedBox(height: 12),
        _buildFullMetricCard(
          icon: Icons.science,
          label: 'Độ pH',
          value: sensorData.pH?.toStringAsFixed(1) ?? 'N/A',
          unit: '',
          color: SoilThresholds.getPhColor(sensorData.pH),
          status: SoilThresholds.getPhStatus(sensorData.pH),
          optimalRange: '6.0-7.5',
        ),
        const SizedBox(height: 12),
        _buildFullMetricCard(
          icon: Icons.electric_bolt,
          label: 'Độ dẫn điện (EC)',
          value: sensorData.conductivity?.toStringAsFixed(2) ?? 'N/A',
          unit: 'µS/cm',
          color: SoilThresholds.getEcColor(sensorData.conductivity),
          status: SoilThresholds.getEcStatus(sensorData.conductivity),
          optimalRange: '1.0-3.0 µS/cm',
        ),
        const SizedBox(height: 12),
        _buildFullMetricCard(
          icon: Icons.grass,
          label: 'Nitơ (N)',
          value: sensorData.nitrogen?.toStringAsFixed(0) ?? 'N/A',
          unit: 'mg/kg',
          color: SoilThresholds.getNitrogenColor(sensorData.nitrogen),
          status: SoilThresholds.getNitrogenStatus(sensorData.nitrogen),
          optimalRange: '80-150 mg/kg',
        ),
        const SizedBox(height: 12),
        _buildFullMetricCard(
          icon: Icons.spa,
          label: 'Phospho (P)',
          value: sensorData.phosphorus?.toStringAsFixed(0) ?? 'N/A',
          unit: 'mg/kg',
          color: SoilThresholds.getPhosphorusColor(sensorData.phosphorus),
          status: SoilThresholds.getPhosphorusStatus(sensorData.phosphorus),
          optimalRange: '30-80 mg/kg',
        ),
        const SizedBox(height: 12),
        _buildFullMetricCard(
          icon: Icons.eco,
          label: 'Kali (K)',
          value: sensorData.potassium?.toStringAsFixed(0) ?? 'N/A',
          unit: 'mg/kg',
          color: SoilThresholds.getPotassiumColor(sensorData.potassium),
          status: SoilThresholds.getPotassiumStatus(sensorData.potassium),
          optimalRange: '120-200 mg/kg',
        ),
      ],
    );
  }

  /// Build compact metric card for grid view
  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty)
                Text(' $unit', style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build full metric card for detail view
  Widget _buildFullMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required String status,
    required String optimalRange,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ngưỡng tối ưu: $optimalRange',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  ' $unit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
