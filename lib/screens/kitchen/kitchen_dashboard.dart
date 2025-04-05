import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Helper function to capitalize status.
String capitalize(String s) =>
    s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

class KitchenDashboard extends StatelessWidget {
  const KitchenDashboard({Key? key}) : super(key: key);

  Stream<QuerySnapshot> getOrdersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': newStatus,
      if (newStatus == 'Pick Up')
        'pickedUpTime': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Kitchen Dashboard"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: "Back",
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/kitchen-menu');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
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
            colors: [Color(0xFF004D40), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: getOrdersStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text("Something went wrong",
                    style: TextStyle(color: Colors.white)),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snapshot.data!.docs;
            if (orders.isEmpty) {
              return const Center(
                child: Text("No orders yet.",
                    style: TextStyle(color: Colors.white)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final data = order.data() as Map<String, dynamic>;
                return _OrderCard(
                  orderId: order.id,
                  data: data,
                  updateOrderStatus: updateOrderStatus,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Future<void> Function(String, String) updateOrderStatus;

  const _OrderCard({
    Key? key,
    required this.orderId,
    required this.data,
    required this.updateOrderStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String status = capitalize(data['status'] ?? '');
    String shortOrderId = orderId.substring(0, 6);
    String itemsString = data['items'] is Map
        ? (data['items'] as Map<String, dynamic>)
            .entries
            .map((e) => '${e.key} (${e.value})')
            .join(', ')
        : 'N/A';

    return Card(
      color: Colors.white.withOpacity(0.95),
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Order ID: $shortOrderId",
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Items: $itemsString", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("Status: ",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                DropdownButton<String>(
                  value: status,
                  underline: Container(),
                  iconEnabledColor: Colors.black,
                  onChanged: (newStatus) {
                    if (newStatus != null) {
                      updateOrderStatus(orderId, newStatus);
                    }
                  },
                  items: ['Placed', 'Cooking', 'Cooked', 'Pick Up']
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, style: const TextStyle(fontSize: 16)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
