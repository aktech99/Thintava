import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/services/auth_service.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String username;
  final bool isLogin;

  const OTPVerificationScreen({
    Key? key,
    required this.phoneNumber,
    required this.username,
    this.isLogin = true, // Always true for unified flow
  }) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  final _authService = AuthService();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOTP() async {
    if (_otpController.text.trim().length != 6) {
      _showError('Please enter a valid 6-digit OTP');
      return;
    }

    if (!_authService.hasVerificationId) {
      _showError('Verification session expired. Please request a new OTP.');
      // Navigate back to phone input
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authService.verifyOTPAndAuth(
        otp: _otpController.text,
        username: widget.username,
        phoneNumber: widget.phoneNumber,
        isRegistration: true, // Always true for unified flow - service will handle existing users
        role: 'user', // Default role
      );

      if (user != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Authentication successful! Welcome to Thintava!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate to splash screen which will handle role routing
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/splash',
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ OTP Verification failed: $e');
      
      // Handle specific error cases
      String errorMessage = e.toString();
      if (errorMessage.contains('No verification ID found')) {
        errorMessage = 'Verification session expired. Please request a new OTP.';
        // Navigate back to phone input after showing error
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else if (errorMessage.contains('PigeonUserDetails') || 
                 errorMessage.contains('List<Object?>')) {
        // This specific error usually means auth was successful but there's a serialization issue
        errorMessage = 'Authentication may have succeeded. Please wait...';
        
        // Wait a moment and check if user is signed in
        Future.delayed(const Duration(seconds: 2), () async {
          if (mounted) {
            final user = _authService.currentUser;
            if (user != null) {
              // User is signed in, navigate to success
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Authentication successful! Welcome to Thintava!',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/splash',
                (route) => false,
              );
            } else {
              // Still not signed in, show error
              _showError('Authentication failed. Please try again.');
            }
          }
        });
      } else if (errorMessage.contains('invalid-verification-code')) {
        errorMessage = 'Invalid OTP. Please check and try again.';
      } else if (errorMessage.contains('session-expired')) {
        errorMessage = 'Session expired. Please request a new OTP.';
        // Navigate back after delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
      
      if (mounted) {
        _showError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resendOTP() async {
    try {
      bool success = await _authService.sendOTP(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (verificationId) {
          if (mounted) {
            _showSuccess('OTP sent successfully!');
          }
        },
        onError: (error) {
          if (mounted) {
            _showError(error);
          }
        },
        onAutoVerificationCompleted: () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/splash');
          }
        },
      );

      if (!success) {
        _showError('Failed to resend OTP. Please try again.');
      }
    } catch (e) {
      _showError('Error resending OTP: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFB703),
                  Color(0xFFF59E0B),
                  Color(0xFFD97706),
                ],
              ),
            ),
          ),
          // Glassmorphism decorations
          Positioned(
            top: -50,
            left: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Back button
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header
                              const Icon(
                                Icons.sms_outlined,
                                size: 64,
                                color: Color(0xFFFFB703),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "Enter OTP",
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "We've sent a verification code to",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.phoneNumber,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFFB703),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),

                              // OTP input field
                              TextFormField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 6,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 8,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Enter 6-digit OTP",
                                  labelStyle: GoogleFonts.poppins(color: Colors.black54),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFFFB703), width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, 
                                    vertical: 20,
                                  ),
                                  counterText: "", // Hide counter
                                ),
                                onChanged: (value) {
                                  if (value.length == 6) {
                                    // Auto-verify when 6 digits are entered
                                    _verifyOTP();
                                  }
                                },
                              ),

                              const SizedBox(height: 24),

                              // Verify button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyOTP,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFB703),
                                    foregroundColor: Colors.black87,
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.verified_user),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Verify OTP",
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Resend OTP
                              TextButton(
                                onPressed: _resendOTP,
                                child: Text(
                                  "Didn't receive OTP? Resend",
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFFB703),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Auto-account creation info
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Your account will be created automatically if this is your first time!",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}