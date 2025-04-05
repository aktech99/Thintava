import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final cart = <String, int>{};
  final searchController = TextEditingController();
  String filterOption = "All"; // Options: "All", "Veg", "Non Veg"

  void increaseQuantity(String itemId) {
    setState(() {
      cart[itemId] = (cart[itemId] ?? 0) + 1;
    });
  }

  void decreaseQuantity(String itemId) {
    setState(() {
      if (cart[itemId] != null && cart[itemId]! > 0) {
        cart[itemId] = cart[itemId]! - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuStream = FirebaseFirestore.instance.collection('menuItems').snapshots();

    return WillPopScope(
      onWillPop: () async {
        // Prevent navigating back from the home screen.
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          // Optionally, remove the leading back button if it's not needed:
          // automaticallyImplyLeading: false,
          title: const Text("Menu"),
          actions: [
            IconButton(
              icon: const Icon(Icons.track_changes),
              tooltip: "Track Order",
              onPressed: () {
                Navigator.pushNamed(context, '/track');
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Logout",
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/auth');
              },
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 255, 255, 255), Color.fromARGB(255, 255, 255, 255)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Search bar and filter row.
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: "Search food items",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: filterOption,
                      onChanged: (newValue) {
                        setState(() {
                          filterOption = newValue!;
                        });
                      },
                      items: <String>["All", "Veg", "Non Veg"]
                          .map((String value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              // Menu items list.
              Expanded(
                child: StreamBuilder(
                  stream: menuStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final items = snapshot.data!.docs;
                    // Filter items based on search text and veg/non-veg filter.
                    final filteredItems = items.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? "").toString().toLowerCase();
                      final searchText = searchController.text.toLowerCase();
                      bool matchesSearch = name.contains(searchText);

                      // Check the veg filter. Assuming each item has a boolean 'isVeg'
                      bool matchesFilter = true;
                      if (filterOption == "Veg") {
                        matchesFilter = data['isVeg'] == true;
                      } else if (filterOption == "Non Veg") {
                        matchesFilter = data['isVeg'] == false;
                      }
                      return matchesSearch && matchesFilter;
                    }).toList();

                    if (filteredItems.isEmpty) {
                      return const Center(child: Text("No items found"));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final doc = filteredItems[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final id = doc.id;
                        int quantity = cart[id] ?? 0;

                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Food Image.
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: data['imageUrl'] != null
                                      ? Image.network(
                                          data['imageUrl'],
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 100,
                                          height: 100,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.fastfood, size: 50),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Dish Details.
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['name'] ?? 'Item',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "₹${data['price']}",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Quantity controller.
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () => decreaseQuantity(id),
                                    ),
                                    Text(
                                      quantity.toString(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () => increaseQuantity(id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: "Go to Cart",
          onPressed: () {
            Navigator.pushNamed(context, '/cart', arguments: cart);
          },
          child: const Icon(Icons.shopping_cart),
        ),
      ),
    );
  }
}
