import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

/// Widget to display soil sensor data with all 7 parameters
/// Used in device_chart_screen and detailed views
class SoilSensorCardDetail extends StatelessWidget {
  final SensorData sensorData;
  final VoidCallback? onRefresh;

  const SoilSensorCardDetail({
    super.key,
    required this.sensorData,
    this.onRefresh,
  });

  /// Get color based on soil moisture level
  Color _getMoistureColor(double? moisture) {
    if (moisture == null) return Colors.grey;
    if (moisture < 20) return Colors.red; // Too dry
    if (moisture < 40) return Colors.orange; // Slightly dry
    if (moisture < 60) return Colors.green; // Optimal
    if (moisture < 80) return Colors.lightBlue; // Wet
    return Colors.blue; // Too wet
  }

  /// Get color based on pH level
  Color _getPhColor(double? pH) {
    if (pH == null) return Colors.grey;
    if (pH < 6) return Colors.orange; // Too acidic
    if (pH < 8) return Colors.green; // Optimal (6-7)
    return Colors.blue; // Too alkaline
  }

  /// Get color based on EC (electrical conductivity)
  Color _getECColor(double? ec) {
    if (ec == null) return Colors.grey;
    if (ec < 0.5) return Colors.red; // Too low
    if (ec < 2.0) return Colors.green; // Optimal
    if (ec < 4.0) return Colors.orange; // High
    return Colors.red; // Too high
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with device info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🌱 Soil Sensor Data',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Node: ${sensorData.nodeId} | Battery: ${sensorData.battery.toStringAsFixed(2)}V',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Divider(),

          // Main sensor parameters in grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Soil Moisture
                _buildParameterCard(
                  context,
                  icon: '💧',
                  label: 'Soil Moisture',
                  value: sensorData.soilMoisture,
                  unit: '%',
                  color: _getMoistureColor(sensorData.soilMoisture),
                  optimal: '40-60%',
                ),
                // Soil Temperature
                _buildParameterCard(
                  context,
                  icon: '🌡️',
                  label: 'Temperature',
                  value: sensorData.soilTemperature,
                  unit: '°C',
                  color: Colors.orange,
                  optimal: '18-30°C',
                ),
                // pH Level
                _buildParameterCard(
                  context,
                  icon: '⚗️',
                  label: 'pH Level',
                  value: sensorData.pH,
                  unit: '',
                  color: _getPhColor(sensorData.pH),
                  optimal: '6.0-7.0',
                ),
                // EC (Electrical Conductivity)
                _buildParameterCard(
                  context,
                  icon: '⚡',
                  label: 'EC',
                  value: sensorData.ec,
                  unit: 'mS/cm',
                  color: _getECColor(sensorData.ec),
                  optimal: '0.5-2.0',
                ),
                // Nitrogen
                _buildParameterCard(
                  context,
                  icon: 'N',
                  label: 'Nitrogen',
                  value: sensorData.nitrogen,
                  unit: 'mg/kg',
                  color: Colors.green,
                  optimal: '50-200',
                ),
                // Phosphorus
                _buildParameterCard(
                  context,
                  icon: 'P',
                  label: 'Phosphorus',
                  value: sensorData.phosphorus,
                  unit: 'mg/kg',
                  color: Colors.purple,
                  optimal: '20-100',
                ),
                // Potassium
                _buildParameterCard(
                  context,
                  icon: 'K',
                  label: 'Potassium',
                  value: sensorData.potassium,
                  unit: 'mg/kg',
                  color: Colors.red,
                  optimal: '100-300',
                ),
                // Battery Status
                _buildParameterCard(
                  context,
                  icon: '🔋',
                  label: 'Battery',
                  value: sensorData.battery,
                  unit: 'V',
                  color: sensorData.battery > 3.5 ? Colors.green : Colors.red,
                  optional: true,
                ),
              ],
            ),
          ),
          const Divider(),

          // NPK Summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NPK Nutrients',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildNPKBar(
                        'N',
                        sensorData.nitrogen ?? 0,
                        300,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNPKBar(
                        'P',
                        sensorData.phosphorus ?? 0,
                        200,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNPKBar(
                        'K',
                        sensorData.potassium ?? 0,
                        300,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),

          // Soil Health Summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soil Health Assessment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHealthAssessment(context),
              ],
            ),
          ),

          // Timestamp
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Last updated: ${sensorData.timestamp.toString().split('.')[0]}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterCard(
    BuildContext context, {
    required String icon,
    required String label,
    required double? value,
    required String unit,
    required Color color,
    String? optimal,
    bool optional = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (value != null)
            Text(
              '${value.toStringAsFixed(2)}$unit',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              'N/A',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[400]),
            ),
          if (optimal != null && !optional)
            Text(
              'Optimal: $optimal',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNPKBar(String label, double value, double max, Color color) {
    final percentage = (value / max * 100).clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toStringAsFixed(0)} mg/kg',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 20,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthAssessment(BuildContext context) {
    final issues = <String>[];

    // Check moisture
    if (sensorData.soilMoisture != null) {
      if (sensorData.soilMoisture! < 20) {
        issues.add('Soil too dry - needs irrigation');
      } else if (sensorData.soilMoisture! > 80) {
        issues.add('Soil too wet - risk of root rot');
      }
    }

    // Check pH
    if (sensorData.pH != null) {
      if (sensorData.pH! < 6) {
        issues.add('Soil too acidic - add lime');
      } else if (sensorData.pH! > 8) {
        issues.add('Soil too alkaline - add sulfur');
      }
    }

    // Check nutrients
    if (sensorData.nitrogen != null && sensorData.nitrogen! < 50) {
      issues.add('Low nitrogen - nutrient deficiency');
    }
    if (sensorData.phosphorus != null && sensorData.phosphorus! < 20) {
      issues.add('Low phosphorus - nutrient deficiency');
    }
    if (sensorData.potassium != null && sensorData.potassium! < 100) {
      issues.add('Low potassium - nutrient deficiency');
    }

    if (issues.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          border: Border.all(color: Colors.green),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '✅ Soil conditions are optimal!',
                style: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: issues
          .map(
            (issue) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        issue,
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Compact soil sensor card for list view
class SoilSensorCardCompact extends StatelessWidget {
  final SensorData sensorData;
  final VoidCallback? onTap;

  const SoilSensorCardCompact({
    super.key,
    required this.sensorData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🌱 Soil Sensor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Chip(
                    label: Text('${sensorData.battery.toStringAsFixed(2)}V'),
                    backgroundColor: sensorData.battery > 3.5
                        ? Colors.green[100]
                        : Colors.red[100],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Main parameters row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactParam('💧', sensorData.soilMoisture, '%'),
                  _buildCompactParam('🌡️', sensorData.soilTemperature, '°C'),
                  _buildCompactParam('⚗️', sensorData.pH, ''),
                  _buildCompactParam('⚡', sensorData.ec, 'mS/cm'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactParam(String icon, double? value, String unit) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          value != null ? '${value.toStringAsFixed(1)}$unit' : 'N/A',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
