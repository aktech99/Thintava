// lib/screens/user/user_home.dart - Updated for SMS auth
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/widgets/session_checker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';

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
  final searchController = TextEditingController();
  String filterOption = "All";
  
  Map<String, dynamic>? _userData;
  bool _isLoadingUserData = true;

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

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _loadUserData();
    
    _authService.startSessionListener(() {
      logout(context, forceLogout: true);
    });
  }

  Future<void> _loadUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final userData = await _authService.getUserData(user.uid);
        if (mounted) {
          setState(() {
            _userData = userData;
            _isLoadingUserData = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
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
    searchController.dispose();
    _authService.stopSessionListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuStream = FirebaseFirestore.instance.collection('menuItems').snapshots();

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
              icon: const Icon(Icons.track_changes),
              tooltip: "Track Order",
              onPressed: () => Navigator.pushNamed(context, '/track'),
            ),
            Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart),
                      tooltip: "Cart",
                      onPressed: () => Navigator.pushNamed(context, '/cart'),
                    ),
                    if (cartProvider.itemCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB703),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            '${cartProvider.itemCount}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
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
                const Color(0xFFFFB703),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User greeting and search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _isLoadingUserData
                          ? Container(
                              height:40,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            )
                          : Text(
                              "Hello, ${_getUserDisplayName()}!",
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF023047),
                              ),
                            ),
                        const SizedBox(height: 16),
                        
                        // Search and filter row
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  decoration: InputDecoration(
                                    hintText: "Search food items",
                                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                  ),
                                  onChanged: (value) {
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.filter_list, color: Color(0xFF023047)),
                                  tooltip: "Filter",
                                  onSelected: (String value) {
                                    setState(() {
                                      filterOption = value;
                                    });
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'All',
                                      child: Text('All Items'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'Veg',
                                      child: Text('Vegetarian Only'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'Non Veg',
                                      child: Text('Non-Vegetarian'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Filter indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          "Filter: ",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF023047),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            filterOption,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Menu items list
                  Expanded(
                    child: StreamBuilder(
                      stream: menuStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFFB703),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text("No items available"));
                        }

                        final items = snapshot.data!.docs;
                        
                        // Filter items based on search text and veg/non-veg filter
                        final filteredItems = items.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = (data['name'] ?? "").toString().toLowerCase();
                          final searchText = searchController.text.toLowerCase();
                          bool matchesSearch = name.contains(searchText);

                          bool matchesFilter = true;
                          if (filterOption == "Veg") {
                            matchesFilter = data['isVeg'] == true;
                          } else if (filterOption == "Non Veg") {
                            matchesFilter = data['isVeg'] == false;
                          }
                          
                          return matchesSearch && matchesFilter;
                        }).toList();

                        if (filteredItems.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 50, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                const Text("No matching items"),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      searchController.clear();
                                      filterOption = "All";
                                    });
                                  },
                                  child: const Text("Clear filters"),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final doc = filteredItems[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final id = doc.id;
                            final price = (data['price'] ?? 0.0) is double 
                              ? (data['price'] ?? 0.0) 
                              : double.parse((data['price'] ?? '0').toString());
                            bool isVeg = data['isVeg'] ?? false;

                            return Consumer<CartProvider>(
                              builder: (context, cartProvider, child) {
                                int quantity = cartProvider.getQuantity(id);
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Food Image
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: data['imageUrl'] != null
                                            ? Image.network(
                                                data['imageUrl'],
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  width: 100,
                                                  height: 100,
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.restaurant, size: 40),
                                                ),
                                              )
                                            : Container(
                                                width: 100,
                                                height: 100,
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.restaurant, size: 40),
                                              ),
                                        ),
                                        
                                        const SizedBox(width: 12),
                                        
                                        // Food details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  // Veg/Non-veg indicator
                                                  Container(
                                                    padding: const EdgeInsets.all(2),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: isVeg ? Colors.green : Colors.red,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.circle,
                                                      size: 8,
                                                      color: isVeg ? Colors.green : Colors.red,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  // Item name
                                                  Expanded(
                                                    child: Text(
                                                      data['name'] ?? 'Food Item',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              
                                              const SizedBox(height: 4),
                                              
                                              // Description if available
                                              if (data['description'] != null)
                                                Text(
                                                  data['description'],
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                
                                              const SizedBox(height: 8),
                                              
                                              // Price and add to cart row
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    "₹${price.toStringAsFixed(2)}",
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFFFFB703),
                                                    ),
                                                  ),
                                                  
                                                  // Add/Remove buttons
                                                  quantity > 0 
                                                    ? Row(
                                                        children: [
                                                          IconButton(
                                                            onPressed: () => cartProvider.removeItem(id),
                                                            icon: const Icon(Icons.remove_circle_outline),
                                                            color: const Color(0xFFFFB703),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(
                                                              minWidth: 32,
                                                              minHeight: 32,
                                                            ),
                                                          ),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFFFB703).withOpacity(0.1),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              quantity.toString(),
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                          IconButton(
                                                            onPressed: () => cartProvider.addItem(id),
                                                            icon: const Icon(Icons.add_circle_outline),
                                                            color: const Color(0xFFFFB703),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(
                                                              minWidth: 32,
                                                              minHeight: 32,
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : ElevatedButton(
                                                        onPressed: () => cartProvider.addItem(id),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFFFFB703),
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                          minimumSize: const Size(40, 30),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(16),
                                                          ),
                                                        ),
                                                        child: const Text("ADD"),
                                                      ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Quick Actions at bottom
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      width: MediaQuery.of(context).size.width * 0.85,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF9F0),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickAction(
                            context,
                            Icons.track_changes_outlined,
                            "Track",
                            () => Navigator.pushNamed(context, '/track'),
                          ),
                          _buildQuickAction(
                            context,
                            Icons.history_outlined,
                            "History",
                            () => Navigator.pushNamed(context, '/history'),
                          ),
                          _buildQuickAction(
                            context,
                            Icons.person_outline,
                            "Profile",
                            () => _showProfileDialog(),
                          ),
                        ],
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

  String _getUserDisplayName() {
    if (_userData != null && _userData!['username'] != null) {
      return _userData!['username'];
    }
    
    // Fallback to phone number without country code
    final user = _authService.currentUser;
    if (user?.phoneNumber != null) {
      String phone = user!.phoneNumber!;
      // Remove country code and show last 4 digits
      if (phone.length > 4) {
        return "User${phone.substring(phone.length - 4)}";
      }
      return "User";
    }
    
    return "User";
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Profile Information',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_userData != null) ...[
              _buildProfileRow('Username', _userData!['username'] ?? 'Not set'),
              _buildProfileRow('Phone', _userData!['phoneNumber'] ?? 'Not set'),
              _buildProfileRow('Role', _userData!['role'] ?? 'user'),
              _buildProfileRow('Member since', _formatDate(_userData!['createdAt'])),
            ] else ...[
              Text('Loading profile...', style: GoogleFonts.poppins()),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFFB703),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = timestamp.toDate();
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
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

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.black87,
            size: 22,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}