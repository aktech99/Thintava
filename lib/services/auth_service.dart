// lib/services/auth_service.dart - FIXED SINGLETON VERSION
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:canteen_app/services/session_manager.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SessionManager _sessionManager = SessionManager();

  // Flag to prevent session check during login process
  bool _isLoggingIn = false;
  
  // Store verification ID and resend token as static to persist across instances
  static String? _verificationId;
  static int? _resendToken;
  static String? _currentPhoneNumber;

  // Send OTP to phone number
  Future<bool> sendOTP({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
    required Function() onAutoVerificationCompleted,
  }) async {
    try {
      _isLoggingIn = true;
      _currentPhoneNumber = phoneNumber;
      print('📱 Sending OTP to: $phoneNumber');

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('✅ Auto verification completed');
          try {
            await _signInWithCredential(credential);
            onAutoVerificationCompleted();
          } catch (e) {
            print('❌ Auto verification error: $e');
            onError('Auto verification failed: ${e.toString()}');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _isLoggingIn = false;
          print('❌ Verification failed: ${e.message}');
          String errorMessage = _parsePhoneAuthError(e);
          onError(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          print('📨 OTP sent successfully. Verification ID: ${verificationId.substring(0, 10)}...');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          print('⏰ Auto retrieval timeout. Verification ID: ${verificationId.substring(0, 10)}...');
        },
        forceResendingToken: _resendToken,
      );
      
      return true;
    } catch (e) {
      _isLoggingIn = false;
      print('❌ Send OTP error: $e');
      onError('Failed to send OTP: ${e.toString()}');
      return false;
    }
  }

  // Verify OTP and complete registration/login
  Future<User?> verifyOTPAndAuth({
    required String otp,
    required String username,
    required String phoneNumber,
    bool isRegistration = true,
    String role = 'user',
  }) async {
    try {
      if (_verificationId == null || _verificationId!.isEmpty) {
        throw Exception('No verification ID found. Please resend OTP.');
      }

      print('🔐 Verifying OTP: $otp with verification ID: ${_verificationId!.substring(0, 10)}...');

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      User? user;
      
      try {
        UserCredential result = await _auth.signInWithCredential(credential);
        user = result.user;
      } catch (e) {
        // Handle PigeonUserDetails error
        if (e.toString().contains('PigeonUserDetails') || 
            e.toString().contains('List<Object?>')) {
          print('🔄 PigeonUserDetails error detected, using workaround...');
          
          // Wait a moment for the auth state to update
          await Future.delayed(const Duration(milliseconds: 1000));
          
          // Check if user is now signed in
          user = _auth.currentUser;
          if (user == null) {
            // Try waiting a bit more
            await Future.delayed(const Duration(milliseconds: 2000));
            user = _auth.currentUser;
          }
          
          if (user == null) {
            throw Exception('Authentication failed. Please try again.');
          }
          
          print('✅ Workaround successful, user authenticated: ${user.uid}');
        } else {
          // Re-throw other errors
          rethrow;
        }
      }

      if (user != null) {
        print('✅ Phone Auth successful for: ${user.phoneNumber}');
        
        if (isRegistration) {
          // For registration, create user document
          await _createUserDocument(user, username, phoneNumber, role);
        } else {
          // For login, verify user exists
          bool userExists = await _checkUserExists(user.uid);
          if (!userExists) {
            throw Exception('User not found. Please register first.');
          }
        }
        
        // Register session
        await _sessionManager.registerSession(user);
        print('✅ Session registered successfully');
        
        // Update FCM token
        await _updateFCMTokenSafely(user.uid, isRegistration: isRegistration);
        print('✅ FCM token updated');
        
        // Clear verification data after successful auth
        _clearVerificationData();
        
        print('✅ Authentication completed successfully');
      }
      
      _isLoggingIn = false;
      return user;
    } catch (e) {
      _isLoggingIn = false;
      print('❌ OTP verification error: $e');
      
      if (e is FirebaseAuthException) {
        throw Exception(_parsePhoneAuthError(e));
      }
      
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(User user, String username, String phoneNumber, String role) async {
    try {
      // Check if username is already taken
      bool usernameExists = await _checkUsernameExists(username);
      if (usernameExists) {
        throw Exception('Username already taken. Please choose another.');
      }

      await _db.collection('users').doc(user.uid).set({
        'username': username,
        'phoneNumber': phoneNumber,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': user.uid,
      });
      
      print('✅ User document created successfully');
    } catch (e) {
      print('❌ Error creating user document: $e');
      // Delete the auth user if document creation fails
      await user.delete();
      rethrow;
    }
  }

  // Check if username already exists
  Future<bool> _checkUsernameExists(String username) async {
    try {
      final result = await _db.collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      return result.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking username: $e');
      return false;
    }
  }

  // Check if user document exists
  Future<bool> _checkUserExists(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('❌ Error checking user existence: $e');
      return false;
    }
  }

  // Sign in with credential (for auto-verification)
  Future<User?> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      User? user;
      
      try {
        UserCredential result = await _auth.signInWithCredential(credential);
        user = result.user;
      } catch (e) {
        // Handle PigeonUserDetails error for auto-verification too
        if (e.toString().contains('PigeonUserDetails') || 
            e.toString().contains('List<Object?>')) {
          print('🔄 PigeonUserDetails error in auto-verification, using workaround...');
          
          // Wait for auth state to update
          await Future.delayed(const Duration(milliseconds: 1000));
          user = _auth.currentUser;
          
          if (user == null) {
            await Future.delayed(const Duration(milliseconds: 2000));
            user = _auth.currentUser;
          }
          
          if (user == null) {
            throw Exception('Auto-verification failed. Please enter OTP manually.');
          }
          
          print('✅ Auto-verification workaround successful: ${user.uid}');
        } else {
          rethrow;
        }
      }

      if (user != null) {
        // For auto-verification, we need to check if user exists
        bool userExists = await _checkUserExists(user.uid);
        if (!userExists) {
          throw Exception('User not found. Please complete registration.');
        }
        
        await _sessionManager.registerSession(user);
        await _updateFCMTokenSafely(user.uid, isLogin: true);
        
        // Clear verification data after successful auth
        _clearVerificationData();
      }
      
      return user;
    } catch (e) {
      print('❌ Credential sign in error: $e');
      rethrow;
    }
  }

  // Parse phone auth errors
  String _parsePhoneAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number';
      case 'too-many-requests':
        return 'Too many requests. Please try again later';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and try again';
      case 'session-expired':
        return 'OTP has expired. Please request a new one';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  // Resend OTP
  Future<bool> resendOTP({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    // Clear existing verification data before resending
    _clearVerificationData();
    
    return await sendOTP(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
      onAutoVerificationCompleted: () {},
    );
  }

  // Get user data including username
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Safe FCM Token update method
  Future<void> _updateFCMTokenSafely(String uid, {bool isRegistration = false, bool isLogin = false}) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      
      String? token = await FirebaseMessaging.instance.getToken();
      print('📱 FCM Token retrieved: ${token != null ? 'Success' : 'Failed'}');
      
      if (token != null && token.isNotEmpty) {
        Map<String, dynamic> updateData = {
          'fcmToken': token,
        };
        
        if (isRegistration) {
          updateData['registrationTime'] = FieldValue.serverTimestamp();
        }
        if (isLogin) {
          updateData['lastLoginTime'] = FieldValue.serverTimestamp();
        }
        
        await _db.collection('users').doc(uid).update(updateData);
        print('✅ FCM token updated successfully');
      } else {
        print('⚠️ FCM token is null or empty, skipping update');
      }
    } catch (e) {
      print('❌ Error updating FCM token: $e');
      // Don't rethrow - FCM token update failure shouldn't break login/registration
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      print('🔄 Starting logout process...');
      
      // Clear verification data
      _clearVerificationData();
      
      // Clear session first to update history
      await _sessionManager.clearSession();
      print('✅ Session cleared');
      
      // Remove FCM token before signing out
      User? user = _auth.currentUser;
      if (user != null) {
        await _clearFCMTokenSafely(user.uid);
      }
      
      // Sign out from Firebase Auth
      await _auth.signOut();
      print('✅ User logged out successfully');
    } catch (e) {
      print('❌ Error during logout: $e');
      // Still attempt to sign out even if other operations fail
      try {
        await _auth.signOut();
        print('✅ Force sign out successful');
      } catch (signOutError) {
        print('❌ Error signing out: $signOutError');
        rethrow;
      }
    }
  }

  Future<UserCredential> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      print('Error during login: $e');
      rethrow;
    }
  }

  Future<UserCredential> register(String email, String password, String username) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      if (credential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
          'username': username,
          'email': email,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } catch (e) {
      print('Error during registration: $e');
      rethrow;
    }
  }

  // Safe FCM Token clearing method
  Future<void> _clearFCMTokenSafely(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': null,
        'lastLogoutTime': FieldValue.serverTimestamp(),
      });
      
      await FirebaseMessaging.instance.deleteToken();
      print('✅ FCM token cleared successfully');
    } catch (e) {
      print('❌ Error clearing FCM token: $e');
    }
  }

  // Check if this device is still the active session
  Future<bool> checkActiveSession() async {
    try {
      // SKIP session check during login process
      if (_isLoggingIn) {
        print('⏳ Skipping session check - login in progress');
        return true;
      }

      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No current user for session check');
        return false;
      }

      return await _sessionManager.isActiveSession();
    } catch (e) {
      print('Error checking active session: $e');
      return true; // Default to true to avoid blocking user during errors
    }
  }
  
  // Start listening for session changes
  void startSessionListener(VoidCallback onForcedLogout) {
    _sessionManager.startSessionListener(onForcedLogout);
  }
  
  // Stop listening for session changes
  void stopSessionListener() {
    _sessionManager.stopSessionListener();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get user role from Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return data['role'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  // Get current user's role
  Future<String> getCurrentUserRole() async {
    final user = currentUser;
    if (user != null) {
      final role = await getUserRole(user.uid);
      return role ?? 'user';
    }
    return 'user';
  }

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Get current user's phone number
  String? get currentUserPhone => _auth.currentUser?.phoneNumber;

  // Get current user's UID
  String? get currentUserUid => _auth.currentUser?.uid;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Update user profile
  Future<void> updateUserProfile({String? username, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        Map<String, dynamic> updateData = {
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        if (username != null) {
          // Check if username is available
          bool usernameExists = await _checkUsernameExists(username);
          if (usernameExists) {
            throw Exception('Username already taken');
          }
          updateData['username'] = username;
        }
        
        if (photoURL != null) {
          updateData['photoURL'] = photoURL;
        }
        
        await _db.collection('users').doc(user.uid).update(updateData);
      }
    } catch (e) {
      print('Error updating user profile: $e');
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Delete user account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _sessionManager.clearSession();
        await _db.collection('users').doc(user.uid).delete();
        await user.delete();
        _clearVerificationData();
        print('✅ User account deleted successfully');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'requires-recent-login':
          errorMessage = 'Please log in again before deleting your account.';
          break;
        default:
          errorMessage = e.message ?? 'Failed to delete account';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }

  // Clear verification data (call when leaving auth screens or after successful auth)
  void _clearVerificationData() {
    _verificationId = null;
    _resendToken = null;
    _currentPhoneNumber = null;
    print('🧹 Verification data cleared');
  }

  // Public method to clear verification data
  void clearVerificationData() {
    _clearVerificationData();
  }

  // Get current verification status (for debugging)
  bool get hasVerificationId => _verificationId != null && _verificationId!.isNotEmpty;
  
  // Get current phone number being verified (for debugging)
  String? get currentVerificationPhone => _currentPhoneNumber;
}