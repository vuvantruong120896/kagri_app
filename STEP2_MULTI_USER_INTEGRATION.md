# Step 2: Multi-User Firebase Integration

## ✅ Completed Changes

### 1. Updated FirebaseService with User-Scoped Paths

#### New Database Structure (Multi-Tenant)
```
users/
  {userUID}/
    profile: {email, displayName, createdAt, gateways: {}}
    
nodes/
  {userUID}/
    {gatewayMAC}/
      {nodeId}/
        info: {name, type, firmware_version, created_at, last_seen}
        latest_data: {temperature, humidity, timestamp, ...}

sensor_data/
  {userUID}/
    {nodeId}/
      {timestamp}: {temperature, humidity, ...}

gateways/
  {userUID}/
    {gatewayMAC}/
      status: {wifi_rssi, uptime, free_heap, ...}
      routing_table: {nodes: [...], updated_at}
```

#### Updated Methods in `lib/services/firebase_service.dart`

| Method | Old Path | New Path |
|--------|----------|----------|
| `getNodesStream()` | `nodes/{nodeId}` | `nodes/{userUID}/{gatewayMAC}/{nodeId}` |
| `getLatestDataStream()` | `nodes/{nodeId}/latest_data` | `nodes/{userUID}/{gatewayMAC}/{nodeId}/latest_data` |
| `getSensorDataStream()` | `sensor_data/{nodeId}` | `sensor_data/{userUID}/{nodeId}` |
| `getGatewayStatusStream()` | `gateways/{gatewayId}/status` | `gateways/{userUID}/{gatewayMAC}/status` |
| `getRoutingTableStream()` | `gateways/{gatewayId}/routing_table` | `gateways/{userUID}/{gatewayMAC}/routing_table` |
| `updateNodeInfo()` | `nodes/{nodeId}/info` | `nodes/{userUID}/{gatewayMAC}/{nodeId}/info` |
| `addSensorData()` | `nodes/{nodeId}/latest_data` | `nodes/{userUID}/{gatewayMAC}/{nodeId}/latest_data` |

**Key Features:**
- ✅ Automatic user UID retrieval from `AuthService().currentUserUID`
- ✅ Returns empty data if user not logged in (null check)
- ✅ Gateway MAC tracking for multi-gateway support
- ✅ Nested iteration through gateways → nodes

### 2. Updated Device Model

**File**: `lib/models/device.dart`

**New Field:**
```dart
final String? gatewayMAC; // Gateway MAC address this node belongs to
```

**Changes:**
- ✅ Added `gatewayMAC` field to Device class
- ✅ Updated `fromJson()` to parse `gatewayMAC` or `gateway_mac`
- ✅ Updated `toJson()` to include `gateway_mac` if not null
- ✅ Updated `copyWith()` to handle `gatewayMAC` parameter

### 3. Updated DataService

**File**: `lib/services/data_service.dart`

**Changes:**
```dart
// OLD
Future<void> updateNodeInfo(String nodeId, Map<String, dynamic> updates)

// NEW
Future<void> updateNodeInfo(
  String nodeId, 
  Map<String, dynamic> updates, {
  String? gatewayMAC,
})
```

Same for `addSensorData()` - now requires optional `gatewayMAC` parameter.

### 4. Updated HomeScreen

**File**: `lib/screens/home_screen.dart`

**Change in Rename Device:**
```dart
// OLD
await _dataService.updateNodeInfo(device.nodeId, {'name': newName});

// NEW
await _dataService.updateNodeInfo(
  device.nodeId, 
  {'name': newName},
  gatewayMAC: device.gatewayMAC,
);
```

---

## 🔥 Firebase Security Rules (IMPORTANT!)

### Current Status: TEST MODE (Insecure)
```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```
⚠️ **WARNING**: All authenticated users can see each other's data!

### Production Rules (Apply Now!)

Go to **Firebase Console** → **Realtime Database** → **Rules** and replace with:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "auth != null && auth.uid == $uid"
      }
    },
    "nodes": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "auth != null && auth.uid == $uid"
      }
    },
    "sensor_data": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "auth != null && auth.uid == $uid"
      }
    },
    "gateways": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "auth != null && auth.uid == $uid"
      }
    }
  }
}
```

**What this does:**
- ✅ Each user can only read/write their own data
- ✅ `users/{userUID}` - only readable/writable by that user
- ✅ `nodes/{userUID}` - isolated per user
- ✅ `sensor_data/{userUID}` - isolated per user
- ✅ `gateways/{userUID}` - isolated per user

**How to apply:**
1. Go to Firebase Console
2. Realtime Database → Rules tab
3. Copy-paste the rules above
4. Click **Publish**

---

## 🧪 Testing Multi-User Isolation

### Test 1: Create Second User Account
```
1. Logout from app (user icon → Logout)
2. On Login Screen, tap "Sign Up"
3. Create new account:
   - Name: Test User 2
   - Email: test2@kagri.com
   - Password: test123456
