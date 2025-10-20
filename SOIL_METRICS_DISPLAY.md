# 🌱 Hệ thống Hiển thị 7 Chỉ số Đất - Kagri App

## 📋 Tổng quan

Hệ thống mới cho phép hiển thị đầy đủ **7 chỉ số đất quan trọng** trên tất cả các màn hình chính của ứng dụng Kagri, bao gồm:

1. **Độ ẩm đất** (Soil Moisture) - %
2. **Nhiệt độ đất** (Soil Temperature) - °C  
3. **pH** - [0-14]
4. **EC** - Độ dẫn điện (mS/cm)
5. **N** - Nitơ (mg/kg)
6. **P** - Phospho (mg/kg)
7. **K** - Kali (mg/kg)

---

## 🎨 Thiết kế UI/UX

### Đặc điểm nổi bật:

✅ **Color-Coded Indicators** - Mỗi chỉ số có màu sắc riêng theo ngưỡng an toàn
- 🔴 Đỏ (Critical): Giá trị nguy hiểm
- 🟠 Cam (Warning): Giá trị cảnh báo
- 🟢 Xanh lá (Optimal): Giá trị tối ưu
- 🔵 Xanh dương (Good): Giá trị tốt
- ⚪ Xám (Neutral): Không có dữ liệu

✅ **Icon phù hợp** cho từng chỉ số
- 💧 Độ ẩm: Water Drop
- 🌡️ Nhiệt độ: Thermostat
- 🔬 pH: Science
- ⚡ EC: Electric Bolt
- 🌿 Nitơ (N): Grass
- 🌸 Phospho (P): Spa
- 🌾 Kali (K): Eco

✅ **Responsive Layout** - Tự động điều chỉnh theo kích thước màn hình

✅ **Status Labels** - Hiển thị trạng thái bằng tiếng Việt dễ hiểu

---

## 📂 Cấu trúc File Mới

### 1. **lib/utils/soil_thresholds.dart** (200+ dòng)
**Chức năng:** Định nghĩa ngưỡng an toàn và xử lý màu sắc cho 7 chỉ số đất

**Ngưỡng tối ưu:**
```dart
// Độ ẩm đất: 40-70%
// Nhiệt độ đất: 15-30°C
// pH: 6.0-7.5
// EC: 1.0-3.0 mS/cm
// Nitơ (N): 80-150 mg/kg
// Phospho (P): 30-80 mg/kg
// Kali (K): 120-200 mg/kg
```

**API chính:**
```dart
// Lấy màu sắc theo giá trị
Color getSoilMoistureColor(double? value)
Color getPhColor(double? value)
Color getNitrogenColor(double? value)
// ... và các hàm tương tự cho 7 chỉ số

// Lấy trạng thái văn bản
String getSoilMoistureStatus(double? value) // "Tối ưu", "Khô", "Rất ẩm"...
String getPhStatus(double? value) // "Tối ưu", "Chua", "Kiềm"...
// ... và các hàm tương tự
```

---

### 2. **lib/widgets/soil_metrics_display.dart** (400+ dòng)
**Chức năng:** Widget tái sử dụng để hiển thị 7 chỉ số đất

**2 chế độ hiển thị:**

#### A. **Compact View** (cho Home Screen)
- Grid layout 3 hàng x 2-3 cột
- Hiển thị giá trị chính + status badge
- Tối ưu không gian

```dart
SoilMetricsDisplay(
  sensorData: latestData,
  isCompact: true, // Chế độ compact
)
```

#### B. **Full View** (cho Detail Dialog)
- Card lớn từng chỉ số
- Hiển thị đầy đủ: Icon + Label + Value + Unit + Status + Optimal Range
- Dễ đọc và thông tin chi tiết

```dart
SoilMetricsDisplay(
  sensorData: data,
  isCompact: false, // Chế độ đầy đủ
)
```

---

## 🖥️ Tích hợp vào các màn hình

### 1. **Home Screen** (`lib/screens/home_screen.dart`)

**Thay đổi:**
- Thay thế hiển thị cơ bản (chỉ 2 chỉ số) bằng widget mới
- Hiển thị grid 3x3 cho soil sensor
- Giữ nguyên hiển thị cho environment/water sensor

**Vị trí:** Trong `_buildDeviceCard()` → `StreamBuilder<List<SensorData>>`

**Code:**
```dart
if (latestData.deviceType == 'soil_sensor') {
  return Column(
    children: [
      SoilMetricsDisplay(
        sensorData: latestData,
        isCompact: true,
      ),
      // Battery và RSSI info
      // Counter và timestamp
    ],
  );
}
```

