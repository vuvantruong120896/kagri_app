# Chart Feature Implementation 📊

## ✅ Đã thêm tính năng xem biểu đồ!

### 🎯 Tính năng mới

**Device Chart Screen** - Màn hình hiển thị biểu đồ lịch sử sensor data với nhiều tùy chọn

---

## 📱 Màn hình mới: DeviceChartScreen

### File: `lib/screens/device_chart_screen.dart`

### Cấu trúc:
```
┌─────────────────────────────────────────┐
│ AppBar                                  │
│ - Sensor Node 1                         │
│ - Node ID: 0xCC64                      │
│                            [Refresh 🔄] │
├─────────────────────────────────────────┤
│ Chọn chỉ số:                           │
│ [🌡️ Nhiệt độ] [💧 Độ ẩm] [🔋 Pin] [📡 RSSI] │
│                                         │
│ Khoảng thời gian:                      │
│ [1 giờ] [6 giờ] [24 giờ] [7 ngày]     │
├─────────────────────────────────────────┤
│ Statistics:                             │
│ Hiện tại | Trung bình | Thấp nhất | Cao nhất │
│  25.5°C  |   25.2°C   |  24.8°C  | 26.1°C  │
├─────────────────────────────────────────┤
│                                         │
│      📈 Line Chart                      │
│                                         │
│  30°C ┤         ╱──╲                   │
│       │     ╱──╱    ╲                  │
│  25°C ┼──╱──          ╲──╲             │
│       │                   ╲            │
│  20°C ┤                    ╲──         │
│       └─────────────────────────       │
│       14:00  14:30  15:00  15:30       │
│                                         │
└─────────────────────────────────────────┘
```

---

## 🎨 Features

### 1. **Metric Selector** (Chọn chỉ số)

4 loại chỉ số có thể xem:

#### 🌡️ Nhiệt độ (Temperature)
- Đơn vị: °C
- Màu: Blue (temperatureNormal)
- Range: Tự động scale theo data

#### 💧 Độ ẩm (Humidity)
- Đơn vị: %
- Màu: Cyan (humidityNormal)
- Range: 0-100%

#### 🔋 Pin (Battery)
- Đơn vị: V (Volts)
- Màu: Green (online)
- Range: 3.0-4.2V thường

#### 📡 RSSI (Signal Strength)
- Đơn vị: dBm
- Màu: Primary blue
- Range: -40 to -100 dBm

**UI:** ChoiceChip với icon và label
```dart
ChoiceChip(
  label: Row(
    Icon + Text
  ),
  selected: isSelected,
  selectedColor: primary,
)
```

---

### 2. **Time Range Selector** (Khoảng thời gian)

4 khoảng thời gian:

#### ⏱️ 1 giờ (1h)
- Hiển thị: Last 60 phút
- X-axis format: HH:mm
- Best for: Real-time monitoring

#### ⏱️ 6 giờ (6h)
- Hiển thị: Last 6 hours
- X-axis format: HH:mm
- Best for: Short-term trends

#### ⏱️ 24 giờ (24h)
- Hiển thị: Last 24 hours
- X-axis format: HH:mm
- Best for: Daily patterns

#### ⏱️ 7 ngày (7d)
- Hiển thị: Last 7 days
- X-axis format: dd/MM
- Best for: Weekly trends

**UI:** ChoiceChip với label đơn giản
```dart
ChoiceChip(
  label: Text('1 giờ'),
  selected: isSelected,
  selectedColor: accent (orange),
)
```

---

### 3. **Statistics Summary**

4 thống kê quan trọng:

```
┌──────────────────────────────────────────┐
│ Hiện tại    Trung bình   Thấp nhất  Cao nhất │
│  25.5°C      25.2°C      24.8°C    26.1°C  │
└──────────────────────────────────────────┘
```

#### Hiện tại (Latest)
- Giá trị: Bản ghi mới nhất
- Màu: Primary blue

#### Trung bình (Average)
- Giá trị: Mean của tất cả data points
- Màu: Accent orange

#### Thấp nhất (Min)
- Giá trị: Minimum trong range
- Màu: Blue

#### Cao nhất (Max)
- Giá trị: Maximum trong range
- Màu: Red

---

### 4. **Line Chart** (fl_chart)

