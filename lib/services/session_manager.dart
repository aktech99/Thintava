// lib/services/session_manager.dart - IMPROVED VERSION
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class SessionManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Collection name for session management
  static const String _sessionCollection = 'user_sessions';
  
  // Get current device identifier with better error handling
  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        try {
          AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
          // Use androidId if available, fallback to model + id combination
          String deviceId = androidInfo.id.isNotEmpty 
              ? androidInfo.id 
              : '${androidInfo.model}_${androidInfo.serialNumber}';
          return deviceId.isNotEmpty ? deviceId : _generateFallbackId();
        } catch (androidError) {
          print('Error getting Android device info: $androidError');
          return _generateFallbackId();
        }
      } else if (Platform.isIOS) {
        try {
          IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
          String deviceId = iosInfo.identifierForVendor ?? '';
          return deviceId.isNotEmpty ? deviceId : _generateFallbackId();
        } catch (iosError) {
          print('Error getting iOS device info: $iosError');
          return _generateFallbackId();
        }
      }
      return _generateFallbackId();
    } catch (e) {
      print('Error getting device info: $e');
      return _generateFallbackId();
    }
  }

  // Generate a fallback device ID when device info fails
  String _generateFallbackId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'unknown';
    return '${platform}_fallback_$timestamp';
  }
  
  // Register a new session for the current device with retry logic
  Future<void> registerSession(User user) async {
    try {
      print("🔄 Starting session registration for user: ${user.uid}");
      
      final String deviceId = await _getDeviceId();
      print("📱 Device ID: $deviceId");
      
      String? fcmToken;
      
      // Try to get FCM token with retry logic
      int fcmRetries = 0;
      const maxFcmRetries = 3;
      
      while (fcmToken == null && fcmRetries < maxFcmRetries) {
        try {
          fcmToken = await FirebaseMessaging.instance.getToken()
              .timeout(const Duration(seconds: 5));
          if (fcmToken != null) {
            print("✅ FCM token obtained: ${fcmToken.substring(0, 20)}...");
            break;
          }
        } catch (fcmError) {
          fcmRetries++;
          print("⚠️ FCM token attempt $fcmRetries failed: $fcmError");
          if (fcmRetries < maxFcmRetries) {
            await Future.delayed(Duration(milliseconds: 500 * fcmRetries));
          }
        }
      }
      
      if (fcmToken == null) {
        print("⚠️ Could not get FCM token after $maxFcmRetries attempts, continuing without it");
      }
      
      // Terminate other sessions first
      await _terminateOtherSessions(user.uid, deviceId);
      
      // Register the current session with retry logic
      int sessionRetries = 0;
      const maxSessionRetries = 3;
      bool sessionRegistered = false;
      
      while (!sessionRegistered && sessionRetries < maxSessionRetries) {
        try {
          await _db.collection(_sessionCollection).doc(user.uid).set({
            'activeDeviceId': deviceId,
            'activeDeviceFcmToken': fcmToken,
            'lastLoginTime': FieldValue.serverTimestamp(),
            'email': user.email,
            'userId': user.uid,
            'platform': Platform.operatingSystem,
            'registeredAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 10));
          
          sessionRegistered = true;
          print('✅ Session registered successfully for device: $deviceId');
          
        } catch (sessionError) {
          sessionRetries++;
          print('❌ Session registration attempt $sessionRetries failed: $sessionError');
          
          if (sessionRetries < maxSessionRetries) {
            await Future.delayed(Duration(seconds: sessionRetries));
          } else {
            print('❌ Failed to register session after $maxSessionRetries attempts');
            // Don't throw - session registration failure shouldn't break login
          }
        }
      }
      
    } catch (e) {
      print('❌ Error in registerSession: $e');
      // Don't throw error - session management shouldn't break login
    }
  }
  
  // Terminate other sessions for this user with better error handling
  Future<void> _terminateOtherSessions(String userId, String currentDeviceId) async {
    try {
      print("🔍 Checking for existing sessions for user: $userId");
      
      // Get the user's current session document with timeout
      DocumentSnapshot sessionDoc = await _db.collection(_sessionCollection)
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (sessionDoc.exists && sessionDoc.data() != null) {
        final data = sessionDoc.data() as Map<String, dynamic>;
        final String? existingDeviceId = data['activeDeviceId'];
        
        print("📱 Current device: $currentDeviceId");
        print("📱 Existing device: $existingDeviceId");
        
        if (existingDeviceId != null && existingDeviceId != currentDeviceId) {
          final String? existingFcmToken = data['activeDeviceFcmToken'];
          
          print("🔄 Terminating session for device: $existingDeviceId");
          
          // Store the terminated session in history
          try {
            await _db.collection(_sessionCollection)
                .doc(userId)
                .collection('history')
                .add({
                  'deviceId': existingDeviceId,
                  'fcmToken': existingFcmToken,
                  'loginTime': data['lastLoginTime'],
                  'logoutTime': FieldValue.serverTimestamp(),
                  'logoutReason': 'Logged in on another device',
                  'platform': data['platform'] ?? 'unknown',
                }).timeout(const Duration(seconds: 10));
            
            print("✅ Session history recorded for terminated device");
            
          } catch (historyError) {
            print('⚠️ Error storing session history: $historyError');
            // Continue even if history storage fails
          }
          
          print('✅ Previous session terminated for device: $existingDeviceId');
        } else {
          print('ℹ️ Same device login or no existing device ID');
        }
      } else {
        print('ℹ️ No existing session found for user');
      }
    } catch (e) {
      print('⚠️ Error terminating other sessions: $e');
      // Don't throw - this shouldn't prevent new session registration
    }
  }
  
  // Check if this device is still the active session with better error handling
  Future<bool> isActiveSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No current user for session check');
        return false;
      }
      
      final String deviceId = await _getDeviceId();
      print('🔍 Checking session for device: $deviceId');
      
      DocumentSnapshot sessionDoc = await _db.collection(_sessionCollection)
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (!sessionDoc.exists || sessionDoc.data() == null) {
        print('❌ No session document exists');
        return false;
      }
      
      final data = sessionDoc.data() as Map<String, dynamic>;
      final String? activeDeviceId = data['activeDeviceId'];
      
      final isActive = activeDeviceId == deviceId;
      print('🔍 Session check: activeDeviceId=$activeDeviceId, currentDeviceId=$deviceId, isActive=$isActive');
      
      return isActive;
    } catch (e) {
      print('❌ Error checking session status: $e');
      return true; // Default to true to avoid blocking user
    }
  }
  
  // Clear the current session on logout with better error handling
  Future<void> clearSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No current user for session clearing');
        return;
      }
      
      final String deviceId = await _getDeviceId();
      print("🧹 Clearing session for device: $deviceId");
      
      // Get current session with timeout
      DocumentSnapshot sessionDoc = await _db.collection(_sessionCollection)
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (sessionDoc.exists && sessionDoc.data() != null) {
        final data = sessionDoc.data() as Map<String, dynamic>;
        final String? activeDeviceId = data['activeDeviceId'];
        
        // Only clear if this is the active device
        if (activeDeviceId == deviceId) {
          // Add to history before clearing
          try {
            await _db.collection(_sessionCollection)
                .doc(user.uid)
                .collection('history')
                .add({
                  'deviceId': deviceId,
                  'fcmToken': data['activeDeviceFcmToken'],
                  'loginTime': data['lastLoginTime'],
                  'logoutTime': FieldValue.serverTimestamp(),
                  'logoutReason': 'Manual logout',
                  'platform': data['platform'] ?? 'unknown',
                }).timeout(const Duration(seconds: 10));
            
            print("✅ Logout history recorded");
            
          } catch (historyError) {
            print('⚠️ Error storing logout history: $historyError');
            // Continue with session clearing even if history storage fails
          }
          
          // Clear the active session
          await _db.collection(_sessionCollection)
              .doc(user.uid)
              .delete()
              .timeout(const Duration(seconds: 10));
          
          print('✅ Session cleared for device: $deviceId');
        } else {
          print('⚠️ Device mismatch during session clearing: $activeDeviceId vs $deviceId');
        }
      } else {
        print('⚠️ No session document found to clear');
      }
    } catch (e) {
      print('❌ Error clearing session: $e');
      // Don't throw - session clearing failure shouldn't prevent logout
    }
  }
  
  // Set up a listener for session changes with better error handling
  StreamSubscription<DocumentSnapshot>? _sessionListener;
  
  void startSessionListener(VoidCallback onForcedLogout) {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No current user for session listener');
        return;
      }
      
      print('👂 Starting session listener for user: ${user.uid}');
      
      _sessionListener = _db.collection(_sessionCollection)
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) async {
        try {
          if (!snapshot.exists || snapshot.data() == null) {
            // Session document was deleted
            print('❌ Session document no longer exists - forced logout');
            onForcedLogout();
            return;
          }
          
          final data = snapshot.data() as Map<String, dynamic>;
          final activeDeviceId = data['activeDeviceId'];
          
          // Get current device ID for comparison
          final deviceId = await _getDeviceId();
          
          print('📱 Session listener: activeDeviceId=$activeDeviceId, currentDeviceId=$deviceId');
          
          if (activeDeviceId != deviceId) {
            // Another device is now active
            print('❌ Another device is now the active session - forced logout');
            onForcedLogout();
          }
        } catch (e) {
          print('❌ Error in session listener callback: $e');
        }
      }, onError: (error) {
        print('❌ Error in session listener: $error');
        // Don't call onForcedLogout for listener errors
      });
      
      print('✅ Session listener started successfully');
    } catch (e) {
      print('❌ Error starting session listener: $e');
    }
  }
  
  void stopSessionListener() {
    try {
      _sessionListener?.cancel();
      _sessionListener = null;
      print('🛑 Session listener stopped');
    } catch (e) {
      print('❌ Error stopping session listener: $e');
    }
  }
}