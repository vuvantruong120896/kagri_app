# Handheld WiFi Provisioning - Mobile App Implementation

## Overview
Added complete WiFi provisioning support for Handheld soil sensor devices via BLE.
The Mobile App can now scan for Handheld devices and provision them with WiFi credentials.

## Changes Made

### 1. **Updated BLE Constants** (`lib/constants/ble_constants.dart`)

#### Added Handheld Device Detection
```dart
/// Check if device name is a Handheld
static bool isHandheldDevice(String deviceName) {
  return deviceName.toUpperCase().startsWith(handheldNamePrefix);
}
```

#### Added Handheld UUIDs and Service Constants
```dart
// Handheld WiFi Config BLE Service
static const String handheldWiFiServiceUuid = '0000ffb0-0000-1000-8000-00805f9b34fb';
static const String handheldWiFiCommandCharUuid = '0000ffb1-0000-1000-8000-00805f9b34fb';
static const String handheldWiFiResponseCharUuid = '0000ffb2-0000-1000-8000-00805f9b34fb';

// Handheld Sensor Data BLE Service  
static const String handheldSensorServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
static const String handheldSensorCommandCharUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';
static const String handheldSensorResponseCharUuid = '0000ffe2-0000-1000-8000-00805f9b34fb';
```

#### Updated DeviceType Enum
```dart
enum DeviceType { gateway, node, handheld }

// Added Handheld support to extensions
case DeviceType.handheld:
  return 'Handheld Sensor'; // displayName
  return '📊'; // icon
```

### 2. **Enhanced BLE Provisioning Service** (`lib/services/ble_provisioning_service.dart`)

#### New Method: `provisionHandheldWiFi()`
Provisions Handheld device with WiFi credentials.

**Parameters:**
- `device`: BluetoothDevice to provision
- `ssid`: WiFi network name
- `password`: WiFi password (optional)
- `onProgress`: Callback for progress updates

**Payload sent to device:**
```json
{
  "ssid": "WiFi_SSID",
  "password": "password123",
  "userUID": "user-xxx"
}
```

**Response from device:**
```json
{
  "status": "success",
  "message": "WiFi credentials received",
  "device": "KAGRI-HHC"
}
```

#### Helper Method: `_sendHandheldProvisioningData()`
Internal helper for sending data and waiting for response with timeout.

### 3. **Created Handheld Provisioning Screen** (`lib/screens/handheld_provisioning_screen.dart`)

#### Features:
- **Device Information Display**: Shows connected device name (e.g., KAGRI-HHC-65E0)
- **WiFi Network Scanning**: Automatically scans available WiFi networks
- **Network Selection Dropdown**: Quick select from scanned networks
- **Manual SSID Entry**: Allow entering custom SSID
- **Password Field**: Secure password input with show/hide toggle
- **Real-time Progress**: Circular progress indicator during provisioning
- **Status Messages**: Clear feedback on each step
- **Success/Error Dialogs**: Informative dialogs with next actions
- **Info Section**: Display important notes about credentials

#### UI Components:
1. **Device Info Card** (Blue box)
   - Displays connected device name
   
2. **WiFi Network Field**
   - Text input with prefix icon
   - Dropdown button for scanned networks
   - Refresh button for WiFi scanning
   
3. **Password Field**
   - Secure text input
   - Show/hide password toggle
   
4. **Send Button**
   - Large action button to initiate provisioning
   - Disabled during provisioning
   
5. **Progress Indicator**
   - Circular progress with percentage
   - Status message display
   
6. **Info Section** (Amber box)
   - Notes about credentials storage
   - Device will auto-connect on boot
   - Can reconfigure via BLE anytime

#### Flow:
```
1. Device Discovery Screen
   ↓
2. User taps Handheld device (KAGRI-HHC-XXXX)
   ↓
3. Navigate to HandheldProvisioningScreen
   ↓
4. User selects/enters SSID and password
   ↓
5. User taps "Gửi cấu hình" button
   ↓
6. Progress dialog shown with status updates
   ↓
7. If successful:
   - Show success dialog with SSID info
   - Save provisioning session
   - Return to Discovery Screen
   
   If failed:
   - Show error dialog with error message
   - Allow retry
```

### 4. **Updated Device Discovery Screen** (`lib/screens/device_discovery_screen.dart`)

#### Added Handheld Import
```dart
import 'handheld_provisioning_screen.dart';
```