#### Chart Features:
- ✅ **Curved line** - Smooth interpolation
- ✅ **Area fill** - Gradient below line (20% opacity)
- ✅ **Dots** - Show on line if < 20 points
- ✅ **Grid lines** - Horizontal và vertical
- ✅ **Touch tooltip** - Hiển thị value khi tap
- ✅ **Auto scaling** - Y-axis tự động theo min/max
- ✅ **Time labels** - X-axis hiển thị timestamps

#### Chart Configuration:
```dart
LineChart(
  LineChartData(
    gridData: FlGridData(show: true),
    titlesData: FlTitlesData(
      bottomTitles: Time labels (HH:mm or dd/MM)
      leftTitles: Value labels with unit
    ),
    lineBarsData: [
      LineChartBarData(
        spots: data points,
        isCurved: true,
        color: metric color,
        barWidth: 3,
        dotData: show if < 20 points,
        belowBarData: gradient fill,
      ),
    ],
    lineTouchData: tooltip on touch,
  ),
)
```

#### Touch Tooltip:
```
╔═══════════════════════╗
║ 17/10 14:35:45        ║
║ 25.50°C               ║
╚═══════════════════════╝
```
- Timestamp: White bold
- Value: Metric color, larger font
- Auto-positioned above touch point

---

## 🔗 Navigation Paths

### Path 1: Từ Home Screen → Device Details → Chart
```
Home Screen
  ↓ Tap on Node Card
Device Details Dialog
  ↓ Tap "Xem biểu đồ"
Device Chart Screen
```

### Path 2: Từ Home Screen → FloatingActionButton → Chart
```
Home Screen
  ↓ Tap FAB (Analytics button)
[If 1 device] → Device Chart Screen
[If multiple] → Device Selector Dialog
  ↓ Select a device
Device Chart Screen
```

---

## 💻 Code Structure

### Main Components:

#### 1. **DeviceChartScreen** (StatefulWidget)
```dart
class DeviceChartScreen extends StatefulWidget {
  final Device device;
}

class _DeviceChartScreenState extends State<DeviceChartScreen> {
  String _selectedMetric = 'temperature';
  String _selectedTimeRange = '1h';
}
```

#### 2. **Metric Selector**
```dart
Widget _buildMetricChip(String value, String label, IconData icon)
```
- ChoiceChip with icon + text
- Selected: primary color with white text
- Unselected: white background with primary text

#### 3. **Time Range Selector**
```dart
Widget _buildTimeRangeChip(String value, String label)
```
- ChoiceChip with text only
- Selected: accent (orange) with white text
- Unselected: white background with black text

#### 4. **Data Filter**
```dart
List<SensorData> _filterDataByTimeRange(List<SensorData> data)
```
- Calculates cutoff time based on selected range
- Filters data to only include records after cutoff
- Returns filtered list

#### 5. **Statistics Builder**
```dart
Widget _buildStatistics(List<SensorData> data)
```
- Calculates min, max, avg, latest
- Builds 4 stat cards in a row
- Color-coded by stat type

#### 6. **Chart Builder**
```dart
Widget _buildChart(List<SensorData> data)
```
- Converts SensorData to FlSpot points
- Configures chart appearance based on metric
- Handles empty data gracefully
- Returns LineChart widget

---

## 📊 Data Processing

### Time Filtering:
```dart
1h  → now.subtract(Duration(hours: 1))
6h  → now.subtract(Duration(hours: 6))
24h → now.subtract(Duration(hours: 24))
7d  → now.subtract(Duration(days: 7))

Filter: data.where((d) => d.timestamp.isAfter(cutoffTime))
```

### Value Extraction:
```dart
switch (_selectedMetric) {
  case 'temperature': return d.temperature;
  case 'humidity':    return d.humidity;
  case 'battery':     return d.battery;
  case 'rssi':        return d.rssi?.toDouble() ?? 0;
}
```

### Chart Points:
```dart
for (var i = 0; i < data.length; i++) {
  final d = data[data.length - 1 - i]; // Reverse order
  spots.add(FlSpot(i.toDouble(), value));
}
```
- X-axis: Index (0, 1, 2, ...)
- Y-axis: Sensor value
- Order: Oldest → Newest (left to right)

---

