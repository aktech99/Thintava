import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  Stream<DocumentSnapshot?> getLatestOrderStream() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print("No user logged in, redirecting to login page");
      // Redirect to login or show a message
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Track Your Order")),
      body: StreamBuilder<DocumentSnapshot?>(
        stream: getLatestOrderStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No current orders."));
          }

          final order = snapshot.data!.data() as Map<String, dynamic>;
          final status = order['status'] ?? 'Unknown';
          final total = order['total'] ?? 0.0;
          final items = (order['items'] as Map<String, dynamic>?)
              ?.entries
              .map((e) => "${e.key}: ${e.value}")
              .join('\n') ??
              'No items';

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Order Status: $status", style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 10),
                Text("Total: ₹$total", style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text("Items:\n$items", style: const TextStyle(fontSize: 16)),
              ],
            ),
          );
        },
      ),
    );
  }
}
