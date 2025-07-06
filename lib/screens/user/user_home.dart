// lib/screens/user/user_home.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/widgets/session_checker.dart';

class UserHome extends StatefulWidget {
  const UserHome({Key? key}) : super(key: key);

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Overall fade-in animation for the content
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Pulse animation for interactive elements
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    
    // Start listening for session changes
    _authService.startSessionListener(() {
      logout(context, forceLogout: true);
    });
  }

  void logout(BuildContext context, {bool forceLogout = false}) async {
    if (!forceLogout) {
      // Show a cool animated dialog before logout
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Logging Out'),
          content: SizedBox(
            height: 100,
            child: Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
                  ),
                  const SizedBox(height: 20),
                  Text('Thank you for visiting!', 
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      // Actual logout with a small delay for animation
      await Future.delayed(const Duration(seconds: 1));
    }
    
    // Use AuthService.logout
    await _authService.logout();
    
    if (!forceLogout && context.mounted) {
      Navigator.of(context).pop(); // Close dialog
    }
    
    if (context.mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _authService.stopSessionListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the main UI in a SessionChecker
    return SessionChecker(
      authService: _authService,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            "Thintava", 
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: "Notifications",
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No new notifications!', 
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.black87,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: "Logout",
              onPressed: () => logout(context),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFB703), // The requested amber color
                const Color(0xFFFFB703).withOpacity(0.85),
                const Color(0xFFFDC85D),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      "What would you like today?",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF023047),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Explore our delicious menu options",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: const Color(0xFF023047).withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Food categories horizontal scrollable list
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildCategoryItem(Icons.local_pizza, "Pizza"),
                          _buildCategoryItem(Icons.lunch_dining, "Burgers"),
                          _buildCategoryItem(Icons.ramen_dining, "Noodles"),
                          _buildCategoryItem(Icons.icecream, "Desserts"),
                          _buildCategoryItem(Icons.local_drink, "Drinks"),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    Text(
                      "Quick Actions",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF023047),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        shrinkWrap: true,
                        physics: const ScrollPhysics(),
                        children: [
                          _buildActionCard(
                            context,
                            Icons.restaurant_menu,
                            "Browse Menu",
                            "Explore our delicious options",
                            () => Navigator.pushNamed(context, '/menu'),
                            Colors.orangeAccent,
                          ),
                          _buildActionCard(
                            context,
                            Icons.track_changes,
                            "Track Order",
                            "Check your current order status",
                            () => Navigator.pushNamed(context, '/track'),
                            Colors.blueAccent,
                          ),
                          _buildActionCard(
                            context,
                            Icons.history,
                            "Order History",
                            "View your past orders",
                            () => Navigator.pushNamed(context, '/history'),
                            Colors.purpleAccent,
                          ),
                          _buildActionCard(
                            context,
                            Icons.local_offer,
                            "Special Deals",
                            "Check out today's offers",
                            () => Navigator.pushNamed(context, '/deals'),
                            Colors.redAccent,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 15),
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 30,
              color: const Color(0xFF023047),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF023047),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    Color accentColor,
  ) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF023047),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}