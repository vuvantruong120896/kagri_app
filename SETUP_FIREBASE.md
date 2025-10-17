# KAGRI IoT Monitor App

Ứng dụng Flutter để giám sát dữ liệu IoT từ Firebase (nhiệt độ, độ ẩm, v.v.)

## Thiết lập Firebase

### 1. Tạo dự án Firebase
1. Truy cập [Firebase Console](https://console.firebase.google.com/)
2. Tạo dự án mới hoặc sử dụng dự án hiện có
3. Thêm ứng dụng Android và iOS

### 2. Cấu hình Firebase cho Android
1. Tải file `google-services.json` từ Firebase Console
2. Đặt file này vào thư mục `android/app/`
3. Thêm vào `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```
4. Thêm vào `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'

dependencies {
    implementation 'com.google.firebase:firebase-analytics'
}
```

### 3. Cấu hình Firebase cho iOS
1. Tải file `GoogleService-Info.plist` từ Firebase Console
2. Đặt file này vào thư mục `ios/Runner/`
3. Mở `ios/Runner.xcworkspace` trong Xcode
4. Add file `GoogleService-Info.plist` vào project

### 4. Cấu trúc Firebase cần thiết

#### Firestore Collections:
```
/devices/{deviceId}
{
  "id": "device_001",
  "name": "Sensor 1",
  "type": "temperature_humidity", 
  "location": "Nhà kính 1",
  "isOnline": true,
  "lastSeen": timestamp,
  "firmwareVersion": "1.0.0",
  "configuration": {}
}

/sensor_data/{dataId}
{
  "id": "auto_generated",
  "deviceId": "device_001",
  "temperature": 25.5,
  "humidity": 65.2,
  "timestamp": timestamp,
  "location": "Nhà kính 1",
  "batteryLevel": 85.0,
  "signalStrength": 75,
  "additionalData": {}
}
```

#### Realtime Database (optional):
```
/sensor_readings/{deviceId}/{timestamp}
{
  "temperature": 25.5,
  "humidity": 65.2,
  "timestamp": timestamp,
  "batteryLevel": 85.0,
  "signalStrength": 75
}
```

### 5. Security Rules

#### Firestore Rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read access to devices and sensor data
    match /devices/{document=**} {
      allow read: if true;
      allow write: if false; // Only allow from server/firmware
    }
    
    match /sensor_data/{document=**} {
      allow read: if true;
      allow write: if false; // Only allow from server/firmware
    }
  }
}
```

#### Realtime Database Rules:
```json
{
  "rules": {
    "sensor_readings": {
      ".read": true,
      ".write": false
    }
  }
}
```

## Cấu trúc ứng dụng

### Models
- `SensorData`: Dữ liệu từ cảm biến (nhiệt độ, độ ẩm, timestamp, v.v.)
- `Device`: Thông tin thiết bị (ID, tên, trạng thái, v.v.)

### Services
- `FirebaseService`: Xử lý kết nối và truy vấn Firebase

### Screens
- `HomeScreen`: Màn hình chính hiển thị dữ liệu sensor real-time

### Widgets
- `SensorCard`: Widget hiển thị thông tin sensor
- `ChartWidget`: Widget biểu đồ (sẽ implement sau)

## Chạy ứng dụng

```bash
flutter pub get
flutter run
```

## Tính năng hiện tại

✅ Hiển thị dữ liệu sensor real-time từ Firebase
✅ Lọc theo thiết bị
✅ Hiển thị thống kê tổng quan
✅ UI responsive và user-friendly
✅ Hỗ trợ cả Firestore và Realtime Database

## Tính năng sẽ phát triển

🔲 Biểu đồ thời gian thực
🔲 Cảnh báo khi vượt ngưỡng
🔲 Xuất dữ liệu CSV/Excel
🔲 Cài đặt ngưỡng cảnh báo
🔲 Push notifications
🔲 Đăng nhập/phân quyền người dùng
🔲 Backup/restore dữ liệu

## Liên kết với firmware

Để liên kết với firmware từ `D:\Projects\Lora\LM_LR_MESH`, vui lòng:

1. Kiểm tra cấu trúc dữ liệu Firebase trong firmware
2. Đảm bảo tên collection/document khớp với app
3. Cập nhật model `SensorData` nếu cần thêm field
4. Cấu hình Firebase credentials

## Hỗ trợ

Nếu gặp vấn đề, vui lòng cung cấp:
- Cấu trúc Firebase từ firmware
- Log lỗi từ ứng dụng
- Cấu hình Firebase hiện tại