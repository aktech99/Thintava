import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in.")),
      );
    }

    // Fetch orders where the userId matches the currently logged-in user
    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid) // Ensure orders are for the logged-in user
        .orderBy('timestamp', descending: true) // Sort orders by timestamp in descending order
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text("My Orders")),
      body: StreamBuilder(
        stream: ordersStream,
        builder: (context, snapshot) {
          // Loading state
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final orders = snapshot.data!.docs;

          // Empty orders state
          if (orders.isEmpty) {
            return const Center(child: Text("You have no orders yet."));
          }

          // Build the list of orders
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;

              // Retrieve items (as a Map), join them into a readable string format
              final items = (data['items'] as Map<String, dynamic>)
                  .entries
                  .map((e) => "${e.key} x${e.value}")
                  .join(', ');

              // Fetch other relevant data: status, timestamp, total
              final status = data['status'] ?? 'unknown';
              final timestamp = (data['timestamp'] as Timestamp).toDate();
              final total = data['total'] ?? 0.0;

              // Create a list tile to display each order
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                elevation: 4,
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text("₹$total - $status"), // Order total and status
                  subtitle: Text(
                    "Items: $items\nDate: $timestamp", // Displaying items and timestamp
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
