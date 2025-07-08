// lib/services/auth_service.dart - COMPLETE FIXED VERSION
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:canteen_app/services/session_manager.dart';
import 'package:canteen_app/services/firebase_auth_wrapper.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SessionManager _sessionManager = SessionManager();

  // Flag to prevent session check during login process
  bool _isLoggingIn = false;

  // Register User - FIXED with wrapper
  Future<User?> register(String email, String password, String role) async {
    try {
      _isLoggingIn = true;
      print('🔄 Starting registration process...');
      
      // Use the wrapper with retry logic
      final result = await FirebaseAuthWrapper.createUserWithRetry(
        email: email,
        password: password,
        maxRetries: 3,
      );
      
      final user = result?.user;

      if (user != null) {
        print('✅ Firebase Auth registration successful');
        
        // Save role in Firestore FIRST
        await _db.collection('users').doc(user.uid).set({
          'email': email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ User document created');

        // Then register session
        await _sessionManager.registerSession(user);
        print('✅ Session registered');
        
        // Update FCM token
        await _updateFCMTokenSafely(user.uid, isRegistration: true);
        print('✅ FCM token updated');
      }

      _isLoggingIn = false;
      return user;
    } catch (e) {
      _isLoggingIn = false;
      print('❌ Registration error: $e');
      
      // Provide better error messages
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            throw Exception('An account already exists with this email.');
          case 'invalid-email':
            throw Exception('Please enter a valid email address.');
          case 'operation-not-allowed':
            throw Exception('Email/password accounts are not enabled.');
          case 'weak-password':
            throw Exception('Password should be at least 6 characters.');
          default:
            throw Exception(e.message ?? 'Registration failed. Please try again.');
        }
      }
      
      rethrow;
    }
  }

  // Login User - FIXED with wrapper
  Future<User?> login(String email, String password) async {
    try {
      _isLoggingIn = true;
      print('🔑 Starting login process for: $email');
      
      // Use the wrapper with retry logic
      final result = await FirebaseAuthWrapper.signInWithRetry(
        email: email,
        password: password,
        maxRetries: 3,
      );
      
      final user = result?.user;
      
      if (user != null) {
        print('✅ Firebase Auth successful for: ${user.email}');
        
        // Register session IMMEDIATELY after successful auth
        await _sessionManager.registerSession(user);
        print('✅ Session registered successfully');
        
        // Update FCM token
        await _updateFCMTokenSafely(user.uid, isLogin: true);
        print('✅ FCM token updated');
        
        print('✅ Login completed successfully');
      }
      
      _isLoggingIn = false;
      return user;
    } catch (e) {
      _isLoggingIn = false;
      print('❌ Login error: $e');
      
      // Provide better error messages
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            throw Exception('No account found with this email address.');
          case 'wrong-password':
          case 'invalid-credential':
            throw Exception('Incorrect password. Please try again.');
          case 'invalid-email':
            throw Exception('Please enter a valid email address.');
          case 'user-disabled':
            throw Exception('This account has been disabled.');
          case 'too-many-requests':
            throw Exception('Too many failed attempts. Please try again later.');
          case 'network-request-failed':
            throw Exception('Network error. Please check your internet connection.');
          default:
            throw Exception(e.message ?? 'Login failed. Please try again.');
        }
      }
      
      rethrow;
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
      
      // Clear session first to update history
      await _sessionManager.clearSession();
      print('✅ Session cleared');
      
      // Remove FCM token before signing out
      User? user = _auth.currentUser;
      if (user != null) {
        await _clearFCMTokenSafely(user.uid);
      }
      
      // Sign out from Firebase Auth using wrapper
      await FirebaseAuthWrapper.signOut();
      print('✅ User logged out successfully');
    } catch (e) {
      print('❌ Error during logout: $e');
      // Still attempt to sign out even if other operations fail
      try {
        await FirebaseAuthWrapper.signOut();
        print('✅ Force sign out successful');
      } catch (signOutError) {
        print('❌ Error signing out: $signOutError');
        rethrow;
      }
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

  // Check if this device is still the active session - FIXED
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
  User? get currentUser => FirebaseAuthWrapper.currentUser;

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
  bool get isLoggedIn => FirebaseAuthWrapper.currentUser != null;

  // Get current user's email
  String? get currentUserEmail => FirebaseAuthWrapper.currentUser?.email;

  // Get current user's UID
  String? get currentUserUid => FirebaseAuthWrapper.currentUser?.uid;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => FirebaseAuthWrapper.authStateChanges();

  // Update user profile
  Future<void> updateUserProfile({String? displayName, String? photoURL}) async {
    try {
      final user = FirebaseAuthWrapper.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.updatePhotoURL(photoURL);
        
        await _db.collection('users').doc(user.uid).update({
          'displayName': displayName,
          'photoURL': photoURL,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating user profile: $e');
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = e.message ?? 'Failed to send password reset email';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to send password reset email: ${e.toString()}');
    }
  }

  // Verify email
  Future<void> sendEmailVerification() async {
    try {
      final user = FirebaseAuthWrapper.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      print('Error sending email verification: $e');
      throw Exception('Failed to send email verification: ${e.toString()}');
    }
  }

  // Reload user data
  Future<void> reloadUser() async {
    try {
      await FirebaseAuthWrapper.currentUser?.reload();
    } catch (e) {
      print('Error reloading user: $e');
    }
  }

  // Delete user account
  Future<void> deleteAccount() async {
    try {
      final user = FirebaseAuthWrapper.currentUser;
      if (user != null) {
        await _sessionManager.clearSession();
        await _db.collection('users').doc(user.uid).delete();
        await user.delete();
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
}