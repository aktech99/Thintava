import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/screens/auth/otp_verification_screen.dart';
import 'package:canteen_app/services/auth_service.dart';

class PhoneInputScreen extends StatefulWidget {
  final bool isLogin;
  
  const PhoneInputScreen({
    Key? key,
    this.isLogin = true, // Default to true since we only have login now
  }) : super(key: key);

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> 
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = false;
  String _selectedCountryCode = '+91';

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
    _phoneController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber => '$_selectedCountryCode${_phoneController.text}';

  void _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      bool success = await _authService.sendOTP(
        phoneNumber: _fullPhoneNumber,
        onCodeSent: (verificationId) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPVerificationScreen(
                  phoneNumber: _fullPhoneNumber,
                  username: _usernameController.text.trim(),
                  isLogin: true, // Always true for unified flow
                ),
              ),
            );
          }
        },
        onError: (error) {
          if (mounted) {
            _showError(error);
          }
        },
        onAutoVerificationCompleted: () {
          if (mounted) {
            // Auto verification successful, navigate to home
            Navigator.pushReplacementNamed(context, '/splash');
          }
        },
      );

      if (!success) {
        _showError('Failed to send OTP. Please try again.');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
        backgroundColor: Colors.red,
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
            right: -100,
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
              child: Form(
                key: _formKey,
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
                                Text(
                                  "Welcome!",
                                  style: GoogleFonts.poppins(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Enter your phone number to continue",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),

                                // Username field (optional for better UX)
                                TextFormField(
                                  controller: _usernameController,
                                  style: GoogleFonts.poppins(),
                                  decoration: InputDecoration(
                                    labelText: "Display Name (Optional)",
                                    labelStyle: GoogleFonts.poppins(color: Colors.black54),
                                    prefixIcon: const Icon(Icons.person, color: Color(0xFFFFB703)),
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
                                      vertical: 14,
                                    ),
                                    hintText: "Enter your preferred name",
                                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Phone number field
                                Row(
                                  children: [
                                    // Country code dropdown
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedCountryCode,
                                          style: GoogleFonts.poppins(
                                            color: Colors.black87,
                                            fontSize: 16,
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: '+91', child: Text('+91')),
                                            DropdownMenuItem(value: '+1', child: Text('+1')),
                                            DropdownMenuItem(value: '+44', child: Text('+44')),
                                            DropdownMenuItem(value: '+86', child: Text('+86')),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedCountryCode = value!;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Phone number input
                                    Expanded(
                                      child: TextFormField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        style: GoogleFonts.poppins(),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your phone number';
                                          }
                                          if (value.length < 10) {
                                            return 'Please enter a valid phone number';
                                          }
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          labelText: "Phone Number",
                                          labelStyle: GoogleFonts.poppins(color: Colors.black54),
                                          prefixIcon: const Icon(Icons.phone, color: Color(0xFFFFB703)),
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
                                            vertical: 14,
                                          ),
                                          hintText: "Enter your phone number",
                                          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // Info card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB703).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFFB703).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: Color(0xFFFFB703),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "New user? We'll create your account automatically!",
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

                                const SizedBox(height: 24),

                                // Send OTP button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _sendOTP,
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
                                            const Icon(Icons.sms),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Send OTP",
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

                                // Terms and privacy
                                Text(
                                  "By continuing, you agree to our Terms of Service and Privacy Policy",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
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
          ),
        ],
      ),
    );
  }
}