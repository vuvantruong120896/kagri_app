# Firebase Realtime Database Rules - Fix Permission Denied

## Problem

```
Permission denied when uploading handheld sensor data
Path: /sensor_data/{userUID}/handheld/{timestamp}
Error: Database error: Permission denied
```

The issue is that your Firebase Realtime Database Rules don't allow authenticated users to write to the `sensor_data/{uid}/handheld/` path.

## Solution

You need to update Firebase Realtime Database Rules to allow write access to handheld sensor data.

### Current Rules (Likely)

The current rules probably only allow writing to paths like `sensor_data/{uid}/{nodeId}` where nodeId is a gateway/mesh node, but not for handheld devices.

### Updated Rules

Replace your Firebase Realtime Database Rules with:

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

### Key Changes

1. **Allow handheld write:** Added explicit `"handheld"` rule under `sensor_data/{$uid}/`
2. **Maintain existing rules:** Kept rules for gateway nodes (`$nodeId`)
3. **User isolation:** All rules check `$uid === auth.uid` to ensure users can only access their own data

## How to Update Firebase Rules

### Step 1: Open Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (KAGRI)
3. Navigate to **Realtime Database**

### Step 2: Go to Rules Tab

1. Click on **Rules** tab (top of the database view)
2. You'll see the current rules in a text editor

### Step 3: Update the Rules

1. Copy the new rules from above
2. Paste them into the Firebase Rules editor
3. Check syntax (Firebase will show a ✅ if valid)

### Step 4: Publish

1. Click **Publish** button
2. Confirm the change in the popup
3. Wait for rules to be deployed (usually < 30 seconds)

### Step 5: Verify

1. Return to Mobile App
2. Try uploading handheld sensor data again
3. Should see: `✅ Dữ liệu đã lưu lên Firebase!`
4. Check Firebase Console to verify data appears at `/sensor_data/{yourUID}/handheld/{timestamp}`

## Visual Guide

```
Firebase Console
    ↓
Realtime Database
    ↓
Rules tab
    ↓
[Current Rules Text] ← Copy and paste updated rules here
    ↓
Publish button
    ↓
✅ Rules deployed
    ↓
Test in Mobile App
```

## Testing the Fix

### Before Publishing Rules

You can test rules in Firebase Console:

1. In Rules tab, click **Test** (before Publishing)
2. Select: **Authenticated User**
3. Location: `/sensor_data/4F0EPiGc75WVu8bZBbGKXZZVAK13/handheld/1764218366`
4. Operation: **write**
5. Should show: **✅ Allowed** (after applying the new rules)

### After Publishing Rules

1. Build and run Mobile App
2. Connect to Handheld device
3. Receive sensor data
4. Status should show: `✅ Dữ liệu đã lưu lên Firebase!`
5. Check Firebase Console data appears

## Troubleshooting

### Still getting "Permission denied"?

1. **Clear app cache:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Verify user is authenticated:**
   - Make sure user is logged in to Mobile App
   - Check `AuthService.currentUserUID` is not null

3. **Check Firebase Rules deployment:**
   - Go to Firebase Console → Realtime Database → Rules
   - Verify your new rules are showing (not old ones)
   - Check the "Last modified" timestamp

4. **Test rule manually:**
   - Firebase Console → Rules tab → Test
   - Path: `/sensor_data/{your_uid}/handheld/1764218366`
   - Should show ✅ Allowed

### User UID Mismatch?

The error shows: `4F0EPiGc75WVu8bZBbGKXZZVAK13`

Make sure this is your authenticated user UID in Firebase Auth:

1. Firebase Console → Authentication
2. Click on the user
3. Copy User UID
4. Should match the UID in the error message

### Path Structure Wrong?

Verify the path structure matches:
```
sensor_data/
└── {userUID}/
    └── handheld/
        └── {timestamp}/
            └── sensor_data_here
```

## Alternative: Simpler Rules (Less Secure)

If you want to allow all authenticated users to write anywhere in `sensor_data` (less secure):

```json
{
  "rules": {
    "sensor_data": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    }
  }
}
```

**Note:** This still ensures user isolation (users can only write to their own UID path).

## Security Best Practices

✅ Current rules enforce:
- User authentication required (`.auth !== null`)
- User isolation (`$uid === auth.uid`)
- Each user can only access their own data
- Cannot write to other user's data

## Next Steps

1. Update Firebase Rules as shown above
2. Publish the changes
3. Test in Mobile App
4. Verify data appears in Firebase Console
5. Try uploading multiple readings

## Support

If rules update doesn't fix the issue:
1. Check User UID in Firebase Auth matches the one in error
2. Check AuthService.currentUserUID is returning correct value
3. Check network connectivity
4. Clear cache and rebuild: `flutter clean && flutter pub get && flutter run`
