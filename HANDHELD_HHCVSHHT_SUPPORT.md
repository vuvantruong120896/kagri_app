# Mobile App - Handheld Device Support (KAGRI-HHC vs KAGRI-HHT)

## Overview

Updated Mobile App to distinguish between two Handheld device modes:
- **KAGRI-HHC** - WiFi Configuration mode (device sends WiFi config to Handheld)
- **KAGRI-HHT** - Sensor Data mode (device receives sensor data from Handheld)

## Implementation Details

### 1. **BLE Constants Enhancement** (`ble_constants.dart`)

#### New Device Prefixes
```dart
static const String handheldWiFiNamePrefix = 'KAGRI-HHC-';  // WiFi config
static const String handheldSensorNamePrefix = 'KAGRI-HHT-'; // Sensor data
```

#### New Handheld Type Enum
```dart
enum HandheldType { wiFiConfig, sensorData }

extension HandheldTypeExtension on HandheldType {
  String get displayName;        // "WiFi Configuration" or "Sensor Data"
  String get description;         // User-friendly description
  String get icon;                // 📡 or 📊
}
```

#### New Helper Methods
```dart
/// Check if device is Handheld in WiFi Config mode (KAGRI-HHC-XXXX)
static bool isHandheldWiFiDevice(String deviceName)

/// Check if device is Handheld in Sensor Data mode (KAGRI-HHT-XXXX)
static bool isHandheldSensorDevice(String deviceName)

/// Get Handheld sub-type (WiFi config or Sensor data)
static HandheldType? getHandheldType(String deviceName)
```

### 2. **Device Discovery Flow** (`device_discovery_screen.dart`)

**Updated Selection Logic:**

```
Device Scan
    ↓
Device Selected
    ↓
├─ Gateway → Gateway Provisioning
├─ Node → Node Provisioning
└─ Handheld → Check Sub-Type
    ├─ KAGRI-HHC → WiFi Provisioning Screen
    └─ KAGRI-HHT → Sensor Data Reception Screen
```

**Code Flow:**
```dart
final handheldType = BleConstants.getHandheldType(deviceName);

if (handheldType == HandheldType.wiFiConfig) {
  // KAGRI-HHC: Navigate to WiFi provisioning
  Navigator.push(HandheldProvisioningScreen);
} else if (handheldType == HandheldType.sensorData) {
  // KAGRI-HHT: Navigate to sensor data reception
  Navigator.push(HandheldSensorDataScreen);
}
```

### 3. **Handheld WiFi Provisioning Screen** (`handheld_provisioning_screen.dart`)

**Purpose:** Configure WiFi credentials on KAGRI-HHC devices

**Features:**
- Device info display (shows KAGRI-HHC-XXXX)
- WiFi SSID input field
- Password field with show/hide toggle
- Real-time provisioning progress
- Success/error dialogs
- Credentials saved to device NVS

**BLE Communication:**
- **Service UUID:** `0000ffb0-0000-1000-8000-00805f9b34fb`
- **Send Payload:** `{ssid, password, userUID}`
- **Receive Response:** `{status: "success"}`

### 4. **Handheld Sensor Data Reception Screen** (NEW) (`handheld_sensor_data_screen.dart`)

**Purpose:** Receive sensor data from KAGRI-HHT devices

**Features:**
- Real-time sensor data display
- Support for all sensors:
  - Temperature (°C)
  - Moisture (%)
  - EC (mS/cm)
  - pH
  - N, P, K (mg/kg)
- Connection status monitoring
- Timestamp tracking
- Data point counter
- Formatted sensor readings with colors

**BLE Communication:**
- **Service UUID:** `0000ffe0-0000-1000-8000-00805f9b34fb`
- **Receive Data:** JSON with sensor readings
- **Example Payload:**
```json
{
  "temp": 25.5,
  "moisture": 45.2,
  "ec": 0.8,
  "ph": 6.5,
  "n": 120,
  "p": 50,
  "k": 180,
  "timestamp": 1700000000
}
```

## Device Mode Selection

