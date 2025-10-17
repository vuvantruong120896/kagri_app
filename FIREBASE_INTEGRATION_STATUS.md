# Firebase Integration - Status & Next Steps

## ✅ Completed

### 1. Models Updated (Firebase Schema Compliant)
- **SensorData** (`lib/models/sensor_data.dart`)
  - Changed `deviceId` → `nodeId` (hex format: "0xCC64")
  - Added `counter` field (packet sequence)
  - Changed `batteryLevel` → `battery` (voltage in V)
  - Changed `signalStrength` → `rssi` (dBm)
  - Added `snr` field (Signal-to-Noise Ratio)
  - Removed `location` and `additionalData`
  - Added helper methods: `batteryPercentage`, `isBatteryLow`, `isSignalWeak`

- **Device** (`lib/models/device.dart`)
  - Changed `id` → `nodeId` (hex format)
  - Removed `location`, `isOnline`, `configuration` fields
  - Added `createdAt` timestamp
  - `isOnline` is now a computed getter (last seen < 2 minutes)
  - Added `lastSeenText` helper

- **GatewayStatus** (`lib/models/gateway_status.dart`) - NEW
  - Matches Firebase `gateways/{gatewayId}/status` structure
  - Fields: connectedNodes, packets stats, WiFi/Firebase status, uptime, heap

### 2. Services Updated

- **FirebaseService** (`lib/services/firebase_service.dart`)
  - Completely rewritten for Firebase Realtime Database
  - Removed Firestore dependency
  - Implements firmware schema:
    * `getNodesStream()` - nodes with latest_data
    * `getLatestDataStream(nodeId)` - real-time latest data
    * `getSensorDataStream(nodeId)` - historical timeseries
    * `getSensorDataByDateRange()` - date-filtered queries
    * `getGatewayStatusStream(gatewayId)` - gateway health
    * `addSensorData()`, `updateNodeInfo()`, `cleanupOldData()`

- **MockDataService** (`lib/services/mock_data_service.dart`)
  - Updated to generate hex node IDs ('0xCC64', '0x4F70', '0x09F8')
  - Generate battery voltage (3.0-4.2V) instead of percentage
  - Generate RSSI (-40 to -80 dBm) and SNR (5-12 dB)
  - Removed location field

- **DataService** (`lib/services/data_service.dart`)
  - Updated all methods to use `nodeId` instead of `deviceId`
  - `getSensorDataStream(nodeId)`
  - `getDevicesStream()`
  - `getSensorDataByDateRange(nodeId, startDate, endDate)`

## ⏳ Pending - UI Updates

### Files Needing Updates:

1. **sensor_card.dart** - Replace references:
   - `sensorData.deviceId` → `sensorData.nodeId`
   - `sensorData.location` → Remove (or get from Device.name)
   - `sensorData.batteryLevel` → `sensorData.batteryPercentage`
   - `sensorData.signalStrength` → `sensorData.rssi` (display as dBm, not %)
   - Update battery icon logic to use voltage

2. **home_screen.dart** - Replace references:
   - `device.id` → `device.nodeId`
   - `deviceId:` parameter → `nodeId:`
   - Update device filter dropdown to use `device.nodeId`
   - Update statistics calculation for new fields
   - Show device online/offline status using `device.isOnline` getter

## 📋 Firebase Configuration Steps

### 1. Firebase Console Setup
```
1. Go to https://console.firebase.google.com
2. Select project: kagri-iot (or create new)
3. Enable Realtime Database (NOT Firestore)
4. Get Database URL: https://kagri-iot-default-rtdb.asia-southeast1.firebasedatabase.app
5. Get Database Secret:
   - Project Settings → Service Accounts
   - Database Secrets tab → Generate Secret
   - Copy: 0kMDkyCxejcJB350HrFlgBmb3Y5PsOiR90ZXf1MV (example from firmware)
```

### 2. Download Configuration Files

**For Android** (`android/app/google-services.json`):
```bash
# From Firebase Console:
# Project Settings → General → Your apps → Android app
# Download google-services.json
# Place at: android/app/google-services.json
```

**For iOS** (`ios/Runner/GoogleService-Info.plist`):
```bash
# From Firebase Console:
# Project Settings → General → Your apps → iOS app
# Download GoogleService-Info.plist
# Place at: ios/Runner/GoogleService-Info.plist
```

