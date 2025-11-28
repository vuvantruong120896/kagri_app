# Handheld Sensor Data Firebase Upload

## Overview
Handheld sensor data received via BLE is automatically uploaded to Firebase Realtime Database after successful reception.

## Data Flow

```
┌─────────────────────┐
│  Handheld Device    │
│  (ESP32-S3)         │
└──────────┬──────────┘
           │ BLE: Sensor Data (JSON)
           ▼
┌─────────────────────┐
│   Mobile App        │
│ (handheld_sensor_   │
│  data_screen.dart)  │
└──────────┬──────────┘
           │ Parse JSON
           │ _uploadToFirebase()
           ▼
┌─────────────────────┐
│  Firebase Service   │
│ addHandheldSensor   │
│ Data()              │
└──────────┬──────────┘
           │ Store Data
           ▼
┌─────────────────────────┐
│ Firebase Realtime DB    │
│ sensor_data/            │
│ {userUID}/handheld/     │
│ {timestamp}/            │
│ {sensor_data}           │
└─────────────────────────┘
```

## Implementation Details

### 1. Handheld Sensor Data Screen (`handheld_sensor_data_screen.dart`)

**Data Reception:**
```dart
subscription = sensorDataChar.onValueReceived.listen((value) async {
  if (value.isNotEmpty && !dataReceived) {
    // Parse JSON
    final data = jsonDecode(dataStr) as Map<String, dynamic>;
    
    // Set loading state
    setState(() {
      _sensorData = data;
      _statusMessage = 'Đã nhận dữ liệu cảm biến!';
      _isUploading = true;
      dataReceived = true;
    });
    
    // Upload to Firebase
    await _uploadToFirebase(data);
  }
});
```

**Upload Method:**
```dart
Future<void> _uploadToFirebase(Map<String, dynamic> sensorData) async {
  try {
    setState(() => _statusMessage = 'Đang tải lên Firebase...');
    
    final success = await _firebaseService.addHandheldSensorData(sensorData);
    
    if (mounted) {
      setState(() {
        _isUploading = false;
        if (success) {
          _statusMessage = '✅ Dữ liệu đã lưu lên Firebase!';
        } else {
          _statusMessage = '⚠️ Lỗi tải lên Firebase';
        }
      });
    }
  } catch (e) {
    // Handle error
  }
}
```

### 2. Firebase Service (`firebase_service.dart`)

**Upload Method:**
```dart
Future<bool> addHandheldSensorData(Map<String, dynamic> sensorDataJson) async {
  try {
    final userUID = _currentUserUID;
    if (userUID == null) {
      throw Exception('User not logged in');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final data = Map<String, dynamic>.from(sensorDataJson);
    data['timestamp'] = timestamp;
    data['deviceType'] = 'soil_sensor';
    data['nodeId'] = 'handheld';

    // Write to sensor_data/{userUID}/handheld/{timestamp}
    await database
        .ref('sensor_data/$userUID/handheld/$timestamp')
        .set(data);

    return true;
  } catch (e) {
    print('[Firebase] Error uploading handheld sensor data: $e');
    return false;
  }
}
```

### 3. Firebase Data Structure

**Path:** `sensor_data/{userUID}/handheld/{timestamp}`

**Example Data:**
```json
{
  "timestamp": 1732689600,
  "deviceType": "soil_sensor",
  "nodeId": "handheld",
  "temp": 28.5,
  "temperature": 28.5,
  "moisture": 65.3,
  "ec": 2.1,
  "ph": 7.2,
  "n": 145,
  "p": 98,
  "k": 210
}
```

## Status Messages

| Status | Message | Description |
|--------|---------|-------------|
| Connecting | `Kết nối đến Handheld...` | Connecting to BLE device |
| Discovering | `Tìm kiếm BLE services...` | Searching for BLE services |
| Waiting | `Chờ dữ liệu cảm biến...` | Waiting for sensor data |
| Received | `Đã nhận dữ liệu cảm biến!` | Data received from Handheld |
| Uploading | `Đang tải lên Firebase...` | Uploading to Firebase |
| Success | `✅ Dữ liệu đã lưu lên Firebase!` | Upload successful |
| Error | `⚠️ Lỗi tải lên Firebase` | Upload failed |

## Error Handling

- **No user logged in:** Firebase upload fails gracefully
- **Network error:** Exception caught and displayed to user
- **Firebase unavailable:** Error message shown with exception details

## Testing Checklist

- [ ] Connect Handheld device via BLE
- [ ] Subscribe to sensor data
- [ ] Receive data successfully
- [ ] Verify upload status changes to "Đang tải lên Firebase..."
- [ ] Check Firebase console for data in `sensor_data/{userUID}/handheld/`
- [ ] Verify timestamp matches current time
- [ ] Verify all sensor fields are present

## Related Files

- `lib/screens/handheld_sensor_data_screen.dart` - BLE data reception and upload UI
- `lib/services/firebase_service.dart` - Firebase upload implementation
- `lib/models/sensor_data.dart` - Sensor data model
- `lib/services/auth_service.dart` - Authentication (provides userUID)

## Future Enhancements

- [ ] Retry logic for failed uploads
- [ ] Offline data queuing
- [ ] Batch upload for multiple readings
- [ ] Upload progress indication
- [ ] Historical data view for handheld readings
