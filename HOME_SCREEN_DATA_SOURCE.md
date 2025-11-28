# HOME Screen - Dữ Liệu Hiển Thị

## Tóm tắt
Màn HOME của Mobile App lấy dữ liệu từ **Firebase Realtime Database** qua `DeviceRegistryService`.

## Cấu trúc Dữ Liệu

### Nguồn Dữ Liệu Chính
```
Firebase Realtime Database
    └── users/{uid}/devices/
        ├── device_0x1234
        ├── device_0x5678
        └── device_0xABCD
```

### Dữ Liệu Mỗi Thiết Bị (RegisteredDevice)

**File:** `lib/models/registered_device.dart`

```dart
class RegisteredDevice {
  // Persistent data (mã hóa trong Firebase)
  final String nodeId;              // ID thiết bị: "0x1234"
  final String deviceType;          // "soil_sensor", "gateway", etc
  final String displayName;         // Tên hiển thị: "Node 1234"
  final String? location;           // Vị trí: "Cánh đồng A"
  final String? notes;              // Ghi chú
  final DateTime provisionedAt;     // Thời gian đăng ký
  final String? firmwareVersion;    // Phiên bản firmware
  final String? provisionedBy;      // Ứng dụng nào đã đăng ký

  // Runtime status (cập nhật từ routing_table)
  bool isOnline;                    // Trạng thái kết nối
  DateTime? lastSeen;               // Lần cuối thấy
  int? rssi;                        // Độ mạnh tín hiệu
  int? hopCount;                    // Số hop từ gateway
}
```

## Quy Trình Lấy Dữ Liệu

### 1. HomeScreen.dart
```dart
// HOME Screen sử dụng StreamBuilder lắng nghe dữ liệu
Expanded(
  child: StreamBuilder<List<RegisteredDevice>>(
    stream: _deviceRegistry.getDevicesStream(),  // ← Gọi service
    builder: (context, snapshot) {
      // Hiển thị danh sách thiết bị
    }
  )
)
```

### 2. DeviceRegistryService.getDevicesStream()

**File:** `lib/services/device_registry_service.dart`

```dart
Stream<List<RegisteredDevice>> getDevicesStream() {
  final ref = _getUserDevicesRef();  // users/{uid}/devices
  
  return ref.onValue.map((event) {
    // Chuyển đổi Firebase snapshot thành List<RegisteredDevice>
    // Mỗi lần dữ liệu thay đổi, stream phát dữ liệu mới
  });
}
```

### 3. Firebase Path

```
users/{uid}/devices/
├── device_0x1234: {
│   "nodeId": "0x1234",
│   "deviceType": "soil_sensor",
│   "displayName": "Node 1234",
│   "location": "Cánh đồng A",
│   "notes": "Sensor đo độ ẩm",
│   "provisionedAt": 1732708666000,
│   "firmwareVersion": "v1.2.3",
│   "provisionedBy": "mobile_app_v1.0.0",
│   "isOnline": true,
│   "lastSeen": 1732708666000,
│   "rssi": -45,
│   "hopCount": 2
│ }
├── device_0x5678: { ... }
└── device_0xABCD: { ... }
```

## Dòng Dữ Liệu Chi Tiết

### Khi Khởi Động App
```
HomeScreen.initState()
    ↓
_deviceRegistry.getDevicesStream()
    ↓
Firebase: GET users/{uid}/devices/
    ↓
RegisteredDevice.fromFirebase() (chuyển đổi dữ liệu)
    ↓
StreamBuilder cập nhật UI
    ↓
Hiển thị danh sách thiết bị trên màn HOME
```

### Khi Dữ Liệu Thay Đổi
```
Firebase dữ liệu thay đổi (update isOnline, rssi, v.v.)
    ↓
Stream phát dữ liệu mới
    ↓
StreamBuilder lắng nghe thay đổi
    ↓
UI tự động cập nhật (không cần rebuild toàn bộ)
```

## Dữ Liệu Hiển Thị Trên HOME

