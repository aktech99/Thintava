// 🔧 FILE: lib/screens/cart/cart_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class CartScreen extends StatefulWidget {
  final Map<String, int> cart;

  const CartScreen({Key? key, required this.cart}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double total = 0;
  Map<String, dynamic> menuMap = {};
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    fetchItems();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> fetchItems() async {
    final snapshot = await FirebaseFirestore.instance.collection('menuItems').get();
    setState(() {
      for (var doc in snapshot.docs) {
        menuMap[doc.id] = doc.data();
      }
      recalcTotal();
    });
  }

  void recalcTotal() {
    double newTotal = 0;
    widget.cart.forEach((key, qty) {
      final price = menuMap[key]?['price'] ?? 0;
      newTotal += price * qty;
    });
    setState(() {
      total = newTotal;
    });
  }

  void increaseQuantity(String itemId) {
    setState(() {
      widget.cart[itemId] = (widget.cart[itemId] ?? 0) + 1;
      recalcTotal();
    });
  }

  void decreaseQuantity(String itemId) {
    setState(() {
      if (widget.cart[itemId] != null && widget.cart[itemId]! > 1) {
        widget.cart[itemId] = widget.cart[itemId]! - 1;
      } else {
        widget.cart.remove(itemId);
      }
      recalcTotal();
    });
  }

  void removeItem(String itemId) {
    setState(() {
      widget.cart.remove(itemId);
      recalcTotal();
    });
  }

  void startPayment() {
    if (widget.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your cart is empty")),
      );
      return;
    }

    var options = {
      'key': 'rzp_live_FBnjPJmPGZ9JHo', // Replace with your Razorpay key
      'amount': (total * 100).toInt(), // Amount in paise
      'name': 'Canteen Order',
      'description': 'Food Order Payment',
      'prefill': {
        'contact': '',
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
      },
      'currency': 'INR',
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

 void _handlePaymentSuccess(PaymentSuccessResponse response) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final Map<String, int> orderItems = {};

  widget.cart.forEach((itemId, qty) {
    final itemName = menuMap[itemId]?['name'] ?? 'Unknown';
    orderItems[itemName] = qty;
  });

  final order = {
    'userId': user.uid,
    'items': orderItems,
    'status': 'placed',
    'timestamp': Timestamp.now(),
    'total': total,
    'paymentId': response.paymentId,
    'paymentStatus': 'success',
  };

  await FirebaseFirestore.instance.collection('orders').add(order);

  // ✅ CLEAR THE CART
  widget.cart.clear();

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Order placed successfully!"))
  );
  Navigator.popUntil(context, (route) => route.isFirst);
}



 void _handlePaymentError(PaymentFailureResponse response) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text("Payment failed! Tap to retry."),
      action: SnackBarAction(
        label: 'Retry',
        onPressed: startPayment, // ✅ Retry payment
      ),
    ),
  );
}


  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("External Wallet selected.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Cart")),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004D40), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: widget.cart.isEmpty
                  ? const Center(child: Text("Your cart is empty"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: widget.cart.length,
                      itemBuilder: (context, index) {
                        final itemId = widget.cart.keys.elementAt(index);
                        final quantity = widget.cart[itemId]!;
                        final item = menuMap[itemId];
                        if (item == null) return const SizedBox();
                        final price = item['price'] ?? 0;

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Food image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: item['imageUrl'] != null
                                      ? Image.network(
                                          item['imageUrl'],
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.fastfood, size: 40),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Dish details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? 'Item',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "₹$price",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Subtotal: ₹${price * quantity}",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                // Quantity selector and delete button
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          onPressed: () => decreaseQuantity(itemId),
                                        ),
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 300),
                                          transitionBuilder: (child, animation) =>
                                              FadeTransition(opacity: animation, child: child),
                                          child: Text(
                                            '$quantity',
                                            key: ValueKey<int>(quantity),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          onPressed: () => increaseQuantity(itemId),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => removeItem(itemId),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Text(
                    "Total: ₹$total",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: startPayment,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      child: const Text(
                        "Pay & Place Order",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
