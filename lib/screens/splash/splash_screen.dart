// lib/screens/splash/splash_screen.dart - Updated for SMS Auth
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:canteen_app/constants/food_quotes.dart';
import 'package:canteen_app/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  
  @override
  _SplashScreenState createState() => _SplashScreenState();
}
 
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final StreamSubscription<User?> _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final AuthService _authService = AuthService();
  bool _hasNavigated = false;
  bool _isProcessingAuth = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupFirebaseMessaging();
    _startAuthListener();
    print('🎬 Splash screen initialized with SMS auth');
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
    print('🎭 Animations set up');
  }

  void _setupFirebaseMessaging() {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          FlutterLocalNotificationsPlugin().show(
            notification.hashCode,
            notification.title,
            notification.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'thintava_channel',
                'Thintava Notifications',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      });
      print('📱 Firebase messaging set up');
    } catch (e) {
      print('⚠️ Error setting up Firebase messaging: $e');
    }
  }

  void _startAuthListener() {
    print("👂 Starting auth state listener for SMS auth...");
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted || _hasNavigated || _isProcessingAuth) return;

      _isProcessingAuth = true;
      print("📱 Auth state changed, user: ${user?.uid ?? 'null'}");

      try {
        if (user == null) {
          print("🔴 No user found, navigating to auth...");
          await _delayedNavigation(2000);
          _navigateToAuth();
          return;
        }

        print("🟢 User found: ${user.uid}");
        print("📱 User phone: ${user.phoneNumber ?? 'No phone'}");
        
        // Wait longer for session registration to complete
        print("⏳ Waiting for session to stabilize...");
        await Future.delayed(const Duration(seconds: 3));
        
        if (!mounted || _hasNavigated) return;
        
        // Check session status with retry logic
        bool isActiveSession = false;
        int sessionCheckRetries = 0;
        const maxSessionRetries = 3;
        
        while (!isActiveSession && sessionCheckRetries < maxSessionRetries) {
          try {
            isActiveSession = await _authService.checkActiveSession()
                .timeout(const Duration(seconds: 10));
            
            if (!isActiveSession) {
              sessionCheckRetries++;
              print("❌ Session check failed, retry $sessionCheckRetries/$maxSessionRetries");
              
              if (sessionCheckRetries < maxSessionRetries) {
                await Future.delayed(Duration(seconds: sessionCheckRetries));
              }
            } else {
              print("✅ Session is active");
            }
          } catch (sessionError) {
            sessionCheckRetries++;
            print("❌ Session check error (attempt $sessionCheckRetries): $sessionError");
            
            if (sessionCheckRetries >= maxSessionRetries) {
              print("⚠️ Session check failed after $maxSessionRetries attempts, continuing anyway");
              isActiveSession = true; // Allow login to proceed
            } else {
              await Future.delayed(Duration(seconds: sessionCheckRetries));
            }
          }
        }
        
        if (!isActiveSession) {
          print("❌ Device session is not active, logging out");
          await _authService.logout();
          
          if (!mounted || _hasNavigated) return;
          _showSessionExpiredMessage();
          _navigateToAuth();
          return;
        }

        // Handle FCM token
        await _setupFCMToken(user.uid);

        // Fetch user role with retry logic
        String role = await _fetchUserRoleWithRetry(user.uid);

        if (!mounted || _hasNavigated) return;
        
        // Add delay for better UX
        await _delayedNavigation(1000);

        print("🎯 User role: $role");

        // Navigate based on role
        switch (role) {
          case 'admin':
            print("🏠 Navigating to admin home");
            _navigateToRoute('/admin/home');
            break;
          case 'kitchen':
            print("👨‍🍳 Navigating to kitchen home");
            _navigateToRoute('/kitchen-menu');
            break;
          default:
            print("👤 Navigating to user home");
            _navigateToRoute('/user/user-home');
        }

      } catch (e) {
        print("❌ Error in auth listener: $e");
        if (mounted && !_hasNavigated) {
          _navigateToAuth();
        }
      } finally {
        _isProcessingAuth = false;
      }
    }, onError: (error) {
      print("❌ Auth state change error: $error");
      _isProcessingAuth = false;
      if (mounted && !_hasNavigated) {
        _navigateToAuth();
      }
    });
  }

  Future<void> _delayedNavigation(int milliseconds) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  void _showSessionExpiredMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your account was logged in on another device',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Safe navigation methods
  void _navigateToAuth() {
    if (!_hasNavigated && mounted) {
      _hasNavigated = true;
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  void _navigateToRoute(String route) {
    if (!_hasNavigated && mounted) {
      _hasNavigated = true;
      Navigator.pushReplacementNamed(context, route);
    }
  }

  Future<void> _setupFCMToken(String userId) async {
    try {
      print("🚀 Setting up FCM token for user: $userId");
      String? token;
      int retries = 0;
      const maxRetries = 3;

      while (token == null && retries < maxRetries) {
        try {
          token = await FirebaseMessaging.instance.getToken()
              .timeout(const Duration(seconds: 5));
          
          if (token != null) {
            print("✅ FCM token obtained: ${token.substring(0, 20)}...");
            break;
          }
        } catch (e) {
          retries++;
          print("⚠️ FCM token attempt $retries failed: $e");
          if (retries < maxRetries) {
            await Future.delayed(Duration(seconds: retries));
          }
        }
      }

      if (token != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set(
            {
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          ).timeout(const Duration(seconds: 10));
          
          print("💾 FCM token saved to Firestore");
        } catch (e) {
          print("⚠️ Error saving FCM token: $e");
        }

        // Set up token refresh listener
        _tokenRefreshSubscription?.cancel();
        _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          print("🔄 FCM token refreshed");
          try {
            await FirebaseFirestore.instance.collection('users').doc(userId).set(
              {
                'fcmToken': newToken,
                'lastTokenUpdate': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          } catch (e) {
            print("⚠️ Error saving refreshed FCM token: $e");
          }
        });
      } else {
        print("⚠️ Could not get FCM token after $maxRetries attempts");
      }
    } catch (e) {
      print("❌ Error in FCM setup: $e");
    }
  }

  Future<String> _fetchUserRoleWithRetry(String userId) async {
    int retries = 0;
    const maxRetries = 3;
    
    while (retries < maxRetries) {
      try {
        print("🔍 Fetching user role (attempt ${retries + 1})...");
        
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get()
            .timeout(const Duration(seconds: 10));
        
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final role = data['role'] ?? 'user';
          print("📋 User role found: $role");
          return role;
        } else {
          print("📋 No user document found, user might not be properly registered");
          // For SMS auth, if no document found, user registration failed
          throw Exception('User profile not found. Please register again.');
        }
      } catch (e) {
        retries++;
        print("❌ Error fetching role (attempt $retries): $e");
        
        if (retries < maxRetries) {
          await Future.delayed(Duration(seconds: retries));
        } else {
          print("❌ Failed to fetch role after $maxRetries attempts");
          
          // For SMS auth, we should not default to 'user' if the document doesn't exist
          // This indicates a registration issue
          if (e.toString().contains('User profile not found')) {
            // Force logout and redirect to registration
            await _authService.logout();
            if (mounted && !_hasNavigated) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Profile not found. Please register again.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              _navigateToAuth();
            }
            throw e;
          }
          
          return 'user'; // Fallback for other errors
        }
      }
    }
    
    return 'user';
  }

  @override
  void dispose() {
    print("🗑️ Disposing splash screen");
    _authSubscription.cancel();
    _tokenRefreshSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB703), Color(0xFFFFB703)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    size: 60,
                    color: Color(0xFFFFB703),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Thintava',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    foodQuotes[DateTime.now().second % foodQuotes.length],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  _isProcessingAuth 
                    ? "Verifying your session..." 
                    : "Preparing your experience...",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}