## 🎨 Color Scheme

### Metric Colors:
```dart
Temperature → AppColors.temperatureNormal (Blue)
Humidity    → AppColors.humidityNormal (Cyan)
Battery     → AppColors.online (Green)
RSSI        → AppColors.primary (Blue)
```

### UI Colors:
```dart
Primary selection  → AppColors.primary (Blue)
Accent selection   → AppColors.accent (Orange)
Grid lines         → Colors.grey[300]
Border             → Colors.grey[300]
Area fill          → Metric color @ 20% opacity
```

---

## 🚀 User Experience

### Loading States:

#### 1. **Waiting for data**
```
[CircularProgressIndicator]
```

#### 2. **No data available**
```
📊 Icon (grey, 64px)
"Chưa có dữ liệu"
```

#### 3. **No data in time range**
```
📅 Icon (grey, 64px)
"Không có dữ liệu trong khoảng thời gian này"
```

#### 4. **Error loading**
```
⚠️ Icon (red, 64px)
"Lỗi tải dữ liệu"
[Error message]
```

### Interaction:

#### Tap on chart
- Shows tooltip with timestamp + value
- Tooltip follows finger

#### Tap metric chip
- Changes chart data
- Updates statistics
- Smooth transition

#### Tap time range chip
- Filters data
- Updates chart
- Updates statistics

#### Pull to refresh
- Tap refresh button in AppBar
- Rebuilds widget
- Refetches stream data

---

## 📱 Responsive Design

### Chart Sizing:
```dart
Expanded(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: _buildChart(data),
  ),
)
```
- Chart takes all available vertical space
- Horizontal padding: 16px
- Automatically scales to screen size

### Chip Wrapping:
```dart
Wrap(
  spacing: 8,
  children: [chips...],
)
```
- Chips wrap to next line on small screens
- 8px spacing between chips

---

## 🐛 Error Handling

### Empty data:
```dart
if (spots.isEmpty) {
  return Center(child: Text('Không có dữ liệu'));
}
```

### Invalid index:
```dart
if (value.toInt() >= data.length) return Text('');
if (index < 0 || index >= data.length) return Text('');
```

### Null RSSI:
```dart
case 'rssi':
  return d.rssi?.toDouble() ?? 0;
```

### Division by zero:
```dart
// Y-axis range
final range = maxY - minY;
final padding = range > 0 ? range * 0.1 : 1.0;
```

---

## 📊 Chart Examples

### Temperature Chart (1h):
```
30°C ┤           ╱──╲
     │       ╱──╱    ╲
25°C ┼────╱──         ╲──╲
     │                    ╲
20°C ┤                     ╲──
     └────────────────────────
     14:00  14:30  15:00  15:30
```

### Humidity Chart (24h):
```
80% ┤  ╱─╲     ╱──╲
    │ ╱   ╲   ╱    ╲
60% ┼╱     ╲─╱      ╲──╲
    │                   ╲
40% ┤                    ──
    └────────────────────────
    00:00  06:00  12:00  18:00
```

### Battery Chart (7d):
```
4.2V ┤──────────╲
     │           ╲
3.7V ┼            ╲──────╲
     │                    ╲
3.0V ┤                     ──
     └────────────────────────
     10/10  13/10  16/10  19/10
```

### RSSI Chart (6h):
```
-40dBm ┤  ╱──╲     ╱──╲
       │ ╱    ╲   ╱    ╲
-60dBm ┼╱      ╲─╱      ╲
       │                 ╲
-80dBm ┤                  ──
       └────────────────────────
       12:00  13:00  14:00  15:00
```

---

## 🔧 HomeScreen Integration

### FloatingActionButton Update:
```dart
floatingActionButton: StreamBuilder<List<Device>>(
  stream: _dataService.getDevicesStream(),
  builder: (context, snapshot) {
    final devices = snapshot.data ?? [];
    
    return FloatingActionButton(
      onPressed: () {
        if (devices.length == 1) {
          // Direct navigation
          Navigator.push(...DeviceChartScreen(device));
        } else {
          // Show device selector
          _showChartDeviceSelector(context, devices);
        }
      },
      child: Icon(Icons.analytics),
    );
  },
)
```