---

### 2. **Device Details Dialog** (`lib/screens/home_screen.dart`)

**Thay đổi:**
- Trong `ExpansionTile` của mỗi bản ghi lịch sử
- Hiển thị đầy đủ 7 chỉ số với layout card lớn
- Dễ đọc và so sánh giữa các bản ghi

**Vị trí:** Trong `_showDeviceDetails()` → `ExpansionTile.children`

**Code:**
```dart
children: [
  Padding(
    padding: const EdgeInsets.all(16),
    child: data.deviceType == 'soil_sensor'
        ? SoilMetricsDisplay(
            sensorData: data,
            isCompact: false, // Full view
          )
        : Column(/* environment sensor view */),
  ),
],
```

---

### 3. **Chart Screen** (`lib/screens/device_chart_screen.dart`)

**Thay đổi:**
- Thêm 5 chip mới: pH, EC, N, P, K
- Cập nhật `_buildChart()` để xử lý dữ liệu 7 chỉ số
- Cập nhật `_buildStatistics()` để tính min/max/avg cho 7 chỉ số
- Thêm màu sắc và unit riêng cho từng chỉ số mới

**Metrics mới:**
```dart
Wrap(
  children: [
    // Existing: temperature, humidity, battery, rssi
    _buildMetricChip('pH', 'pH', Icons.science),
    _buildMetricChip('ec', 'EC', Icons.electric_bolt),
    _buildMetricChip('nitrogen', 'Nitơ (N)', Icons.grass),
    _buildMetricChip('phosphorus', 'Phospho (P)', Icons.spa),
    _buildMetricChip('potassium', 'Kali (K)', Icons.eco),
  ],
)
```

