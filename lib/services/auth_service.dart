import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Authentication service for user management
/// Handles login, signup, logout, and user state
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get current user UID (null if not logged in)
  String? get currentUserUID => _auth.currentUser?.uid;

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email and password
  /// Returns User if successful, throws exception if failed
  Future<User?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      // Create user account
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = credential.user;

      if (user != null) {
        // Update display name if provided
        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
          await user.reload();
        }

        // Create user profile in Realtime Database
        await _createUserProfile(user, displayName);

        print('✅ User created: ${user.uid}');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Sign up error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Sign up error: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  /// Returns User if successful, throws exception if failed
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;

      if (user != null) {
        print('✅ User logged in: ${user.uid}');

        // Update last login timestamp
        await _updateLastLogin(user.uid);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Sign in error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Sign in error: $e');
      rethrow;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('✅ User signed out');
    } catch (e) {
      print('❌ Sign out error: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      print('❌ Password reset error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Password reset error: $e');
      rethrow;
    }
  }

  /// Update user display name
  Future<void> updateDisplayName(String displayName) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.reload();

        // Update in database as well
        await _database.ref('users/${user.uid}/displayName').set(displayName);

        print('✅ Display name updated: $displayName');
      }
    } catch (e) {
      print('❌ Update display name error: $e');
      rethrow;
    }
  }

  /// Update user email
  Future<void> updateEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateEmail(newEmail);
        await user.reload();

        // Update in database as well
        await _database.ref('users/${user.uid}/email').set(newEmail);

        print('✅ Email updated: $newEmail');
      }
    } catch (e) {
      print('❌ Update email error: $e');
      rethrow;
    }
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user logged in');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
      print('✅ Password changed successfully');
    } on FirebaseAuthException catch (e) {
      print('❌ Change password error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Change password error: $e');
      rethrow;
    }
  }

  /// Delete current user account
  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user logged in');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete user data from database
      await _database.ref('users/${user.uid}').remove();
      await _database.ref('gateways/${user.uid}').remove();
      await _database.ref('nodes/${user.uid}').remove();
      await _database.ref('sensor_data/${user.uid}').remove();

      // Delete auth account
      await user.delete();

      print('✅ Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      print('❌ Delete account error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Delete account error: $e');
      rethrow;
    }
  }

  /// Create user profile in Realtime Database
  Future<void> _createUserProfile(User user, String? displayName) async {
    try {
      await _database.ref('users/${user.uid}').set({
        'email': user.email,
        'displayName': displayName ?? user.email?.split('@')[0] ?? 'User',
        'createdAt': ServerValue.timestamp,
        'lastLogin': ServerValue.timestamp,
        'gateways': {}, // Empty map for user's gateways
      });
    } catch (e) {
      print('⚠️ Failed to create user profile in database: $e');
      // Don't throw - user account is created, profile creation is secondary
    }
  }

  /// Update last login timestamp
  Future<void> _updateLastLogin(String uid) async {
    try {
      await _database.ref('users/$uid/lastLogin').set(ServerValue.timestamp);
    } catch (e) {
      print('⚠️ Failed to update last login: $e');
      // Don't throw - login is successful, timestamp update is secondary
    }
  }

  /// Handle Firebase Auth exceptions and return user-friendly messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Contact support.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please log in again.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }
}
