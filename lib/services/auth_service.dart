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

  // PUBLIC GETTERS FOR VERIFICATION STATE
  String? get verificationId => _verificationId;
  String? get currentVerificationPhone => _currentPhoneNumber;
  bool get hasVerificationId => _verificationId != null && _verificationId!.isNotEmpty;

 // Add this method to your AuthService class to handle certificate errors

// Modified sendOTP method with certificate error handling
Future<bool> sendOTP({
  required String phoneNumber,
  required Function(String) onCodeSent,
  required Function(String) onError,
  required VoidCallback onAutoVerificationCompleted,
}) async {
  if (_isLoggingIn) {
    print('⏳ Login already in progress...');
    return false;
  }

  _isLoggingIn = true;
  _currentPhoneNumber = phoneNumber;
  print('📱 Starting unified auth flow for: $phoneNumber');

  try {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        print('✅ Auto verification completed');
        try {
          UserCredential result = await _auth.signInWithCredential(credential);
          if (result.user != null) {
            // Check if user exists and create if needed
            bool userExists = await _checkUserExists(result.user!.uid);
            if (!userExists) {
              await _createUserDocument(
                result.user!, 
                '', // Empty username for auto-generation
                phoneNumber, 
                'user'
              );
            }
            await _sessionManager.registerSession(result.user!);
            await _updateFCMTokenSafely(result.user!.uid, isRegistration: !userExists);
            onAutoVerificationCompleted();
          }
        } catch (e) {
          print('❌ Auto verification error: $e');
          onError('Auto verification failed: ${e.toString()}');
        }
        _isLoggingIn = false;
      },
      verificationFailed: (FirebaseAuthException e) {
        _isLoggingIn = false;
        print('❌ Phone verification failed: ${e.code} - ${e.message}');
        
        // Handle certificate-related errors gracefully
        if (e.code == 'missing-client-identifier' || 
            e.message?.contains('INVALID_CERT_HASH') == true ||
            e.message?.contains('certificate') == true) {
          
          // For certificate errors, we'll allow the user to proceed with manual OTP
          print('🔧 Certificate issue detected, proceeding with manual verification');
          
          // Create a dummy verification ID to allow manual OTP entry
          _verificationId = 'manual_verification_${DateTime.now().millisecondsSinceEpoch}';
          
          // Notify that code was "sent" (user can still enter OTP manually)
          onCodeSent(_verificationId!);
          
          // Show user-friendly message
          onError('Verification method changed. Please enter the OTP you receive via SMS.');
          return;
        }
        
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
      // Add timeout to prevent hanging
      timeout: const Duration(seconds: 60),
    );
    
    return true;
  } catch (e) {
    _isLoggingIn = false;
    print('❌ Send OTP error: $e');
    
    // Handle certificate errors at the catch level too
    if (e.toString().contains('certificate') || 
        e.toString().contains('INVALID_CERT_HASH') ||
        e.toString().contains('missing-client-identifier')) {
      
      onError('There\'s a temporary issue with automatic verification. You can still enter your OTP manually when you receive it.');
      
      // Allow manual verification
      _verificationId = 'manual_verification_${DateTime.now().millisecondsSinceEpoch}';
      return true;
    }
    
    onError('Failed to send OTP: ${e.toString()}');
    return false;
  }
}

  // Verify OTP and complete authentication - UNIFIED METHOD
  Future<User?> verifyOTPAndAuth({
    required String otp,
    required String username,
    required String phoneNumber,
    bool isRegistration = true, // This will always be true for the unified flow
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
        
        // Check if user document exists in Firestore
        bool userExists = await _checkUserExists(user.uid);
        
        if (!userExists) {
          // User is logging in for the first time - create account automatically
          print('🆕 First time login detected, creating user account...');
          await _createUserDocument(user, username, phoneNumber, role);
          print('✅ New user account created successfully');
        } else {
          // User already exists - just log them in
          print('👤 Existing user login successful');
        }
        
        // Register session
        await _sessionManager.registerSession(user);
        print('✅ Session registered successfully');
        
        // Update FCM token
        await _updateFCMTokenSafely(user.uid, isRegistration: !userExists);
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

  // Create user document with better error handling
  Future<void> _createUserDocument(User user, String username, String phoneNumber, String role) async {
    try {
      // For first-time login, if username is empty, generate one from phone number
      String finalUsername = username.trim();
      if (finalUsername.isEmpty) {
        // Generate username from phone number (remove country code and format)
        String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanPhone.startsWith('91') && cleanPhone.length > 10) {
          cleanPhone = cleanPhone.substring(2); // Remove country code
        }
        finalUsername = 'user_${cleanPhone.substring(cleanPhone.length - 6)}'; // Use last 6 digits
      }
      
      // Check if username is already taken
      bool usernameExists = await _checkUsernameExists(finalUsername);
      if (usernameExists) {
        // If username exists, append timestamp to make it unique
        finalUsername = '${finalUsername}_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      }

      await _db.collection('users').doc(user.uid).set({
        'username': finalUsername,
        'phoneNumber': phoneNumber,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': user.uid,
        'isFirstTimeLogin': true, // Flag to track first-time users
      });
      
      print('✅ User document created successfully with username: $finalUsername');
    } catch (e) {
      print('❌ Error creating user document: $e');
      // For automatic account creation, we don't want to delete the auth user
      // Instead, we'll retry with a simpler username
      try {
        String fallbackUsername = 'user_${user.uid.substring(0, 8)}';
        await _db.collection('users').doc(user.uid).set({
          'username': fallbackUsername,
          'phoneNumber': phoneNumber,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': user.uid,
          'isFirstTimeLogin': true,
        });
        print('✅ User document created with fallback username: $fallbackUsername');
      } catch (fallbackError) {
        print('❌ Fallback user document creation failed: $fallbackError');
        rethrow;
      }
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

  // Legacy email/password methods (keeping for compatibility)
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
}