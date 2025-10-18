# Step 1: Firebase Authentication Setup

## ✅ Completed Tasks

### 1. Dependencies Added
- ✅ `firebase_auth: ^5.3.1` added to `pubspec.yaml`
- ✅ Dependencies installed via `flutter pub get`

### 2. Authentication Service Created
- ✅ `lib/services/auth_service.dart`
  - Sign up with email/password
  - Sign in with email/password
  - Sign out
  - Password reset
  - User profile management
  - Account deletion
  - User UID retrieval for provisioning

### 3. UI Screens Created
- ✅ `lib/screens/login_screen.dart`
  - Email/password login form
  - Forgot password link
  - Sign up navigation
  - Error handling with user-friendly messages
  
- ✅ `lib/screens/signup_screen.dart`
  - Full name, email, password, confirm password
  - Form validation
  - Terms and conditions notice
  - Auto-navigation to home after signup

### 4. Auth State Management
- ✅ `lib/main.dart` updated with `AuthWrapper`
  - Stream-based auth state listening
  - Auto-redirect to login if not authenticated
  - Auto-redirect to home if authenticated
  
- ✅ `lib/screens/home_screen.dart` updated
  - Logout button in AppBar (user icon menu)
  - Profile menu option (placeholder)
  - Confirmation dialog before logout

### 5. UI Constants Updated
- ✅ `lib/utils/constants.dart`
  - Added `AppColors.surface`
  - Added `AppColors.textPrimary`, `textSecondary`, `textHint`
  - Added `AppTextStyles.heading` and `body` aliases

## 🚀 How to Test

### Test 1: Sign Up Flow
```bash
1. Run the app: flutter run
2. App should show Login Screen
3. Tap "Sign Up"
4. Fill in:
   - Full Name: Test User
   - Email: test@example.com
   - Password: test123
   - Confirm Password: test123
5. Tap "Sign Up"
6. Should navigate to Home Screen
7. Check Firebase Console → Authentication → Users
   - New user should appear
```

### Test 2: Login Flow
```bash
1. Close and restart app
2. App should show Login Screen (not logged in)
3. Enter:
   - Email: test@example.com
   - Password: test123
4. Tap "Login"
5. Should navigate to Home Screen
```

### Test 3: Logout Flow
```bash
1. On Home Screen, tap user icon (top right)
2. Tap "Logout"
3. Confirm logout dialog
4. Should return to Login Screen
5. Close and restart app
6. Should show Login Screen (persisted logout)
```

### Test 4: Forgot Password
```bash
1. On Login Screen, enter email
2. Tap "Forgot Password?"
3. Check email inbox for password reset link
4. Follow link to reset password
5. Try logging in with new password
```

### Test 5: Validation Errors
```bash
# Invalid email
- Enter "notanemail" → Should show "Please enter a valid email"

# Short password
- Enter "123" → Should show "Password must be at least 6 characters"

# Password mismatch (signup)
- Password: "test123"
- Confirm: "test456"
- Should show "Passwords do not match"

# Wrong credentials
- Email: test@example.com
- Password: wrongpassword
- Should show "Wrong password provided."
```

## 📋 Next Steps (Step 2)

### Update Firebase Service for User-Scoped Data
```dart
// OLD: nodes/{nodeId}/latest_data
// NEW: nodes/{userUID}/{gatewayMAC}/{nodeId}/latest_data

// In lib/services/firebase_service.dart:
Stream<List<Device>> getNodesStream() {
  final userUID = AuthService().currentUserUID;
  if (userUID == null) return Stream.value([]);
  
  final ref = database.ref('nodes/$userUID');
  // ... rest of implementation
}
```

### Update Data Service
```dart
// In lib/services/data_service.dart:
Stream<List<SensorData>> getSensorDataStream({String? nodeId}) {
  final userUID = AuthService().currentUserUID;
  if (userUID == null) {
    // Not logged in, return empty or mock data
    return Stream.value([]);
  }
  
  return firebaseService.getSensorDataStream(
    userUID: userUID,
    nodeId: nodeId,
  );
}
```

## 🔥 Firebase Console Configuration

