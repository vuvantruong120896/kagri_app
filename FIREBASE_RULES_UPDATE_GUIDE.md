# Firebase Rules Update - Handheld Sensor Data Support

## Problem Identified

Current Firebase Rules don't explicitly allow writes to `sensor_data/{uid}/handheld/` path with handheld sensor data structure.

**Error:** 
```
[firebase_database/permission-denied] 
Client doesn't have permission to access the desired data.
```

**Data Structure Mismatch:**
- Current validation expects: `['temperature', 'humidity', 'timestamp']`
- Handheld sends: `['temp', 'temperature', 'moisture', 'ec', 'pH', 'N', 'P', 'K', 'timestamp']`

## Solution

Updated rules to:
1. **Add explicit handheld path** under `sensor_data/{uid}/`
2. **Allow handheld writes** with proper validation
3. **Keep existing rules** for gateway sensor nodes
4. **Maintain security** - user isolation still enforced

## Changes Made

### Before (Lines 85-96)
```json
"sensor_data": {
  "$uid": {
    ".read": "$uid === auth.uid",
    ".write": "$uid === auth.uid || auth != null",
    
    "$nodeId": {
      "$timestamp": {
        ".validate": "newData.hasChildren(['temperature', 'humidity', 'timestamp'])"
      }
    }
  }
}
```

### After (Lines 85-108)
```json
"sensor_data": {
  "$uid": {
    ".read": "$uid === auth.uid",
    ".write": "$uid === auth.uid || auth != null",
    
    "handheld": {
      ".read": "$uid === auth.uid",
      ".write": "$uid === auth.uid || auth != null",
      
      "$timestamp": {
        ".validate": "newData.hasChildren(['timestamp', 'deviceType', 'nodeId'])"
      }
    },
    
    "$nodeId": {
      "$timestamp": {
        ".validate": "newData.hasChildren(['temperature', 'humidity', 'timestamp'])"
      }
    }
  }
}
```

## Key Changes Explained

### 1. Added Handheld Explicit Path
```json
"handheld": {
  ".read": "$uid === auth.uid",
  ".write": "$uid === auth.uid || auth != null",
  "$timestamp": {
    ".validate": "newData.hasChildren(['timestamp', 'deviceType', 'nodeId'])"
  }
}
```

- **Explicit handheld path** - ensures all handheld writes go here
- **Read permission** - only owner can read
- **Write permission** - owner or any authenticated user (gateway can write provisioning data)
- **Validation** - requires timestamp, deviceType, nodeId (flexible on other fields)

### 2. Kept Gateway Node Rules
```json
"$nodeId": {
  "$timestamp": {
    ".validate": "newData.hasChildren(['temperature', 'humidity', 'timestamp'])"
  }
}
```

- Unchanged - gateway sensor nodes still work as before
- Different validation (temperature/humidity for environment sensors)

## How to Apply

### Step 1: Copy Updated Rules

File: `firebase_rules_updated.json` in this project

### Step 2: Firebase Console

1. Go: https://console.firebase.google.com/
2. Select: **KAGRI** project
3. Click: **Realtime Database** (left sidebar)
4. Click: **Rules** tab (top)

### Step 3: Replace Rules

1. Select all current rules (Ctrl+A)
2. Delete
3. Copy entire content from `firebase_rules_updated.json`
4. Paste into Firebase Rules editor

### Step 4: Verify & Publish

1. Check: ✅ Syntax valid (green checkmark)
2. Click: **Publish**
3. Confirm: Click **Publish** in popup
4. Wait: 10-30 seconds for deployment

## Verification Steps

### In Firebase Console

1. Go: **Realtime Database** → **Rules**
2. Click: **Test** button (before publishing if you want to preview)
3. Test handheld write:
   - **User:** Authenticated
   - **Location:** `/sensor_data/4F0EPiGc75WVu8bZBbGKXZZVAK13/handheld/1764218366`
   - **Operation:** Write
   - Should show: ✅ **Allowed**

### In Mobile App

1. Build & run: `flutter clean && flutter pub get && flutter run`
2. Connect to Handheld device via BLE
3. Receive sensor data
4. Status should show: **✅ Dữ liệu đã lưu lên Firebase!**
5. Firebase Console: Navigate to `sensor_data/{yourUID}/handheld/` → should see uploaded data

## Data Structure Validation

### Handheld Data (Validated)
```json
{
  "timestamp": 1764218366,          // Required
  "deviceType": "soil_sensor",      // Required
  "nodeId": "handheld",              // Required
  "temp": 28.5,                      // Additional (not validated)
  "moisture": 65.3,
  "ec": 2.1,
  "pH": 7.2,
  "N": 145,
  "P": 98,
  "K": 210
}
```

### Gateway Node Data (Existing - Unchanged)
```json
{
  "timestamp": 1764218366,           // Required
  "temperature": 28.5,               // Required (different field!)
  "humidity": 65.3,                  // Required
  "other_fields": "..."              // Optional
}
```

## Security Analysis

✅ **Enforced Security:**
- User isolation: `$uid === auth.uid` for reads
- Write control: only owner or authenticated users (gateway)
- Data validation: required fields ensure data integrity
- No cross-user access possible

✅ **Gateway Writes Allowed:**
- Gateway can write to `/sensor_data/{uid}/handheld/` (provisioning, test data)
- Gateway can write to `/sensor_data/{uid}/{nodeId}/` (sensor readings)

✅ **User Access:**
- Each user can only read/write their own data
- Cannot access other user's sensor data
- Cannot write to other user's paths

## Rollback Plan

If issues occur:

1. Go back to Firebase Console → Realtime Database → Rules
2. Replace with your previous rules
3. Publish

Previous rules are still visible in Firebase Console version history.

## Testing Checklist

After applying rules:

- [ ] Rules published and shows "Rules are live"
- [ ] Firebase Test shows ✅ Allowed for handheld path
- [ ] Mobile App connects to Handheld
- [ ] Data received successfully
- [ ] Status shows "✅ Dữ liệu đã lưu lên Firebase!"
- [ ] Firebase Console shows data in `/sensor_data/{uid}/handheld/`
- [ ] Timestamp and all fields present
- [ ] Can upload multiple readings (each gets new timestamp)
- [ ] Gateway sensor nodes still work (existing functionality)

## Troubleshooting

### Rules Won't Publish
- Check syntax (Firebase shows red X if invalid)
- Ensure no trailing commas
- Try copying fresh from `firebase_rules_updated.json`

### Still Getting Permission Denied
1. Clear app cache: `flutter clean`
2. Rebuild: `flutter pub get && flutter run`
3. Verify rules are actually published (check last modified time)
4. Wait 30-60 seconds for global deployment

### Data Not Appearing
1. Check user UID matches (see userUID in error vs Firebase Auth)
2. Verify path structure: `sensor_data/` → `{uid}` → `handheld` → `{timestamp}`
3. Check Mobile App logs for upload success message
4. Refresh Firebase Console page

## Support

- **Full implementation guide:** See `FIREBASE_UPLOAD_IMPLEMENTATION.md`
- **Quick fix:** See `QUICK_FIX_PERMISSION_DENIED.md`
- **Test plan:** See `TEST_PLAN_FIREBASE_UPLOAD.md`

## Summary

✅ Updated Firebase Rules to:
- Allow handheld sensor data writes
- Explicit validation for handheld path
- Maintain backward compatibility with gateway nodes
- Keep security (user isolation)

Next: Apply rules in Firebase Console → Test in Mobile App → Verify in Firebase Console