| Mode | BLE Name | Action | Screen |
|------|----------|--------|--------|
| **WiFi Config** | KAGRI-HHC-65E0 | Send WiFi credentials | HandheldProvisioningScreen |
| **Sensor Data** | KAGRI-HHT-65E0 | Receive sensor data | HandheldSensorDataScreen |

## User Flow

### WiFi Configuration (KAGRI-HHC)
```
1. Device Discovery Screen
   ↓
2. Scan and find "KAGRI-HHC-65E0"
   ↓
3. Tap device
   ↓
4. Navigate to HandheldProvisioningScreen
   ↓
5. Enter WiFi SSID & password
   ↓
6. Progress dialog (connecting → sending → success/error)
   ↓
7. Device saves credentials to NVS
   ↓
8. Return to Discovery Screen
```

### Sensor Data Reception (KAGRI-HHT)
```
1. Device Discovery Screen
   ↓
2. Scan and find "KAGRI-HHT-65E0"
   ↓
3. Tap device
   ↓
4. Navigate to HandheldSensorDataScreen
   ↓
5. Auto-connect to device
   ↓
6. Wait for sensor data
   ↓
7. Display readings when received
   ↓
8. Show timestamp & data counter
   ↓
9. User can exit or wait for next update
```

## Sensor Data Display

**Color-coded sensor readings:**
- 🔴 Temperature: Red
- 🔵 Moisture: Blue
- 🟣 EC: Purple
- 🟢 pH: Green
- 🟠 N: Amber
- 🟤 P: Orange
- 🔷 K: Teal

**Formatted Display:**
```
┌─────────────────────┐
│ Nhiệt độ            │
│ 25.50 °C            │
└─────────────────────┘
```

## Error Handling

**Sensor Data Screen:**
- Connection timeout → Show error dialog
- Invalid JSON → Log and continue waiting
- No data received → Show "Chờ dữ liệu..." with spinner
- Device disconnect → Show "Ngắt" status

**WiFi Provisioning Screen:**
- Empty SSID → Validation before sending
- BLE connection fail → Retry logic
- Response timeout → Error with retry option

## Architecture Improvements

### Separation of Concerns
- **KAGRI-HHC** → WiFi Management
- **KAGRI-HHT** → Data Reception
- Clear routing based on device mode

### Type Safety
- Enum-based device type detection
- Compile-time checking for device types
- Clear method naming: `isHandheldWiFiDevice()` vs `isHandheldSensorDevice()`

### Extensibility
- Easy to add more Handheld sub-types in future
- `HandheldType` enum can be extended
- Helper methods follow same pattern as Gateway/Node

## Files Modified/Created

| File | Action | Purpose |
|------|--------|---------|
| `lib/constants/ble_constants.dart` | Modified | Added Handheld type detection |
| `lib/screens/device_discovery_screen.dart` | Modified | Route to specific Handheld screens |
| `lib/screens/handheld_provisioning_screen.dart` | Existing | WiFi config for KAGRI-HHC |
| `lib/screens/handheld_sensor_data_screen.dart` | **Created** | Sensor data reception for KAGRI-HHT |

## Testing Checklist

- [ ] Device Discovery finds both KAGRI-HHC and KAGRI-HHT
- [ ] KAGRI-HHC opens WiFi provisioning screen
- [ ] KAGRI-HHT opens sensor data screen
- [ ] WiFi provisioning sends correct payload
- [ ] Device receives and parses response
- [ ] Sensor data screen connects to device
- [ ] Sensor data parsed and displayed correctly
- [ ] All sensor readings show with proper units
- [ ] Timestamp updates on new data
- [ ] Connection status indicator works
- [ ] Error handling works for both modes
- [ ] Can return to Discovery and scan again

## Future Enhancements

1. **Streaming**: Continuously receive updates from KAGRI-HHT
2. **Data Export**: Save sensor data to file
3. **Alerts**: Notify when values exceed thresholds
4. **History**: Store historical data points
5. **Multiple Devices**: Monitor multiple Handheld devices
6. **Charting**: Plot sensor data over time

## Status
✅ **IMPLEMENTATION COMPLETE** - All code compiles and ready for testing
