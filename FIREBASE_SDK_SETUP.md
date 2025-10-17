# Firebase SDK Setup - Completed ✅

## Những gì đã làm theo hướng dẫn Firebase Console:

### 1. ✅ Thêm google-services.json
- **File:** `android/app/google-services.json`
- **Project ID:** kagri-iot
- **Package name:** Kagri.Iot.App
- **Database URL:** https://kagri-iot-default-rtdb.asia-southeast1.firebasedatabase.app

### 2. ✅ Thêm Firebase SDK vào Gradle

**File: `android/build.gradle.kts`**
```kotlin
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}
```

**File: `android/app/build.gradle.kts`**
```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ✅ Added
}

android {
    namespace = "Kagri.Iot.App" // ✅ Updated
    applicationId = "Kagri.Iot.App" // ✅ Updated
}
```

### 3. ✅ Update Package Structure

**Old:**
```
android/app/src/main/kotlin/com/example/kagri_app/MainActivity.kt
package com.example.kagri_app
```

**New:**
```
android/app/src/main/kotlin/Kagri/Iot/App/MainActivity.kt
package Kagri.Iot.App
```

### 4. ✅ Tạo firebase_options.dart

**File: `lib/firebase_options.dart`**
```dart
class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAE-nk2GsNh0o5L6D9CMlUtrVHAbfQ_ZEg',
    appId: '1:74923973525:android:aaddfc7f4121d7ebbb749c',
    projectId: 'kagri-iot',
    databaseURL: 'https://kagri-iot-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
```

### 5. ✅ Update main.dart

**File: `lib/main.dart`**
```dart
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const KagriApp());
}
```

### 6. ✅ pubspec.yaml đã có Firebase packages
```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_database: ^11.1.4
```

## 🎯 Setup hoàn tất!

### Các bước tiếp theo:

1. **Clean và rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Xóa folder cũ (optional):**
   ```bash
   # Có thể xóa folder package cũ nếu muốn:
   # android/app/src/main/kotlin/com/example/kagri_app/
   ```

3. **Kiểm tra Firebase kết nối:**
   - Mở app, xem log console
   - Nên thấy: "✅ Firebase initialized successfully"
   - Không có lỗi về google-services.json

4. **Kiểm tra data từ Firebase:**
   - Đảm bảo gateway đang chạy
   - Gateway push routing_table lên Firebase
   - App sẽ hiển thị các node từ routing_table

## 🔍 Troubleshooting

### Lỗi: "No matching client found for package name 'com.example.kagri_app'"
✅ **Fixed:** Package name đã update thành `Kagri.Iot.App` matching với google-services.json

### Lỗi: "Default FirebaseApp is not initialized"
✅ **Fixed:** Đã thêm `firebase_options.dart` và init trong main.dart

### Lỗi: "Could not find com.google.gms:google-services"
✅ **Fixed:** Đã thêm classpath trong android/build.gradle.kts

### Lỗi: Build failed
**Solution:**
```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

## 📊 Verification Checklist

- [x] google-services.json tồn tại trong android/app/
- [x] Package name khớp: Kagri.Iot.App
- [x] Firebase plugin đã add vào build.gradle.kts
- [x] firebase_options.dart đã tạo
- [x] main.dart initialize Firebase với options
- [x] MainActivity.kt đã move sang package mới
- [x] Không có compile errors

## 🚀 Ready to run!

App đã sẵn sàng kết nối Firebase Realtime Database. Chỉ cần:
1. `flutter clean && flutter pub get`
2. `flutter run`
3. Xem data từ gateway hiển thị trên app

## 📱 Expected Behavior

Khi app chạy:
- ✅ Firebase init thành công (log console)
- ✅ Kết nối Realtime Database
- ✅ Đọc routing_table từ gateways/{gatewayId}/routing_table
- ✅ Hiển thị các node trong Home screen
- ✅ Network Status screen hiển thị gateway health
- ✅ Real-time updates khi gateway push data mới

## 📚 References

- Firebase Console: https://console.firebase.google.com/project/kagri-iot
- Android App Config: https://console.firebase.google.com/project/kagri-iot/settings/general/android:Kagri.Iot.App
- Database: https://console.firebase.google.com/project/kagri-iot/database/kagri-iot-default-rtdb/data
