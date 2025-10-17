# Firebase Configuration Guide

## 📁 File Đã Tạo

### `lib/config/firebase_config.dart`
File cấu hình Firebase chứa:
- ✅ Database URL: `https://kagri-iot-default-rtdb.asia-southeast1.firebasedatabase.app`
- ✅ Auth Secret: `0kMDkyCxejcJB350HrFlgBmb3Y5PsOiR90ZXf1MV`
- ✅ useMockData flag: `true` (mặc định dùng mock data)

## 🔧 Cách Sử Dụng

### 1. Chạy với Mock Data (Mặc định)
```dart
// Trong lib/config/firebase_config.dart
static const bool useMockData = true; // ✅ Đang dùng mock data
```

App sẽ hiển thị 3 sensor nodes giả lập:
- 0xCC64 - Sensor Node 1
- 0x4F70 - Sensor Node 2  
- 0x09F8 - Sensor Node 3

### 2. Chuyển sang Firebase Real Data

**Bước 1: Tải config files từ Firebase Console**

a) **Android** - Tải `google-services.json`:
```bash
# 1. Vào: https://console.firebase.google.com
# 2. Chọn project: kagri-iot
# 3. Project Settings → General → Your apps
# 4. Chọn Android app (hoặc Add app nếu chưa có)
# 5. Download google-services.json
# 6. Copy vào: android/app/google-services.json
```

b) **iOS** - Tải `GoogleService-Info.plist`:
```bash
# 1. Vào: https://console.firebase.google.com
# 2. Chọn project: kagri-iot
# 3. Project Settings → General → Your apps
# 4. Chọn iOS app (hoặc Add app nếu chưa có)
# 5. Download GoogleService-Info.plist
# 6. Copy vào: ios/Runner/GoogleService-Info.plist
```

**Bước 2: Đổi flag trong config**
```dart
// Trong lib/config/firebase_config.dart
static const bool useMockData = false; // ✅ Chuyển sang Firebase
```

**Bước 3: Chạy app**
```bash
flutter clean
flutter pub get
flutter run
```

### 3. Toggle Real-time trong App

App có nút toggle (cloud icon) ở góc trên bên phải HomeScreen để chuyển đổi giữa mock data và Firebase data mà không cần rebuild.

## 🔐 Firebase Security Rules

Copy rules này vào Firebase Console → Realtime Database → Rules:

```json
{
  "rules": {
    "nodes": {
      "$nodeId": {
        ".read": true,
        ".write": "auth != null"
      }
    },
    "sensor_data": {
      "$nodeId": {
        ".read": true,
        ".write": "auth != null",
        ".indexOn": [".key"]
      }
    },
    "gateways": {
      "$gatewayId": {
        ".read": true,
        ".write": "auth != null"
      }
    }
  }
}
```

## 📊 Database Structure

```
https://kagri-iot-default-rtdb.asia-southeast1.firebasedatabase.app/
├── nodes/
│   ├── 0xCC64/
│   │   ├── info/
│   │   │   ├── address: "0xCC64"
│   │   │   ├── name: "Sensor Node 1"
│   │   │   ├── type: "sensor"
│   │   │   └── last_seen: 1760607651
│   │   └── latest_data/
│   │       ├── counter: 1234
│   │       ├── temperature: 25.5
│   │       ├── humidity: 65.0
│   │       ├── battery: 3.7
│   │       ├── rssi: -45
│   │       └── snr: 10.5
│   ├── 0x4F70/
│   └── 0x09F8/
├── sensor_data/
│   └── {nodeId}/
│       └── {timestamp}/
│           ├── counter
│           ├── temperature
│           ├── humidity
│           ├── battery
│           ├── rssi
│           └── snr
└── gateways/
    └── GW_1234/
        ├── status/
        │   ├── connected_nodes
        │   ├── wifi_connected
        │   └── uptime_seconds
        └── routing_table/
            ├── node_count
            └── nodes/
```

## 🧪 Testing

1. **Mock Data Test:**
   - useMockData = true
   - Nên thấy 3 devices với data thay đổi mỗi 5 giây
   - Battery, temperature, humidity thay đổi ngẫu nhiên

2. **Firebase Test:**
   - useMockData = false
   - Kết nối gateway (ESP32 với firmware LM_LR_MESH)
   - Gateway sẽ gửi routing table lên Firebase
   - App sẽ hiển thị các node từ routing table
   - Mở Network Status screen để xem gateway health

## ⚙️ Configuration Parameters

### `lib/config/firebase_config.dart`

| Parameter | Value | Description |
|-----------|-------|-------------|
| `databaseUrl` | `https://kagri-iot-default-rtdb...` | Firebase Realtime Database URL |
| `authSecret` | `0kMDkyCx...` | Database secret (dùng cho gateway) |
| `projectId` | `kagri-iot` | Firebase project ID |
| `region` | `asia-southeast1` | Database region |
| `useMockData` | `true` / `false` | Toggle mock vs real data |
| `dataRetentionDays` | `30` | Cleanup old data after X days |
| `updateIntervalMs` | `5000` | Real-time update interval |

## 🚨 Troubleshooting

### Problem: "Firebase not initialized"
```dart
// Solution: Đảm bảo Firebase đã init trong main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}
```

### Problem: "Permission denied"
- Kiểm tra Firebase Security Rules
- Đảm bảo `.read: true` cho nodes và sensor_data

### Problem: "No data showing"
- Kiểm tra gateway đã chạy chưa
- Xem Firebase Console → Realtime Database → Data tab
- Verify routing_table có data không

### Problem: google-services.json not found
- Download lại từ Firebase Console
- Đặt đúng path: `android/app/google-services.json`
- Run `flutter clean` và rebuild

## 📝 Next Steps

1. ✅ Đã có Firebase config constants
2. ✅ FirebaseService đã dùng database URL
3. ✅ DataService toggle mock/Firebase data
4. ⏳ Cần download google-services.json (Android)
5. ⏳ Cần download GoogleService-Info.plist (iOS)
6. ⏳ Set useMockData = false khi ready
7. ⏳ Test với gateway thật

## 🔗 References

- Firebase Console: https://console.firebase.google.com
- Project: kagri-iot
- Firmware docs: `d:\Projects\Lora\LM_LR_MESH\docs\FIREBASE_INTEGRATION.md`
