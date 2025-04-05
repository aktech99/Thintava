import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/screens/role_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);
  
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = 'user';
  final auth = AuthService();

  void handleRegister() async {
    try {
      final user = await auth.register(emailController.text, passwordController.text, selectedRole);
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RoleRouter(uid: user.uid)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Register Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Extend background behind AppBar.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Register", style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Create Account",
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sign up to get started",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          labelText: "Email",
                          labelStyle: GoogleFonts.poppins(color: Colors.black54),
                          prefixIcon: const Icon(Icons.email),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: GoogleFonts.poppins(color: Colors.black54),
                          prefixIcon: const Icon(Icons.lock),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: "Select Role",
                          labelStyle: GoogleFonts.poppins(color: Colors.black54),
                          prefixIcon: const Icon(Icons.person),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (value) => setState(() => selectedRole = value!),
                        items: ['user', 'kitchen', 'admin'].map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role.toUpperCase(), style: GoogleFonts.poppins()),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: handleRegister,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                          ),
                          child: Text(
                            "Register",
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