### Card Thiết Bị Hiển Thị:
1. **Display Name** - Tên người dùng đặt (vd: "Node 1234")
2. **Device Type** - Loại thiết bị (vd: "soil_sensor")
3. **Status** - Trạng thái online/offline
4. **Last Seen** - Lần cuối kết nối
5. **Signal Strength** - RSSI (nếu có)
6. **Latest Sensor Data** - Dữ liệu cảm biến mới nhất

### Data Source Cho Mỗi Phần:

| Dữ Liệu | Nguồn | Từ Đâu |
|---------|-------|--------|
| Tên thiết bị | `displayName` | Firebase devices |
| Loại thiết bị | `deviceType` | Firebase devices |
| Trạng thái | `isOnline` | Firebase devices / routing_table |
| Lần cuối | `lastSeen` | Firebase devices / routing_table |
| RSSI | `rssi` | Firebase devices / routing_table |
| Dữ liệu cảm biến | DataService | sensor_data/{uid}/{nodeId}/ |

## Cơ Chế Cập Nhật

### Real-Time Updates
- Sử dụng Firebase `onValue` stream
- Khi bất kỳ thay đổi nào tại `users/{uid}/devices/`, stream phát tự động
- Không cần polling hoặc manual refresh

### Polling (Nếu Cần)
- Có thể gọi `_deviceRegistry.refreshDevices()` để force update
- Hoặc pull-to-refresh từ UI

## Khác Biệt: RegisteredDevice vs Device vs SensorData

| Loại | Lưu Tại | Mục Đích | Cập Nhật |
|------|---------|---------|----------|
| **RegisteredDevice** | `users/{uid}/devices/` | Danh sách thiết bị được đăng ký | Khi đăng ký hoặc cập nhật tên |
| **Device** | `nodes/{uid}/{gatewayMac}/{nodeId}/` | Thông tin chi tiết trên mạng | Khi khám phá nút mới |
| **SensorData** | `sensor_data/{uid}/{nodeId}/` | Lịch sử dữ liệu cảm biến | Mỗi khi nhận dữ liệu |

## Ví Dụ: Luồng Hiển Thị Handheld

### 1. Khi Đăng Ký Handheld (BLE Provisioning)
```dart
// firebase_service.dart - registerHandheld() được gọi
// Tạo entry trong users/{uid}/devices/
```

### 2. Khi Kết Nối và Nhận Dữ Liệu
```dart
// handheld_sensor_data_screen.dart
// Nhận dữ liệu JSON qua BLE
// Upload lên sensor_data/{uid}/{nodeId}/{timestamp}
// registerDevice() được gọi tự động (nếu chưa có)
```

### 3. HOME Screen Hiển Thị
```dart
// Lấy từ users/{uid}/devices/device_0x45A0
// Hiển thị: "KAGRI-HHT-45A0" (từ displayName)
// Trạng thái: "Offline" (isOnline = false)
// Khi kết nối lại: "Online"
```

## Code Reference

### HomeScreen (Line 364-365)
```dart
StreamBuilder<List<RegisteredDevice>>(
  stream: _deviceRegistry.getDevicesStream(),
```

### DeviceRegistryService (Line 81-110)
```dart
Stream<List<RegisteredDevice>> getDevicesStream() {
  final ref = _getUserDevicesRef();  // users/{uid}/devices
  if (ref == null) {
    return Stream.value([]);
  }
  return ref.onValue.map((event) { ... });
}
```

### RegisteredDevice Model (Line 58-95)
```dart
factory RegisteredDevice.fromFirebase(
  String key,
  Map<dynamic, dynamic> data,
) {
  // Chuyển đổi Firebase data thành RegisteredDevice object
}
```

## Kết Luận

**HOME Screen hiển thị thiết bị dựa vào:**
1. ✅ **users/{uid}/devices/** - Danh sách thiết bị đã đăng ký
2. ✅ **RegisteredDevice model** - Cấu trúc dữ liệu
3. ✅ **DeviceRegistryService** - Stream dữ liệu real-time
4. ✅ **StreamBuilder** - Widget lắng nghe và cập nhật UI

Mỗi lần dữ liệu trong Firebase `users/{uid}/devices/` thay đổi, HOME screen sẽ tự động cập nhật danh sách thiết bị.