**Màu sắc biểu đồ:**
- pH: 🟣 Purple (#9C27B0)
- EC: 🟠 Orange (#FF9800)
- N: 🟢 Green (#4CAF50)
- P: 🔵 Blue (#2196F3)
- K: 🟤 Brown (#795548)

---

## 📊 Ngưỡng Tối Ưu Theo Tiêu Chuẩn Nông Nghiệp

### 1. Độ ẩm đất (Soil Moisture)
| Giá trị | Trạng thái | Màu | Mô tả |
|---------|-----------|-----|-------|
| < 30% | Rất khô | 🔴 Đỏ | Cần tưới ngay |
| 30-40% | Khô | 🟠 Cam | Cần tưới |
| **40-70%** | **Tối ưu** | **🟢 Xanh** | **Lý tưởng cho cây trồng** |
| 70-80% | Ẩm | 🟠 Cam | Giảm tưới |
| > 80% | Rất ẩm | 🔴 Đỏ | Nguy cơ úng rễ |

### 2. Nhiệt độ đất (Soil Temperature)
| Giá trị | Trạng thái | Màu |
|---------|-----------|-----|
| < 10°C | Quá lạnh | 🔴 Đỏ |
| 10-15°C | Lạnh | 🟠 Cam |
| **15-30°C** | **Tối ưu** | **🟢 Xanh** |
| 30-35°C | Nóng | 🟠 Cam |
| > 35°C | Quá nóng | 🔴 Đỏ |

### 3. pH
| Giá trị | Trạng thái | Màu |
|---------|-----------|-----|
| < 5.5 | Quá chua | 🔴 Đỏ |
| 5.5-6.0 | Chua | 🟠 Cam |
| **6.0-7.5** | **Tối ưu** | **🟢 Xanh** |
| 7.5-8.0 | Kiềm | 🟠 Cam |
| > 8.0 | Quá kiềm | 🔴 Đỏ |

### 4. EC (Độ dẫn điện)
| Giá trị | Trạng thái | Màu |
|---------|-----------|-----|
| < 0.5 mS/cm | Rất thấp | 🟠 Cam |
| 0.5-1.0 | Thấp | 🔵 Xanh dương |
| **1.0-3.0** | **Tối ưu** | **🟢 Xanh** |
| 3.0-4.0 | Cao | 🟠 Cam |
| > 4.0 | Quá cao | 🔴 Đỏ |

### 5. Nitơ (N)
| Giá trị | Trạng thái | Màu |
|---------|-----------|-----|
| < 50 mg/kg | Thiếu hụt | 🔴 Đỏ |
| 50-80 | Thấp | 🟠 Cam |
| **80-150** | **Tối ưu** | **🟢 Xanh** |
| 150-200 | Tốt | 🔵 Xanh dương |
| > 200 | Cao | 🟠 Cam |

### 6. Phospho (P)
| Giá trị | Trạng thái | Màu |
|---------|-----------|-----|
| < 20 mg/kg | Thiếu hụt | 🔴 Đỏ |
| 20-30 | Thấp | 🟠 Cam |
| **30-80** | **Tối ưu** | **🟢 Xanh** |
| 80-120 | Tốt | 🔵 Xanh dương |
| > 120 | Cao | 🟠 Cam |

### 7. Kali (K)
| Giá trị | Trạng thái | Màu |
|---------|-----------|-----|
| < 80 mg/kg | Thiếu hụt | 🔴 Đỏ |
| 80-120 | Thấp | 🟠 Cam |
| **120-200** | **Tối ưu** | **🟢 Xanh** |
| 200-250 | Tốt | 🔵 Xanh dương |
| > 250 | Cao | 🟠 Cam |

---

## 🧪 Testing & Validation

### Test Cases:

1. ✅ **Soil Sensor hiển thị đầy đủ 7 chỉ số**
   - Home screen: Grid compact với 7 chỉ số
   - Detail dialog: Full cards với thông tin chi tiết
   - Chart: 9 metrics có thể chọn (4 cơ bản + 5 soil)

2. ✅ **Environment/Water Sensor giữ nguyên UI cũ**
   - Chỉ hiển thị temperature, humidity, battery, RSSI
   - Không bị ảnh hưởng bởi thay đổi

3. ✅ **Color Coding hoạt động chính xác**
   - Giá trị trong ngưỡng tối ưu: 🟢 Xanh
   - Giá trị cảnh báo: 🟠 Cam
   - Giá trị nguy hiểm: 🔴 Đỏ
   - Không có dữ liệu: ⚪ Xám

4. ✅ **Responsive trên nhiều kích thước màn hình**
   - Mobile: Grid tự động điều chỉnh
   - Tablet: Layout rộng hơn
   - Text overflow: Ellipsis khi cần

5. ✅ **Chart hoạt động với tất cả metrics**
   - Chọn metric → Vẽ biểu đồ
   - Statistics: Min, Max, Avg, Latest
   - Color riêng cho từng metric

---

## 🚀 Sử dụng

### 1. Import widget:
```dart
import '../widgets/soil_metrics_display.dart';
import '../utils/soil_thresholds.dart';
```

### 2. Hiển thị trong UI:
```dart
// Compact view cho Home Screen
SoilMetricsDisplay(
  sensorData: latestSensorData,
  isCompact: true,
)

// Full view cho Detail Screen
SoilMetricsDisplay(
  sensorData: historicalData,
  isCompact: false,
)
```

### 3. Customize threshold (nếu cần):
```dart
// Trong soil_thresholds.dart, điều chỉnh giá trị ngưỡng
static const double soilMoistureOptimalMin = 40.0;
static const double soilMoistureOptimalMax = 70.0;
```

---

## 📈 Lợi ích

✅ **Người dùng:**
- Theo dõi đầy đủ chỉ số đất quan trọng
- Hiểu rõ tình trạng đất trồng qua màu sắc
- Đưa ra quyết định tưới tiêu, bón phân chính xác

✅ **Nhà phát triển:**
- Widget tái sử dụng, dễ bảo trì
- Tách biệt logic xử lý ngưỡng
- Mở rộng dễ dàng cho sensor mới

✅ **Nông dân:**
- Giao diện thân thiện, dễ hiểu
- Cảnh báo kịp thời khi chỉ số bất thường
- Tối ưu hóa năng suất và tiết kiệm chi phí

---

## 🔄 Tương lai

### Các tính năng có thể mở rộng:

1. **Lời khuyên thông minh**
   - AI gợi ý hành động dựa trên 7 chỉ số
   - "Nên tưới thêm nước", "Bón thêm Nitơ"

2. **Thông báo Push**
   - Cảnh báo khi chỉ số vượt ngưỡng
   - Nhắc nhở chăm sóc định kỳ

3. **Báo cáo tuần/tháng**
   - Phân tích xu hướng 7 chỉ số
   - So sánh với thời kỳ trước

4. **Tùy chỉnh ngưỡng theo loại cây**
   - Profile riêng cho từng loại cây trồng
   - Tối ưu hóa theo điều kiện vùng miền

---

## 📞 Hỗ trợ

Nếu gặp vấn đề hoặc cần hỗ trợ:
- 📧 Email: support@kagri.app
- 📱 GitHub Issues: [kagri_app/issues](https://github.com/vuvantruong120896/kagri_app/issues)

---

**🌱 Kagri App - Smart Agriculture for Everyone**

*Phiên bản: 1.0.0 | Ngày: 20/10/2025*
