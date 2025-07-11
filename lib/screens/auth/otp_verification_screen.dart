import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:canteen_app/services/auth_service.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String username;
  final bool isLogin;

  const OTPVerificationScreen({
    Key? key,
    required this.phoneNumber,
    required this.username,
    this.isLogin = false,
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
  bool _isResending = false;
  
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startResendTimer();
    
    // Debug: Check if we have verification ID
    print('🔍 OTP Screen initialized. Has verification ID: ${_authService.hasVerificationId}');
    if (!_authService.hasVerificationId) {
      print('⚠️ No verification ID found on OTP screen init!');
    }
  }

  void _setupAnimations() {
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

  void _startResendTimer() {
    _canResend = false;
    _resendCountdown = 60;
    
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    // Don't clear verification data on dispose - only clear on successful auth or explicit back navigation
    super.dispose();
  }

  void _verifyOTP() async {
    if (_otpController.text.length != 6) {
      _showError('Please enter complete OTP');
      return;
    }

    // Check if we have verification ID before proceeding
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
        isRegistration: !widget.isLogin,
        role: 'user', // Default role
      );

      if (user != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isLogin ? 'Login successful!' : 'Registration successful!',
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
                    widget.isLogin ? 'Login successful!' : 'Registration successful!',
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
        
        // Don't show error immediately for this case
        return;
      }
      
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resendOTP() async {
    if (!_canResend || _isResending) return;

    setState(() => _isResending = true);

    try {
      bool success = await _authService.resendOTP(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (verificationId) {
          if (mounted) {
            _showSuccess('OTP sent successfully!');
            _startResendTimer();
          }
        },
        onError: (error) {
          if (mounted) {
            _showError(error);
          }
        },
      );

      if (!success) {
        _showError('Failed to resend OTP. Please try again.');
      }
    } catch (e) {
      _showError('Error resending OTP: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.redAccent,
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
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: GoogleFonts.poppins(
        fontSize: 20,
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color(0xFFFFB703), width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: const Color(0xFFFFB703).withOpacity(0.1),
        border: Border.all(color: const Color(0xFFFFB703)),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Verify OTP",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _authService.clearVerificationData();
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFB703), Color(0xFFFFC107)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sms,
                      size: 60,
                      color: Color(0xFFFFB703),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Glass card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Verify Your Phone",
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Enter the 6-digit code sent to",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.phoneNumber,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFFB703),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // OTP Input
                            Pinput(
                              controller: _otpController,
                              length: 6,
                              defaultPinTheme: defaultPinTheme,
                              focusedPinTheme: focusedPinTheme,
                              submittedPinTheme: submittedPinTheme,
                              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                              showCursor: true,
                              onCompleted: (pin) => _verifyOTP(),
                            ),

                            const SizedBox(height: 32),

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
                                  : Text(
                                      "Verify OTP",
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Resend OTP section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Didn't receive code?",
                                  style: GoogleFonts.poppins(
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_canResend)
                                  TextButton(
                                    onPressed: _isResending ? null : _resendOTP,
                                    child: _isResending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                                          ),
                                        )
                                      : Text(
                                          "Resend",
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFFFFB703),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                  )
                                else
                                  Text(
                                    "Resend in ${_resendCountdown}s",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Change phone number
                            TextButton(
                              onPressed: () {
                                _authService.clearVerificationData();
                                Navigator.pop(context);
                              },
                              child: Text(
                                "Change Phone Number",
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}