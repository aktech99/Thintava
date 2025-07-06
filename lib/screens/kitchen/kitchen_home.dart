// lib/screens/kitchen/kitchen_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:canteen_app/screens/kitchen/kitchen_dashboard.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/widgets/session_checker.dart';

class KitchenHome extends StatefulWidget {
  const KitchenHome({Key? key}) : super(key: key);

  @override
  State<KitchenHome> createState() => _KitchenHomeState();
}

class _KitchenHomeState extends State<KitchenHome> {
  Map<String, int> _orderStats = {'active': 0, 'pending': 0, 'completed': 0};
  bool _isLoading = true;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchOrderStats();
    
    // Start session listener
    _authService.startSessionListener(() {
      // Handle forced logout
      _handleForcedLogout();
    });
  }
  
  @override
  void dispose() {
    _authService.stopSessionListener();
    super.dispose();
  }
  
  void _handleForcedLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  Future<void> _fetchOrderStats() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();
      
      final stats = {'active': 0, 'pending': 0, 'completed': 0};
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        
        if (status == 'Placed') {
          stats['pending'] = (stats['pending'] ?? 0) + 1;
        } else if (status == 'Cooking' || status == 'Cooked' || status == 'Pick Up') {
          stats['active'] = (stats['active'] ?? 0) + 1;
        } else if (status == 'PickedUp') {
          stats['completed'] = (stats['completed'] ?? 0) + 1;
        }
      }
      
      if (mounted) {
        setState(() {
          _orderStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching order stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToKitchenDashboard() {
    print("Attempting to navigate to kitchen dashboard");
    // Try direct navigation with MaterialPageRoute
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const KitchenDashboard(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionChecker(
      authService: _authService,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFB703).withOpacity(0.9),
                const Color(0xFFFFB703).withOpacity(0.7),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kitchen Portal',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _authService.currentUser?.displayName != null
                                ? 'Welcome, ${_authService.currentUser!.displayName}'
                                : 'Welcome, Chef',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.black87,
                          size: 28,
                        ),
                        onPressed: () async {
                          // Show confirmation dialog
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Logout'),
                              content: const Text('Are you sure you want to logout?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFB703),
                                  ),
                                  child: const Text('Logout'),
                                ),
                              ],
                            ),
                          );
                          
                          if (confirmed == true) {
                            // Use AuthService instead of FirebaseAuth directly
                            await _authService.logout();
                            if (mounted) {
                              Navigator.pushReplacementNamed(context, '/auth');
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                // Stats Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Active',
                                value: _orderStats['active'] ?? 0,
                                icon: Icons.local_fire_department,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Pending',
                                value: _orderStats['pending'] ?? 0,
                                icon: Icons.access_time,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Completed',
                                value: _orderStats['completed'] ?? 0,
                                icon: Icons.check_circle,
                                color: const Color(0xFF004D40),
                              ),
                            ),
                          ],
                        ),
                ),
                
                // Main Content Area
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 36),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kitchen Management',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Dashboard Tiles
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              children: [
                                _MenuTile(
                                  title: 'Order Dashboard',
                                  icon: Icons.dashboard_customize,
                                  color: const Color(0xFFFFB703),
                                  onTap: _navigateToKitchenDashboard,
                                ),
                                _MenuTile(
                                  title: 'Inventory',
                                  icon: Icons.inventory,
                                  color: Colors.blueAccent,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Inventory module coming soon!'),
                                        backgroundColor: const Color(0xFFFFB703),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                                _MenuTile(
                                  title: 'Staff Schedule',
                                  icon: Icons.schedule,
                                  color: Colors.purple,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Staff scheduling module coming soon!'),
                                        backgroundColor: const Color(0xFFFFB703),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                                _MenuTile(
                                  title: 'Reports',
                                  icon: Icons.bar_chart,
                                  color: const Color(0xFF004D40),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Reports module coming soon!'),
                                        backgroundColor: const Color(0xFFFFB703),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ],
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
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFFFFB703),
          foregroundColor: Colors.black87,
          onPressed: _fetchOrderStats,
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}