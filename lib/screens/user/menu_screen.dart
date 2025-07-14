// lib/screens/user/menu_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final searchController = TextEditingController();
  String filterOption = "All"; // Options: "All", "Veg", "Non Veg"
  bool isLoading = true;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchMenuItems();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMenuItems() async {
    setState(() {
      isLoading = true;
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuStream = FirebaseFirestore.instance.collection('menuItems').snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Menu",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFFB703),
        actions: [
          IconButton(
            icon: const Icon(Icons.track_changes, color: Colors.white),
            tooltip: "Track Order",
            onPressed: () {
              Navigator.pushNamed(context, '/track');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Logout",
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to logout?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CANCEL"),
                    ),
                    TextButton(
                      onPressed: () async {
                        // Clear cart on logout
                        Provider.of<CartProvider>(context, listen: false).clearCart();
                        
                        // Use AuthService instead of FirebaseAuth directly
                        await _authService.logout();
                        Navigator.pushReplacementNamed(context, '/auth');
                      },
                      child: const Text("LOGOUT"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar and filter row
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
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
                    icon: const Icon(Icons.filter_list, color: Color(0xFFFFB703)),
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
          
          // Filter indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Colors.grey[100],
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
                    color: const Color(0xFFFFB703),
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
            child: isLoading 
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFB703),
                  ),
                )
              : StreamBuilder(
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
                  
                  // Filter items based on search text and veg/non-veg filter.
                  final filteredItems = items.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final isVeg = data['isVeg'] ?? false;
                    final available = data['available'] ?? false;

                    if (!available) return false;

                    bool matchesSearch = name.contains(searchController.text.toLowerCase());
                    bool matchesFilter = filterOption == "All" ||
                        (filterOption == "Veg" && isVeg) ||
                        (filterOption == "Non Veg" && !isVeg);

                    return matchesSearch && matchesFilter;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return const Center(child: Text("No items found"));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final doc = filteredItems[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final id = doc.id;
                      final name = data['name'] ?? 'Unnamed Item';
                      final price = data['price']?.toString() ?? '0';
                      final description = data['description'] ?? '';
                      final isVeg = data['isVeg'] ?? false;
                      final imageUrl = data['imageUrl'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB703).withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFFFB703).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Food Image
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: const Color(0xFFFFB703).withOpacity(0.1),
                                ),
                                child: imageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              Icons.fastfood,
                                              size: 40,
                                              color: const Color(0xFFFFB703).withOpacity(0.7),
                                            );
                                          },
                                        ),
                                      )
                                    : Icon(
                                        Icons.fastfood,
                                        size: 40,
                                        color: const Color(0xFFFFB703).withOpacity(0.7),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Item Details
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
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Icon(
                                            Icons.circle,
                                            size: 8,
                                            color: isVeg ? Colors.green : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        
                                        // Item name
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        description,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    
                                    const SizedBox(height: 8),
                                    
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Price
                                        Text(
                                          "₹$price",
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFFFB703),
                                          ),
                                        ),
                                        
                                        // Add to cart button
                                        Consumer<CartProvider>(
                                          builder: (context, cartProvider, child) {
                                            final quantity = cartProvider.getQuantity(id);
                                            return quantity > 0
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
                                                          color: const Color(0xFFFFB703),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          quantity.toString(),
                                                          style: const TextStyle(
                                                            color: Colors.white,
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
                                                  );
                                          },
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
              ),
          ),
        ],
      ),
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          return FloatingActionButton.extended(
            onPressed: () {
              // Navigate to cart screen
              Navigator.pushNamed(context, '/cart');
            },
            backgroundColor: const Color(0xFFFFB703),
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.white),
                if (cartProvider.itemCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${cartProvider.itemCount}',
                        style: const TextStyle(
                          color: Color(0xFFFFB703),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: Text(
              cartProvider.itemCount > 0 ? "View Cart" : "Cart Empty",
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      ),
    );
  }
}