# Test Plan: Handheld Sensor Data Firebase Upload

## Setup
- [ ] Handheld device (ESP32-S3) powered on and in SENSOR_DATA_TRANSFER mode
- [ ] Mobile app (Flutter) running on Android/iOS
- [ ] Mobile app logged in with Firebase account
- [ ] Firebase console open for verification
- [ ] Handheld advertising BLE service (KAGRI-HHT-XXXX)

## Test 1: Single Data Reception and Upload

**Steps:**
1. Open Mobile App → Device Discovery Screen
2. Scan for available Handheld devices
3. Find and tap on `KAGRI-HHT-XXXX` device
4. Observe screen transitions:
   - "Kết nối đến Handheld..." (Connecting)
   - "Tìm kiếm BLE services..." (Discovering services)
   - "Chờ dữ liệu cảm biến..." (Waiting for data)

5. On Handheld: Press power button 5s to enter SENSOR_DATA_TRANSFER mode
6. Sensor data should start being transmitted
7. Observe Mobile App status:
   - "Đã nhận dữ liệu cảm biến!" (Data received)
   - "Đang tải lên Firebase..." (Uploading)
   - "✅ Dữ liệu đã lưu lên Firebase!" (Success)

**Expected Results:**
- ✅ Connection established (🟢 Kết nối)
- ✅ Sensor readings displayed (Temp, Moisture, EC, pH, NPK)
- ✅ Last update timestamp shown
- ✅ Data counter shows "Tổng số lần nhận: 1"
- ✅ Status message shows success

**Firebase Verification:**
1. Firebase Console → Realtime Database
2. Navigate to: `sensor_data/{userUID}/handheld/`
3. Verify entry with current timestamp exists
4. Verify data structure contains:
   ```json
   {
     "timestamp": <current_unix_timestamp>,
     "deviceType": "soil_sensor",
     "nodeId": "handheld",
     "temp": <value>,
     "moisture": <value>,
     "ec": <value>,
     "ph": <value>,
     "n": <value>,
     "p": <value>,
     "k": <value>
   }
   ```

## Test 2: Multiple Data Receptions (Repeated Cycles)

**Steps:**
1. Complete Test 1
2. After Handheld shows success screen and reboots
3. From home screen, press button 5s again → SENSOR_DATA_TRANSFER mode
4. Repeat data transmission from Handheld
5. Observe second upload cycle

**Expected Results:**
- ✅ Second upload succeeds
- ✅ New Firebase entry created with updated timestamp
- ✅ Both entries visible in `sensor_data/{userUID}/handheld/`
- ✅ Status shows "✅ Dữ liệu đã lưu lên Firebase!" again

**Firebase Verification:**
1. Check `sensor_data/{userUID}/handheld/`
2. Verify 2 entries exist with different timestamps
3. Verify data structure is identical for both

## Test 3: Upload Failure Handling

**Steps:**
1. Disconnect mobile device from internet/WiFi
2. Repeat data reception
3. Observe error handling

**Expected Results:**
- ✅ Data is received successfully
- ✅ Upload attempt is made
- ✅ Error message displayed: "❌ Lỗi: User not logged in" or network error
- ✅ App doesn't crash

**Note:** In offline mode, check if AuthService returns null for userUID

## Test 4: Not Logged In

**Steps:**
1. Logout from Mobile App
2. Try to receive Handheld data
3. Observe error handling

**Expected Results:**
- ✅ Data is received
- ✅ Upload attempt fails with: "❌ Lỗi: User not logged in"
- ✅ App displays error gracefully
- ✅ No crash

## Test 5: UI State Verification

**Checklist:**
- [ ] Connection status indicator (🟢/🔴) updates correctly
- [ ] Progress spinner shows during upload
- [ ] Status text updates through all phases
- [ ] Sensor data displays all fields correctly
- [ ] Timestamp format is readable
- [ ] Data counter increments correctly
- [ ] Can dismiss error dialogs without crash

## Test 6: Data Integrity

**Firebase Console Verification:**
```dart
// Sample query to verify data in Firebase Console
sensor_data/{userUID}/handheld

// Expected structure for each timestamp
{
  "timestamp": 1732689600,
  "deviceType": "soil_sensor",
  "nodeId": "handheld",
  "temp": 28.5,
  "temperature": 28.5,
  "moisture": 65.3,
  "ec": 2.1,
  "ph": 7.2,
  "n": 145.0,
  "p": 98.0,
  "k": 210.0
}
```

**Checks:**
- [ ] All numeric fields are correct type (not strings)
- [ ] Temperature appears as both "temp" and "temperature"
- [ ] All NPK values present
- [ ] Timestamp is Unix seconds format
- [ ] DeviceType is "soil_sensor"
- [ ] NodeId is "handheld"

## Test 7: Concurrent Operations

**Not Applicable** - BLE disconnects after data sent, so no concurrent upload/download

## Performance Checks

| Metric | Expected | Actual |
|--------|----------|--------|
| Upload time | < 2 seconds | |
| Connection time | < 5 seconds | |
| UI responsiveness | No freeze | |
| Memory usage | Stable | |

## Error Scenarios

| Scenario | Expected Behavior | Status |
|----------|-------------------|--------|
| Firebase unavailable | Error message, no crash | |
| Network timeout | Error message, retry option | |
| User not logged in | Error message | |
| Invalid JSON from Handheld | Parse error, warning shown | |
| Device disconnects mid-upload | Graceful error handling | |

## Logs to Check

**Mobile App (Flutter):**
```
[SensorData] Raw data: {...}
[SensorData] Parsed data: {...}
[SensorData] Uploading to Firebase...
[Firebase] Uploading handheld sensor data: {...}
[Firebase] ✅ Handheld sensor data uploaded successfully
```

**Firebase Console:**
- Check Realtime Database rules allow write to `sensor_data/{userUID}/handheld/`
- Verify no permission denied errors in error logs

## Rollback Plan

If upload fails after successful data reception:
1. Check Firebase auth is working (AuthService.currentUserUID)
2. Check Firebase database URL is correct
3. Check Firebase Realtime Database rules:
   ```
   {
     "rules": {
       "sensor_data": {
         "$uid": {
           ".write": "$uid === auth.uid",
           ".read": "$uid === auth.uid"
         }
       }
     }
   }
   ```
4. Verify user has write permissions
5. Check network connectivity from device

## Success Criteria

✅ All tests pass
✅ Data consistently uploaded to Firebase
✅ UI reflects current state accurately
✅ No crashes on error conditions
✅ Firebase data is properly structured
✅ User receives clear feedback on upload status