### 3. Security Rules
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

### 4. Update Data Service
```dart
// In lib/services/data_service.dart
bool useMockData = false; // Change to false once Firebase configured
```

## 🔍 Database Structure (Firmware)

```
firebase-root/
├── nodes/
│   ├── 0xCC64/
│   │   ├── info/
│   │   │   ├── address: "0xCC64"
│   │   │   ├── name: "Sensor Node 1"
│   │   │   ├── type: "sensor"
│   │   │   ├── firmware_version: "1.0.0"
│   │   │   ├── created_at: 1760607000
│   │   │   └── last_seen: 1760607651
│   │   └── latest_data/
│   │       ├── counter: 1234
│   │       ├── temperature: 25.5
│   │       ├── humidity: 65.0
│   │       ├── battery: 3.7
│   │       ├── timestamp: 1760607651
│   │       ├── rssi: -45
│   │       └── snr: 10.5
│   ├── 0x4F70/
│   └── 0x09F8/
├── sensor_data/
│   ├── 0xCC64/
│   │   ├── 1760607651/
│   │   │   ├── counter: 1234
│   │   │   ├── temperature: 25.5
│   │   │   ├── humidity: 65.0
│   │   │   ├── battery: 3.7
│   │   │   ├── rssi: -45
│   │   │   └── snr: 10.5
│   │   └── 1760607711/
│   ├── 0x4F70/
│   └── 0x09F8/
└── gateways/
    └── GW_1234/
        ├── status/
        │   ├── connected_nodes: 3
        │   ├── total_packets_received: 1523
        │   ├── wifi_connected: true
        │   ├── wifi_rssi: -52
        │   ├── firebase_connected: true
        │   ├── uptime_seconds: 3600
        │   ├── free_heap: 189456
        │   └── timestamp: 1760607651
        └── routing_table/
            ├── node_count: 3
            ├── timestamp: 1760607651
            └── nodes/
                ├── 0xCC64/
                │   ├── address: "0xCC64"
                │   ├── via: "0xCC64"
                │   ├── metric: 1
                │   ├── role: 1
                │   ├── rssi: -45
                │   └── snr: 10.5
                ├── 0x4F70/
                └── 0x09F8/
```

## 🐛 Quick Fixes Needed

### sensor_card.dart
```dart
// Line 42: Change
sensorData.deviceId → sensorData.nodeId

// Lines 45-47: Remove location references (or get from parent Device)

// Lines 86-117: Update battery and signal display
// Battery: Use sensorData.batteryPercentage (computed from voltage)
// Signal: Use sensorData.rssi (display as "-XX dBm" not percentage)
```

### home_screen.dart
```dart
// Line 109: Change
value: device.id → value: device.nodeId

// Line 122: Change
device.id → device.nodeId

// Lines 149, 196: Change parameter name
deviceId: → nodeId:

// Lines 329, 334: Change
sensorData.deviceId → sensorData.nodeId

// Lines 341-346: Update for new field names
// Remove location, update battery/signal display
```

## 📊 Testing Checklist

Once Firebase is configured:

- [ ] App starts without errors
- [ ] Toggle data source button works (cloud icon in AppBar)
- [ ] Mock data shows 3 devices with hex IDs
- [ ] Connect to Firebase - should see same data structure
- [ ] Real-time updates work (sensor values change)
- [ ] Device filter dropdown works
- [ ] Statistics (avg temp/humidity) calculate correctly
- [ ] Sensor card displays battery voltage correctly
- [ ] RSSI shows as "-XX dBm" not percentage
- [ ] Device online/offline status updates

## 🎯 Integration Complete Criteria

1. ✅ Models match Firebase schema
2. ✅ Services use correct paths
3. ⏳ UI components updated for new fields
4. ⏳ Firebase configuration files added
5. ⏳ Test with actual gateway data
6. ⏳ Verify real-time updates work

## 📚 References

- Firmware docs: `d:\Projects\Lora\LM_LR_MESH\docs\FIREBASE_INTEGRATION.md`
- Firebase schema: `d:\Projects\Lora\LM_LR_MESH\docs\PHASE3_1_FIREBASE_SCHEMA.md`
- Mobile app: `e:\mobile_app\kagri_app\`
