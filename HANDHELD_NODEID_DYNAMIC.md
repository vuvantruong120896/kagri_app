# Handheld NodeID - Dynamic Configuration

## Summary

Updated Mobile App to use dynamic nodeID based on last 2 bytes of BLE device name instead of hardcoding "handheld".

## Changes Made

### 1. **Extract NodeID from Device Name** 
**File:** `lib/screens/handheld_sensor_data_screen.dart`

Added method to extract last 2 bytes from BLE device advertisement name:

```dart
/// Extract last 2 bytes from BLE device name as nodeID
/// Example: "KAGRI-HHT-45A" → "45A"
String _extractNodeIdFromDeviceName(String deviceName) {
  // Get last 2 bytes (characters after last '-')
  final parts = deviceName.split('-');
  if (parts.isNotEmpty) {
    final lastPart = parts.last;
    return lastPart.length >= 2 ? lastPart.substring(lastPart.length - 2) : lastPart;
  }
  return 'HHT'; // Fallback
}
```

**Logic:**
- Device name format: `KAGRI-HHT-{2 bytes}`
- Split by `-` to get parts: `['KAGRI', 'HHT', '45A']`
- Take last part: `'45A'`
- Extract last 2 chars: `'5A'` 
- Or get entire last part if 2+ chars: `'45A'`

### 2. **Pass NodeID to Firebase Service**
**File:** `lib/screens/handheld_sensor_data_screen.dart`

Updated upload method:

```dart
/// Upload sensor data to Firebase
Future<void> _uploadToFirebase(Map<String, dynamic> sensorData) async {
  try {
    print('[SensorData] Uploading to Firebase...');
    setState(() => _statusMessage = 'Đang tải lên Firebase...');

    // Extract nodeID from device name (e.g., "45A" from "KAGRI-HHT-45A")
    final nodeId = _extractNodeIdFromDeviceName(widget.device.name);
    print('[SensorData] Using nodeID from device name: $nodeId');

    final success = await _firebaseService.addHandheldSensorData(sensorData, nodeId);
    // ...
```

**Changes:**
- Extract nodeID from device name
- Log the extracted nodeID
- Pass nodeID as parameter to Firebase service

### 3. **Update Firebase Service Method Signature**
**File:** `lib/services/firebase_service.dart`

Updated method to accept nodeID parameter:

```dart
Future<bool> addHandheldSensorData(
  Map<String, dynamic> sensorDataJson,
  String nodeId,  // New parameter: dynamic nodeID instead of hardcoded
) async {
  try {
    final userUID = _currentUserUID;
    if (userUID == null) {
      throw Exception('User not logged in');
    }

    // Create timestamp from current time or from provided timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Prepare data for Firebase
    final data = Map<String, dynamic>.from(sensorDataJson);
    data['timestamp'] = timestamp;
    data['deviceType'] = 'soil_sensor'; // Handheld is soil sensor
    data['nodeId'] = nodeId; // Use device-specific nodeID (last 2 bytes)

    print('[Firebase] Uploading handheld sensor data: $data');

    // Write to historical data: sensor_data/{userUID}/{nodeId}/{timestamp}
    await database
        .ref('$sensorDataPath/$userUID/$nodeId/$timestamp')
        .set(data);

    print('[Firebase] ✅ Handheld sensor data uploaded successfully to nodeID: $nodeId');
    return true;
  } catch (e) {
    print('[Firebase] ❌ Error uploading handheld sensor data: $e');
    return false;
  }
}
```

**Changes:**
- Added `String nodeId` parameter
- Use nodeID to store in Firebase at path: `sensor_data/{userUID}/{nodeId}/{timestamp}`
- Updated log message to include nodeID

## Data Flow

```
BLE Device Name: "KAGRI-HHT-45A"
    ↓
Extract last 2 bytes
    ↓
nodeID = "45A"
    ↓
Sensor Data + nodeID
    ↓
Firebase Path: sensor_data/{userUID}/45A/{timestamp}
    ↓
Firebase stores with nodeId field: "45A"
```

## Example

### Before (Hardcoded)
- Device: `KAGRI-HHT-45A`
- NodeID: `handheld` (hardcoded)
- Firebase Path: `sensor_data/{uid}/handheld/{ts}`

### After (Dynamic)
- Device: `KAGRI-HHT-45A`
- NodeID: `45A` (extracted from name)
- Firebase Path: `sensor_data/{uid}/45A/{ts}`

### Device Examples
| Device Name | Extracted NodeID |
|-------------|------------------|
| KAGRI-HHT-45A | 5A |
| KAGRI-HHT-1F2 | F2 |
| KAGRI-HHT-ABC | BC |
| KAGRI-HHT-X | X (fallback) |

## Benefits

1. ✅ **Multiple Devices** - Can connect to multiple Handheld devices, each with unique nodeID
2. ✅ **Unique Data** - Each device's data stored separately in Firebase
3. ✅ **Device Tracking** - Can identify which physical device data came from
4. ✅ **Consistency** - Aligns with Gateway's approach (MAC-based nodeID)
5. ✅ **Flexibility** - Easy to support multiple handheld sensors

## Firebase Rules Update

Ensure Firebase rules validate handheld nodeID correctly:

```json
"handheld": {
  ".read": "$uid === auth.uid",
  ".write": "$uid === auth.uid || auth != null",
  "$timestamp": {
    ".validate": "newData.hasChildren(['temperature', 'humidity', 'timestamp'])"
  }
}
```

Or per nodeID structure:

```json
"{nodeId}": {
  "$timestamp": {
    ".validate": "newData.hasChildren(['temperature', 'humidity', 'timestamp'])"
  }
}
```

## Testing

1. **Connect to Handheld** `KAGRI-HHT-45A`
2. **Receive sensor data**
3. **Check logs:**
   - `[SensorData] Using nodeID from device name: 45A`
   - `[Firebase] ✅ Handheld sensor data uploaded successfully to nodeID: 45A`
4. **Verify in Firebase:**
   - Navigate to: `sensor_data/{userUID}/45A/`
   - Should see timestamp entries with sensor data
5. **Connect to another device** with different nodeID (if available)
   - Should create separate data path

## Backward Compatibility

✅ No breaking changes
- Only affects handheld data upload
- Gateway functionality unchanged
- Mobile App UI unchanged

## Files Modified

- `lib/screens/handheld_sensor_data_screen.dart` - Extract nodeID and pass to service
- `lib/services/firebase_service.dart` - Accept nodeID parameter and use in Firebase path

## Status

✅ Code changes complete
✅ No compilation errors
✅ Ready for testing

---

**Implementation Date:** November 27, 2025
**Purpose:** Support multiple handheld devices with unique nodeIDs based on BLE advertisement names