### Device Selector Dialog:
```dart
void _showChartDeviceSelector(BuildContext context, List<Device> devices) {
  showDialog(
    AlertDialog(
      title: 'Chọn Node để xem biểu đồ',
      content: ListView.builder(
        itemBuilder: (context, index) {
          return ListTile(
            leading: Icon(router, color: online/offline),
            title: device.name,
            subtitle: 'Node ID: ...',
            onTap: () {
              Navigator.pop();
              Navigator.push(...DeviceChartScreen(device));
            },
          );
        },
      ),
    ),
  );
}
```

### Device Details Dialog Update:
```dart
ElevatedButton.icon(
  onPressed: () {
    Navigator.pop(); // Close dialog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceChartScreen(device: device),
      ),
    );
  },
  icon: Icon(Icons.analytics),
  label: Text('Xem biểu đồ'),
)
```

---

## ✅ Testing Checklist

- [x] Chart screen compiles without errors
- [x] Navigation from FAB works
- [x] Navigation from device details works
- [x] Device selector shows when multiple devices
- [ ] Temperature chart displays correctly
- [ ] Humidity chart displays correctly
- [ ] Battery chart displays correctly
- [ ] RSSI chart displays correctly
- [ ] Time range filter works (1h, 6h, 24h, 7d)
- [ ] Statistics calculate correctly
- [ ] Touch tooltip shows on chart tap
- [ ] Empty state shows when no data
- [ ] Error state shows on stream error
- [ ] Chart updates when metric changed
- [ ] Chart updates when time range changed
- [ ] Refresh button works
- [ ] Back button returns to home
- [ ] Chart scales correctly on different screen sizes

---

## 🎯 Benefits

### Before:
❌ Không có cách xem lịch sử data trực quan
❌ Khó so sánh xu hướng theo thời gian
❌ Phải đọc từng số liệu riêng lẻ
❌ Không thấy pattern hoặc anomaly

### After:
✅ Biểu đồ line chart trực quan
✅ Xem xu hướng rõ ràng (tăng/giảm)
✅ Compare 4 metrics khác nhau
✅ Chọn time range linh hoạt
✅ Statistics summary nhanh
✅ Touch tooltip chi tiết
✅ Identify patterns dễ dàng
✅ Spot anomalies ngay lập tức

---

## 📈 Use Cases

### 1. **Temperature Monitoring**
- Xem nhiệt độ thay đổi trong ngày
- Phát hiện spike nhiệt độ bất thường
- Kiểm tra pattern theo giờ (sáng/chiều/tối)

### 2. **Humidity Tracking**
- Monitor độ ẩm môi trường
- So sánh với nhiệt độ
- Phát hiện tăng đột ngột (mưa?)

### 3. **Battery Health**
- Theo dõi pin giảm dần
- Dự đoán khi cần thay pin
- Identify nodes có vấn đề về pin

### 4. **Signal Quality**
- Xem RSSI strength theo thời gian
- Phát hiện khi node di chuyển xa
- Identify vùng signal yếu

---

## 🚀 Next Steps

### Possible Enhancements:
1. 📊 **Multi-metric chart** - Hiển thị nhiều metric cùng lúc
2. 🔍 **Zoom & Pan** - Phóng to vùng quan tâm
3. 📅 **Custom date range** - Chọn from/to date
4. 📥 **Export data** - Download CSV/Excel
5. 📸 **Screenshot** - Save chart as image
6. 🔔 **Threshold lines** - Hiển thị warning levels
7. 📈 **Trend indicators** - Show ↑↓ và percentage change
8. 🎨 **Theme selector** - Dark mode cho chart
9. 📊 **Bar chart option** - Alternative visualization
10. 🔄 **Auto-refresh** - Real-time updates without manual refresh

---

## 📝 Summary

**Major Feature:** Interactive line charts với fl_chart library

**4 Metrics:** Temperature, Humidity, Battery, RSSI

**4 Time Ranges:** 1h, 6h, 24h, 7d

**Key Features:**
- ✅ Real-time streaming data
- ✅ Interactive touch tooltips
- ✅ Auto-scaling axes
- ✅ Statistics summary
- ✅ Smooth curved lines
- ✅ Gradient area fill
- ✅ Multiple navigation paths

Perfect cho monitoring LoRa mesh network sensor data! 📊🎉