4. Login successfully
5. Home Screen should show NO devices (empty list)
```

### Test 2: Verify Data Isolation
```
1. User 1 (test@kagri.com) has devices/sensors
2. User 2 (test2@kagri.com) sees empty list
3. Switch between accounts:
   - Logout from User 2
   - Login as User 1
   - Devices reappear
4. Check Firebase Console → Database:
   nodes/
     {user1UID}/... - User 1 devices
     {user2UID}/... - User 2 devices (empty or different)
```

### Test 3: Test Security Rules
```
1. Login as User 1
2. In Firebase Console → Realtime Database → Rules
3. Click "Rules Simulator"
4. Test Read:
   - Path: /nodes/{user2UID}/
   - Auth UID: {user1UID}
   - Expected: DENIED ❌
5. Test Read:
   - Path: /nodes/{user1UID}/
   - Auth UID: {user1UID}
   - Expected: ALLOWED ✅
```

### Test 4: Rename Device (User-Scoped)
```
1. Login as User 1 with existing devices
2. Long press on a device
3. Tap "Đổi tên thiết bị"
4. Enter new name
5. Verify update successful
6. Check Firebase Console:
   - Path: nodes/{user1UID}/{gatewayMAC}/{nodeId}/info
   - Field 'name' should be updated
7. Login as User 2
8. Verify they DON'T see this device
```

---

## 🚨 Known Issues & Limitations

### Issue 1: Gateway MAC Unknown for Existing Data
**Problem**: Old Firebase data doesn't have `gatewayMAC` in device info.

**Impact**: 
- `device.gatewayMAC` will be `null` for old data
- Rename device will fail with "gatewayMAC not provided" error

**Temporary Fix**: 
Add gatewayMAC manually in Firebase Console for existing devices:
```
nodes/{userUID}/{gatewayMAC}/{nodeId}/info/gateway_mac: "AA:BB:CC:DD:EE:FF"
```

**Permanent Fix (Next Step)**: 
Gateway firmware will include `gateway_mac` in all node info uploads after BLE provisioning.

### Issue 2: Data Migration Required
**Problem**: Existing Firebase data is in old flat structure:
```
OLD: nodes/{nodeId}/info
NEW: nodes/{userUID}/{gatewayMAC}/{nodeId}/info
```

**Solution Options:**
1. **Start Fresh** (Recommended for dev):
   - Delete all data in Firebase Console
   - Let Gateway upload new data in new structure
   
2. **Manual Migration**:
   - Export old data (Firebase Console → Database → Export JSON)
   - Restructure locally with script
   - Import to new paths
   
3. **Let Gateway Re-register**:
   - Gateway will re-upload node info on next boot
   - Will use new paths automatically after firmware update

---

## 📊 Data Flow Diagram

### Before (Flat Structure)
```
App Request
  ↓
FirebaseService.getNodesStream()
  ↓
Query: nodes/
  ↓
Returns: ALL nodes from ALL users ❌
```

### After (User-Scoped)
```
App Request
  ↓
AuthService.currentUserUID → "abc123"
  ↓
FirebaseService.getNodesStream()
  ↓
Query: nodes/abc123/
  ↓
Returns: ONLY current user's nodes ✅
```

---

## 🎯 Next Steps

### Immediate (Do Now)
- [ ] **Apply Firebase Security Rules** (see above)
- [ ] **Test multi-user isolation** (create 2nd account)
- [ ] **Verify rename device works** (with gatewayMAC)

### Step 3: Gateway Firmware Update (Next Week)
- [ ] Update Firebase upload paths to include userUID
- [ ] Implement BLE provisioning to receive userUID from mobile app
- [ ] Store userUID in NVS (non-volatile storage)
- [ ] Generate dynamic netkey from `hash(userUID + gatewayMAC)`

### Step 4: BLE Provisioning Mobile UI (1-2 days)
- [ ] Scan for unpaired gateways (advertising "KAGRI_GW_*")
- [ ] Connect and send WiFi credentials + userUID
- [ ] Gateway saves to NVS and restarts with WiFi
- [ ] Add gateway to user's profile in Firebase

---

## ✅ Success Criteria

### Multi-User Works If:
- ✅ User 1 and User 2 see different device lists
- ✅ Rename device works (updates correct user's node)
- ✅ Firebase Rules deny cross-user access
- ✅ New users start with empty device list
- ✅ Logout → Login shows correct user's data

### Ready for Step 3 If:
- ✅ All Step 2 tests pass
- ✅ Security rules published
- ✅ Understanding of `nodes/{userUID}/{gatewayMAC}/` structure
- ✅ Mobile app retrieves `currentUserUID` correctly

---

**Status**: ✅ Step 2 Complete (Code Changes)  
**Pending**: 🔥 Apply Firebase Security Rules  
**Next**: Step 3 - Gateway Firmware Multi-User Support  
**Estimated Time**: 3-4 days