#### Updated Device Selection Logic
Added special handling for Handheld devices:
```dart
if (deviceType == DeviceType.handheld) {
  // Navigate directly to Handheld provisioning screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>
          HandheldProvisioningScreen(device: result.device),
    ),
  ).then((_) {
    // Resume scanning when returning
    if (mounted) _checkBluetoothAndStartScan();
  });
  return;
}
```

This bypasses the generic provisioning dialog and uses the specialized Handheld UI.

## Architecture

### BLE Communication Flow
```
Mobile App                          Handheld Device
    |                                    |
    |-- Discover BLE Services ---------->|
    |                                    |
    |-- Write WiFi Credentials -------->| (Command Characteristic)
    |   {ssid, password, userUID}       |
    |                                    | (Device processes and saves to NVS)
    |<--------- Success Response ------- | (Response Characteristic - Notify)
    |   {status: "success", ...}        |
    |                                    |
    |-- Disconnect ----------------------|
```

### Data Flow Summary
1. **Scan**: Find KAGRI-HHC-XXXX devices
2. **Connect**: Establish BLE connection
3. **Discover Services**: Find WiFi Config service
4. **Send Credentials**: JSON payload via Command characteristic
5. **Wait for Response**: Listen to Response characteristic (Notify)
6. **Validate**: Check status in response
7. **Success**: Show confirmation or error

## Device Naming Conventions

| Device Type | BLE Name Pattern | Example |
|-------------|------------------|---------|
| Gateway | KAGRI-GW-XXXX | KAGRI-GW-5A2C |
| Node | KAGRI-NODE-XXXX | KAGRI-NODE-AB12 |
| Handheld WiFi Config | KAGRI-HHC-XXXX | KAGRI-HHC-65E0 |
| Handheld Sensor Data | KAGRI-HHT-XXXX | KAGRI-HHT-65E0 |

## Payload Format

### Request (Mobile → Handheld)
```json
{
  "ssid": "NetworkName",
  "password": "password123",
  "userUID": "user@email.com"
}
```

### Response (Handheld → Mobile)
```json
{
  "status": "success",
  "message": "WiFi credentials received",
  "device": "KAGRI-HHC"
}
```

Or on error:
```json
{
  "status": "error",
  "message": "Missing required fields: ssid"
}
```

## Error Handling

The implementation handles:
- ❌ **Empty SSID**: User validation before sending
- ❌ **BLE Connection Timeout**: Retry logic with exponential backoff
- ❌ **Response Timeout**: 30-second timeout with clear error message
- ❌ **JSON Parse Error**: Device validation and user feedback
- ❌ **Bluetooth Not Ready**: Check and request permission

## Testing Checklist

- [ ] Handheld device advertising with correct name (KAGRI-HHC-XXXX)
- [ ] Device appears in Device Discovery screen
- [ ] Can select Handheld device and navigate to provisioning screen
- [ ] WiFi scan works and populates dropdown
- [ ] Manual SSID entry works
- [ ] Password show/hide toggle works
- [ ] Provisioning sends correct JSON payload
- [ ] Receives and parses success response
- [ ] Shows progress during provisioning
- [ ] Shows success dialog on completion
- [ ] Credentials saved to device NVS
- [ ] Device automatically connects on next boot
- [ ] Error handling works correctly
- [ ] Can return to Discovery screen and scan again

## Future Enhancements

1. **Sensor Data Reception**: Add UI to receive sensor data via KAGRI-HHT service
2. **Credentials Update**: Allow updating WiFi without re-provisioning
3. **Offline Sync**: Store provisioning data for retry if network unavailable
4. **Multi-Device Provisioning**: Batch provision multiple Handheld devices
5. **Device Naming**: Allow renaming devices after provisioning
6. **Connection History**: Show previously provisioned Handheld devices

## Files Modified/Created

| File | Action | Description |
|------|--------|-------------|
| `lib/constants/ble_constants.dart` | Modified | Added Handheld UUIDs and device detection |
| `lib/services/ble_provisioning_service.dart` | Modified | Added Handheld provisioning methods |
| `lib/screens/handheld_provisioning_screen.dart` | Created | UI for WiFi provisioning |
| `lib/screens/device_discovery_screen.dart` | Modified | Added Handheld navigation |

## Status
✅ **Ready for Testing** - All implementation complete and tested for compilation
