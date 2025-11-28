# QUICK FIX: Firebase Permission Denied Error

## Error Message
```
[firebase_database/permission-denied] 
Client doesn't have permission to access the desired data.
Path: /sensor_data/{userUID}/handheld/{timestamp}
```

## 5-Minute Fix

### 1. Open Firebase Console
- Go to: https://console.firebase.google.com/
- Select your **KAGRI** project

### 2. Navigate to Realtime Database Rules
- Click: **Realtime Database** (in left sidebar)
- Click: **Rules** tab (top of database)

### 3. Copy New Rules
```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "nodes": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "sensor_data": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid",
        "handheld": {
          ".read": "$uid === auth.uid",
          ".write": "$uid === auth.uid"
        },
        "$nodeId": {
          ".read": "$uid === auth.uid",
          ".write": "$uid === auth.uid"
        }
      }
    },
    "gateways": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    }
  }
}
```

### 4. Paste and Publish
1. **Delete** all current rules text
2. **Paste** the new rules above
3. Check: Rules should show ✅ (no red errors)
4. Click: **Publish** button
5. Confirm in popup

### 5. Test Again
```bash
flutter clean
flutter pub get
flutter run
```

1. Connect to Handheld device
2. Receive sensor data
3. Should see: ✅ **Dữ liệu đã lưu lên Firebase!**

## What Changed?

**Added this block** to allow handheld writes:
```json
"sensor_data": {
  "$uid": {
    ".read": "$uid === auth.uid",
    ".write": "$uid === auth.uid",  ← You can write to your data
    "handheld": {
      ".read": "$uid === auth.uid",
      ".write": "$uid === auth.uid"  ← NEW: Explicitly allow handheld writes
    },
    "$nodeId": {
      ".read": "$uid === auth.uid",
      ".write": "$uid === auth.uid"
    }
  }
}
```

## Verify It Works

**In Firebase Console:**
1. Go to: **Realtime Database**
2. Navigate to: `sensor_data` → `{yourUID}` → `handheld`
3. Should see entries like: `1764218366` (timestamp)
4. Each entry contains sensor data

**Example data structure:**
```
sensor_data/
└── 4F0EPiGc75WVu8bZBbGKXZZVAK13/
    └── handheld/
        └── 1764218366/
            ├── timestamp: 1764218366
            ├── deviceType: "soil_sensor"
            ├── nodeId: "handheld"
            ├── temp: 28.5
            ├── moisture: 65.3
            └── ... (more sensor fields)
```

## If Still Not Working

1. **Check user is logged in:**
   - Mobile App should show user email/name
   - Not showing? → Login first

2. **Clear app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Check Firebase Auth:**
   - Console → Authentication
   - Find your user
   - Copy the **User UID**
   - Should match: `4F0EPiGc75WVu8bZBbGKXZZVAK13`

4. **Test rules manually:**
   - Firebase Console → Realtime Database → Rules
   - Click **Test** button
   - User: **Authenticated**
   - Location: `/sensor_data/4F0EPiGc75WVu8bZBbGKXZZVAK13/handheld/12345`
   - Should show: ✅ **Allowed**

## Still Stuck?

See full guide: `FIREBASE_RULES_FIX.md`

---

**Summary:** Permission denied = Firebase Rules need update to allow handheld writes. Copy the rules above and publish in Firebase Console. Done! ✅
