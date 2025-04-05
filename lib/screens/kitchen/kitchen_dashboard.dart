// 🔧 FILE: lib/screens/kitchen/kitchen_dashboard.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Helper function to capitalize status
String capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

class KitchenDashboard extends StatelessWidget {
  const KitchenDashboard({super.key});

  Stream<QuerySnapshot> getOrdersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': newStatus,
      if (newStatus == 'Pick Up') 'pickedUpTime': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kitchen Dashboard")),
      body: StreamBuilder<QuerySnapshot>(
        stream: getOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const Center(child: Text("No orders yet."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text("Order ID: ${order.id.substring(0, 6)}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        "Items: ${(data['items'] is Map 
                          ? (data['items'] as Map<String, dynamic>).entries.map((e) => '${e.key} (${e.value})').join(', ') 
                          : 'N/A')}",
                      ),
                      const SizedBox(height: 6),
                      Text("Status: ${capitalize(data['status'])}"),
                    ],
                  ),
                  trailing: DropdownButton<String>(
                    value: capitalize(data['status']),
                    onChanged: (newStatus) {
                      if (newStatus != null) {
                        updateOrderStatus(order.id, newStatus);
                      }
                    },
                    items: ['Placed', 'Cooking', 'Cooked', 'Pick Up']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
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
