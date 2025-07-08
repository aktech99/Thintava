// lib/services/firebase_auth_wrapper.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

/// A wrapper class to handle Firebase Auth issues with retries and fallbacks
class FirebaseAuthWrapper {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Sign in with email and password with retry logic
  static Future<UserCredential?> signInWithRetry({
    required String email,
    required String password,
    int maxRetries = 3,
  }) async {
    int retryCount = 0;
    Exception? lastError;
    
    while (retryCount < maxRetries) {
      try {
        print('🔐 Authentication attempt ${retryCount + 1} of $maxRetries');
        
        // Clear any cached auth state
        if (retryCount > 0) {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
        
        // Attempt sign in
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Verify we got a valid user
        if (credential.user != null) {
          print('✅ Authentication successful on attempt ${retryCount + 1}');
          return credential;
        }
        
        throw Exception('No user returned from authentication');
        
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('⚠️ Auth attempt ${retryCount + 1} failed: $e');
        
        // Check if it's the PigeonUserDetails error
        if (e.toString().contains('PigeonUserDetails') || 
            e.toString().contains('List<Object?>')) {
          print('🔄 Detected PigeonUserDetails error, will retry with workaround');
          
          // Try workaround: use auth state listener
          try {
            final user = await _signInWithAuthStateWorkaround(email, password);
            if (user != null) {
              // Create a mock UserCredential since we can't get the real one
              return _MockUserCredential(user);
            }
          } catch (workaroundError) {
            print('⚠️ Workaround also failed: $workaroundError');
          }
        }
        
        // Check for specific Firebase Auth errors that shouldn't be retried
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'user-not-found':
            case 'wrong-password':
            case 'invalid-email':
            case 'user-disabled':
            case 'invalid-credential':
              // Don't retry these errors
              throw e;
          }
        }
        
        retryCount++;
        
        if (retryCount >= maxRetries) {
          break;
        }
      }
    }
    
    // All retries failed
    print('❌ All authentication attempts failed');
    throw lastError ?? Exception('Authentication failed after $maxRetries attempts');
  }
  
  /// Workaround for PigeonUserDetails error using auth state listener
  static Future<User?> _signInWithAuthStateWorkaround(
    String email, 
    String password,
  ) async {
    print('🔧 Using auth state workaround');
    
    final completer = Completer<User?>();
    StreamSubscription? authStateSubscription;
    Timer? timeoutTimer;
    
    try {
      // Set up auth state listener before attempting sign in
      authStateSubscription = _auth.authStateChanges().listen((user) {
        if (user != null && user.email == email) {
          print('✅ Auth state workaround successful');
          if (!completer.isCompleted) {
            completer.complete(user);
          }
        }
      });
      
      // Set up timeout
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('Auth state workaround timed out'),
          );
        }
      });
      
      // Attempt sign in (may throw PigeonUserDetails error but auth might succeed)
      try {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        print('⚠️ Sign in threw error but checking auth state: $e');
        // Don't throw here, wait for auth state
      }
      
      // Also check current user immediately
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email == email) {
        print('✅ Current user already matches');
        if (!completer.isCompleted) {
          completer.complete(currentUser);
        }
      }
      
      // Wait for auth state change or timeout
      return await completer.future;
      
    } finally {
      // Clean up
      authStateSubscription?.cancel();
      timeoutTimer?.cancel();
    }
  }
  
  /// Create user with retry logic
  static Future<UserCredential?> createUserWithRetry({
    required String email,
    required String password,
    int maxRetries = 3,
  }) async {
    int retryCount = 0;
    Exception? lastError;
    
    while (retryCount < maxRetries) {
      try {
        print('📝 Registration attempt ${retryCount + 1} of $maxRetries');
        
        if (retryCount > 0) {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
        
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (credential.user != null) {
          print('✅ Registration successful on attempt ${retryCount + 1}');
          return credential;
        }
        
        throw Exception('No user returned from registration');
        
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('⚠️ Registration attempt ${retryCount + 1} failed: $e');
        
        // Check for specific errors that shouldn't be retried
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'email-already-in-use':
            case 'invalid-email':
            case 'operation-not-allowed':
            case 'weak-password':
              // Don't retry these errors
              throw e;
          }
        }
        
        retryCount++;
        
        if (retryCount >= maxRetries) {
          break;
        }
      }
    }
    
    throw lastError ?? Exception('Registration failed after $maxRetries attempts');
  }
  
  /// Sign out with cleanup
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('✅ Sign out successful');
    } catch (e) {
      print('❌ Error during sign out: $e');
      // Force sign out by clearing current user
      try {
        await _auth.signOut();
      } catch (_) {}
      throw e;
    }
  }
  
  /// Get current user safely
  static User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      print('⚠️ Error getting current user: $e');
      return null;
    }
  }
  
  /// Stream of auth state changes with error handling
  static Stream<User?> authStateChanges() {
    return _auth.authStateChanges().handleError((error) {
      print('⚠️ Auth state stream error: $error');
    });
  }
}

/// Mock UserCredential for workaround cases
class _MockUserCredential implements UserCredential {
  final User _user;
  
  _MockUserCredential(this._user);
  
  @override
  User? get user => _user;
  
  @override
  AdditionalUserInfo? get additionalUserInfo => null;
  
  @override
  AuthCredential? get credential => null;
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}