import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/sensor_data.dart';
import '../models/device.dart';
import '../services/data_service.dart';
import '../utils/constants.dart';

class DeviceChartScreen extends StatefulWidget {
  final Device device;

  const DeviceChartScreen({super.key, required this.device});

  @override
  State<DeviceChartScreen> createState() => _DeviceChartScreenState();
}

class _DeviceChartScreenState extends State<DeviceChartScreen> {
  final DataService _dataService = DataService();
  String _selectedMetric =
      'temperature'; // temperature, humidity, battery, rssi
  String _selectedTimeRange = '1h'; // 1h, 6h, 24h, 7d
  bool _isGateway = false;

  @override
  void initState() {
    super.initState();
    // Check gateways once to mark title correctly
    _dataService
        .getGatewaysStream()
        .first
        .then((list) {
          if (mounted) {
            setState(() {
              _isGateway = list.contains(widget.device.nodeId);
            });
          }
        })
        .catchError((_) {
          // ignore
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isGateway ? 'Gateway' : widget.device.name),
            Text(
              'Node ID: ${widget.device.nodeId}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {}); // Refresh data
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Metric selector
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingMedium),
            color: AppColors.primary.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn chỉ số:', style: AppTextStyles.body1),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Basic metrics
                    _buildMetricChip(
                      'temperature',
                      'Nhiệt độ',
                      Icons.thermostat,
                    ),
                    _buildMetricChip('humidity', 'Độ ẩm', Icons.water_drop),
                    _buildMetricChip('battery', 'Pin', Icons.battery_full),
                    _buildMetricChip('rssi', 'RSSI', Icons.signal_cellular_alt),
                    // Soil sensor specific metrics
                    _buildMetricChip('pH', 'pH', Icons.science),
                    _buildMetricChip('ec', 'EC', Icons.electric_bolt),
                    _buildMetricChip('nitrogen', 'Nitơ (N)', Icons.grass),
                    _buildMetricChip('phosphorus', 'Phospho (P)', Icons.spa),
                    _buildMetricChip('potassium', 'Kali (K)', Icons.eco),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Khoảng thời gian:', style: AppTextStyles.body1),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildTimeRangeChip('1h', '1 giờ'),
                    _buildTimeRangeChip('6h', '6 giờ'),
                    _buildTimeRangeChip('24h', '24 giờ'),
                    _buildTimeRangeChip('7d', '7 ngày'),
                  ],
                ),
              ],
            ),
          ),

          // Chart
          Expanded(
            child: StreamBuilder<List<SensorData>>(
              stream: _dataService.getSensorDataStream(
                nodeId: widget.device.nodeId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.danger,
                        ),
                        const SizedBox(height: 16),
                        Text('Lỗi tải dữ liệu', style: AppTextStyles.heading2),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: AppTextStyles.body2,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.show_chart, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Chưa có dữ liệu',
                          style: AppTextStyles.heading2,
                        ),
                      ],
                    ),
                  );
                }

                final filteredData = _filterDataByTimeRange(snapshot.data!);

                if (filteredData.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không có dữ liệu trong khoảng thời gian này',
                          style: AppTextStyles.heading3,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Statistics summary
                    _buildStatistics(filteredData),

                    // Chart
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.paddingMedium),
                        child: _buildChart(filteredData),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String value, String label, IconData icon) {
    final isSelected = _selectedMetric == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedMetric = value;
          });
        }
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.primary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTimeRangeChip(String value, String label) {
    final isSelected = _selectedTimeRange == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTimeRange = value;
          });
        }
      },
      selectedColor: AppColors.accent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  List<SensorData> _filterDataByTimeRange(List<SensorData> data) {
    final now = DateTime.now();
    Duration duration;

    switch (_selectedTimeRange) {
      case '1h':
        duration = const Duration(hours: 1);
        break;
      case '6h':
        duration = const Duration(hours: 6);
        break;
      case '24h':
        duration = const Duration(hours: 24);
        break;
      case '7d':
        duration = const Duration(days: 7);
        break;
      default:
        duration = const Duration(hours: 1);
    }

    final cutoffTime = now.subtract(duration);
    return data.where((d) => d.timestamp.isAfter(cutoffTime)).toList();
  }

  Widget _buildStatistics(List<SensorData> data) {
    double getValue(SensorData d) {
      switch (_selectedMetric) {
        case 'temperature':
          return d.deviceType == 'soil_sensor'
              ? (d.soilTemperature ?? 0)
              : (d.temperature ?? 0);
        case 'humidity':
          return d.deviceType == 'soil_sensor'
              ? (d.soilMoisture ?? 0)
              : (d.humidity ?? 0);
        case 'battery':
          return d.battery;
        case 'rssi':
          return d.rssi?.toDouble() ?? 0;
        case 'pH':
          return d.pH ?? 0;
        case 'ec':
          return d.conductivity ?? 0;
        case 'nitrogen':
          return d.nitrogen ?? 0;
        case 'phosphorus':
          return d.phosphorus ?? 0;
        case 'potassium':
          return d.potassium ?? 0;
        default:
          return 0;
      }
    }

    final values = data.map(getValue).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;
    final latest = values.first;

    String unit = '';
    switch (_selectedMetric) {
      case 'temperature':
        unit = '°C';
        break;
      case 'humidity':
        unit = '%';
        break;
      case 'battery':
        unit = 'V';
        break;
      case 'rssi':
        unit = ' dBm';
        break;
      case 'pH':
        unit = '';
        break;
      case 'ec':
        unit = ' mS/cm';
        break;
      case 'nitrogen':
      case 'phosphorus':
      case 'potassium':
        unit = ' mg/kg';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            'Hiện tại',
            '${latest.toStringAsFixed(1)}$unit',
            AppColors.primary,
          ),
          _buildStatCard(
            'Trung bình',
            '${avg.toStringAsFixed(1)}$unit',
            AppColors.accent,
          ),
          _buildStatCard(
            'Thấp nhất',
            '${min.toStringAsFixed(1)}$unit',
            Colors.blue,
          ),
          _buildStatCard(
            'Cao nhất',
            '${max.toStringAsFixed(1)}$unit',
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildChart(List<SensorData> data) {
    final spots = <FlSpot>[];

    // Convert data to FlSpot (x = timestamp, y = value)
    for (var i = 0; i < data.length; i++) {
      final d = data[data.length - 1 - i]; // Reverse to show oldest → newest
      double value;

      switch (_selectedMetric) {
        case 'temperature':
          value = d.deviceType == 'soil_sensor'
              ? (d.soilTemperature ?? 0)
              : (d.temperature ?? 0);
          break;
        case 'humidity':
          value = d.deviceType == 'soil_sensor'
              ? (d.soilMoisture ?? 0)
              : (d.humidity ?? 0);
          break;
        case 'battery':
          value = d.battery;
          break;
        case 'rssi':
          value = d.rssi?.toDouble() ?? 0;
          break;
        case 'pH':
          value = d.pH ?? 0;
          break;
        case 'ec':
          value = d.conductivity ?? 0;
          break;
        case 'nitrogen':
          value = d.nitrogen ?? 0;
          break;
        case 'phosphorus':
          value = d.phosphorus ?? 0;
          break;
        case 'potassium':
          value = d.potassium ?? 0;
          break;
        default:
          value = 0;
      }

      spots.add(FlSpot(i.toDouble(), value));
    }

    if (spots.isEmpty) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    // Determine Y axis range
    final values = spots.map((s) => s.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;

    // Handle case where all values are the same (e.g., bad data)
    if (range == 0 || range.isNaN) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Dữ liệu không thay đổi',
              style: AppTextStyles.body1.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Tất cả giá trị đều giống nhau: ${values.first.toStringAsFixed(2)}$_selectedMetric',
              style: AppTextStyles.caption.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Add padding with minimum threshold to prevent negative values
    double padding = range * 0.1; // 10% padding

    // For battery charts, ensure we don't go below 0V
    double chartMinY = minY - padding;
    double chartMaxY = maxY + padding;

    if (_selectedMetric == 'battery' && chartMinY < 0) {
      chartMinY = 0;
      // Adjust maxY to maintain visual balance
      chartMaxY = maxY + (padding * 2);
    }

    Color lineColor;
    String yAxisLabel;

    switch (_selectedMetric) {
      case 'temperature':
        lineColor = AppColors.temperatureNormal;
        yAxisLabel = '°C';
        break;
      case 'humidity':
        lineColor = AppColors.humidityNormal;
        yAxisLabel = '%';
        break;
      case 'battery':
        lineColor = AppColors.online;
        yAxisLabel = 'V';
        break;
      case 'rssi':
        lineColor = AppColors.primary;
        yAxisLabel = 'dBm';
        break;
      case 'pH':
        lineColor = const Color(0xFF9C27B0); // Purple
        yAxisLabel = 'pH';
        break;
      case 'ec':
        lineColor = const Color(0xFFFF9800); // Orange
        yAxisLabel = 'mS/cm';
        break;
      case 'nitrogen':
        lineColor = const Color(0xFF4CAF50); // Green
        yAxisLabel = 'mg/kg';
        break;
      case 'phosphorus':
        lineColor = const Color(0xFF2196F3); // Blue
        yAxisLabel = 'mg/kg';
        break;
      case 'potassium':
        lineColor = const Color(0xFF795548); // Brown
        yAxisLabel = 'mg/kg';
        break;
      default:
        lineColor = AppColors.primary;
        yAxisLabel = '';
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: range / 5,
          verticalInterval: spots.length > 10 ? spots.length / 10 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
          },
          getDrawingVerticalLine: (value) {
            return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: spots.length > 10 ? spots.length / 5 : 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= data.length) return const Text('');
                final index = data.length - 1 - value.toInt();
                if (index < 0 || index >= data.length) return const Text('');

                final timestamp = data[index].timestamp;
                String format = 'HH:mm';
                if (_selectedTimeRange == '7d') {
                  format = 'dd/MM';
                } else if (_selectedTimeRange == '24h') {
                  format = 'HH:mm';
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat(format).format(timestamp),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: range / 5,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(1)}$yAxisLabel',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: chartMinY,
        maxY: chartMaxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: spots.length < 20, // Show dots only if < 20 points
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: lineColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.2),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = data.length - 1 - barSpot.x.toInt();
                if (index < 0 || index >= data.length) return null;

                final d = data[index];
                return LineTooltipItem(
                  '${DateFormat('dd/MM HH:mm:ss').format(d.timestamp)}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: '${barSpot.y.toStringAsFixed(2)}$yAxisLabel',
                      style: TextStyle(
                        color: lineColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