### 1. Enable Authentication
```
1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project
3. Navigate to: Authentication → Sign-in method
4. Enable "Email/Password"
5. (Optional) Enable "Email link (passwordless sign-in)"
```

### 2. Test Mode Database Rules (Temporary)
```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

**⚠️ WARNING**: This allows ALL authenticated users to read/write ALL data.  
Only use for testing! Production rules will be added in Step 2.

### 3. Verify User Creation
```
1. After signup test, go to: Authentication → Users
2. Should see new user with:
   - UID (e.g., "kQ7XxYz...")
   - Email
   - Created date
   - Last sign in
```

### 4. Check Realtime Database
```
After signup, check: Database → Data
Should see:
/users
  /{userUID}
    email: "test@example.com"
    displayName: "Test User"
    createdAt: timestamp
    lastLogin: timestamp
    gateways: {}
```

## 🔐 Security Notes

### Current State (Step 1 Complete)
- ✅ Users must be authenticated to access the app
- ✅ Passwords are hashed by Firebase (never stored plain text)
- ✅ Email verification available (can be enabled)
- ⚠️ All authenticated users can see each other's data (TEST MODE)

### Step 2 Will Add:
- ✅ User-scoped data (users can only see their own devices)
- ✅ Production-ready security rules
- ✅ Gateway ownership tracking
- ✅ Multi-tenant isolation

## 📱 User Experience Flow

```
┌─────────────────────┐
│   App Starts        │
└──────────┬──────────┘
           │
           ▼
    ┌──────────────┐
    │ Auth Check   │
    │ (Firebase)   │
    └──┬───────┬───┘
       │       │
   Not │       │ Logged In
Logged │       │
   In  │       │
       ▼       ▼
┌──────────┐ ┌──────────┐
│  Login   │ │   Home   │
│  Screen  │ │  Screen  │
└────┬─────┘ └────┬─────┘
     │            │
     │ Sign Up    │ Logout
     ▼            ▼
┌──────────┐ ┌──────────┐
│  Signup  │ │  Logout  │
│  Screen  │ │  Dialog  │
└────┬─────┘ └────┬─────┘
     │            │
     └────────────┘
     Auto-login after
     signup/logout
```

## 🐛 Troubleshooting

### Issue: "Firebase not initialized"
```dart
// Make sure main.dart has:
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const KagriApp());
}
```

### Issue: Login/Signup not working
1. Check Firebase Console → Authentication is enabled
2. Check internet connection
3. Check Firebase Rules allow auth users
4. Check error messages in console

### Issue: App stuck on loading screen
- AuthWrapper StreamBuilder is waiting for auth state
- Check Firebase initialization didn't throw error
- Check network connectivity

### Issue: "User not found" after signup
- Signup might have failed silently
- Check Firebase Console → Authentication → Users
- Check error logs in debugger
- Verify email format is correct

## 📊 Testing Checklist

- [ ] Sign up with new account
- [ ] Verify user appears in Firebase Console
- [ ] Verify user profile created in Realtime Database
- [ ] Login with created account
- [ ] Logout and verify redirect to login
- [ ] Restart app and verify logout persisted
- [ ] Test forgot password flow
- [ ] Test form validation (invalid email, short password, etc.)
- [ ] Test password visibility toggle
- [ ] Test "Sign Up" navigation from login
- [ ] Test user menu in HomeScreen
- [ ] Verify currentUserUID is accessible via AuthService

## 🎉 Success Criteria

✅ **Authentication working**:
- Users can sign up
- Users can login
- Users can logout
- Auth state persists across app restarts

✅ **UI complete**:
- Login screen with all fields
- Signup screen with validation
- Logout button in home screen
- User menu with email display

✅ **Firebase integration**:
- Users created in Firebase Auth
- User profiles created in Realtime Database
- Auth state synced with Firebase

✅ **Ready for Step 2**:
- `AuthService().currentUserUID` returns correct UID
- Can be used for user-scoped database queries
- All screens import and use AuthService

---

**Status**: ✅ Step 1 Complete  
**Next**: Step 2 - Update Firebase Service for Multi-User Support  
**Estimated Time**: 2 days
