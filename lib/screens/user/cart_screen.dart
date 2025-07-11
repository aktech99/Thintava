// lib/screens/user/cart_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double total = 0;
  Map<String, dynamic> menuMap = {};
  late Razorpay _razorpay;
  bool isLoading = true;

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
    setState(() {
      isLoading = true;
    });
    
    final snapshot = await FirebaseFirestore.instance.collection('menuItems').get();
    
    setState(() {
      for (var doc in snapshot.docs) {
        menuMap[doc.id] = doc.data();
      }
      recalcTotal();
      isLoading = false;
    });
  }

  void recalcTotal() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    double newTotal = 0;
    cartProvider.cart.forEach((key, qty) {
      final price = menuMap[key]?['price'] ?? 0;
      newTotal += price * qty;
    });
    setState(() {
      total = newTotal;
    });
  }

  void startPayment() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    if (cartProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your cart is empty")),
      );
      return;
    }

    var options = {
      'key': 'rzp_live_FBnjPJmPGZ9JHo', // Replace with your Razorpay key
      'amount': (total * 100).toInt(), // Amount in paise
      'name': 'Thintava',
      'description': 'Food Order Payment',
      'prefill': {
        'contact': '',
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
      },
      'currency': 'INR',
      'theme': {
        'color': '#FFB703',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment error: ${e.toString()}")),
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFB703),
        ),
      ),
    );
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final Map<String, dynamic> orderItems = {};

      cartProvider.cart.forEach((itemId, qty) {
        final itemData = menuMap[itemId];
        if (itemData != null) {
          orderItems[itemId] = {
            'name': itemData['name'] ?? 'Unknown',
            'price': itemData['price'] ?? 0,
            'quantity': qty,
            'subtotal': (itemData['price'] ?? 0) * qty,
          };
        }
      });

      final order = {
        'userId': user.uid,
        'userEmail': user.email,
        'items': orderItems,
        'status': 'Placed',
        'timestamp': Timestamp.now(),
        'total': total,
        'paymentId': response.paymentId,
        'paymentStatus': 'success',
      };

      await FirebaseFirestore.instance.collection('orders').add(order);
      
      // Clear the cart using provider
      cartProvider.clearCart();
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle, 
                  color: Colors.green, 
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Order Placed Successfully!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB703).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFB703).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Your order has been placed successfully and will be prepared shortly.",
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Order Total:",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          "₹${total.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFB703),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Payment ID:",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            response.paymentId ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You can track your order status and get updates on preparation time.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close success dialog
                // Navigate to order tracking and clear navigation stack
                Navigator.pushNamedAndRemoveUntil(
                  context, 
                  '/track',
                  (route) => false,
                );
              },
              icon: const Icon(Icons.track_changes),
              label: const Text("TRACK ORDER"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB703),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error processing order: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Payment failed! Tap to retry."),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: startPayment,
        ),
        backgroundColor: Colors.red,
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
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        // Recalculate total when cart changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          recalcTotal();
        });

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFB703),
            title: const Text(
              "Your Cart",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            elevation: 0,
            actions: [
              if (!cartProvider.isEmpty)
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Clear Cart"),
                        content: const Text("Are you sure you want to clear your cart?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("CANCEL"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              cartProvider.clearCart();
                            },
                            child: const Text("CLEAR"),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  label: const Text(
                    "Clear",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          body: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFB703),
                  ),
                )
              : Column(
                  children: [
                    // Order summary header
                    Container(
                      color: const Color(0xFFFFB703),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "ORDER SUMMARY",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${cartProvider.itemCount} item${cartProvider.itemCount != 1 ? 's' : ''}",
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Cart items list
                    Expanded(
                      child: cartProvider.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Your cart is empty",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFB703),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text("Browse Menu"),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: cartProvider.cart.length,
                              itemBuilder: (context, index) {
                                final itemId = cartProvider.cart.keys.elementAt(index);
                                final quantity = cartProvider.cart[itemId]!;
                                final item = menuMap[itemId];
                                if (item == null) return const SizedBox();
                                final price = item['price'] ?? 0;
                                final isVeg = item['isVeg'] ?? false;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Food image
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: item['imageUrl'] != null
                                                  ? Image.network(
                                                      item['imageUrl'],
                                                      width: 80,
                                                      height: 80,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(
                                                        width: 80,
                                                        height: 80,
                                                        color: Colors.grey[200],
                                                        child: Icon(
                                                          Icons.restaurant,
                                                          size: 40,
                                                          color: Colors.grey[400],
                                                        ),
                                                      ),
                                                    )
                                                  : Container(
                                                      width: 80,
                                                      height: 80,
                                                      color: Colors.grey[200],
                                                      child: Icon(
                                                        Icons.restaurant,
                                                        size: 40,
                                                        color: Colors.grey[400],
                                                      ),
                                                    ),
                                            ),
                                            // Veg/Non-veg indicator
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: isVeg ? Colors.green : Colors.red,
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: Radius.circular(8),
                                                    bottomRight: Radius.circular(8),
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.circle,
                                                  size: 8,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
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
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF023047),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              if (item['description'] != null)
                                                Text(
                                                  item['description'],
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    "₹${price.toStringAsFixed(2)} × $quantity",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                  Text(
                                                    "₹${(price * quantity).toStringAsFixed(2)}",
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFFFFB703),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              
                                              // Quantity controls
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[100],
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.remove_circle_outline,
                                                            color: Color(0xFF023047),
                                                            size: 20,
                                                          ),
                                                          onPressed: () => cartProvider.removeItem(itemId),
                                                          constraints: const BoxConstraints(
                                                            minWidth: 32,
                                                            minHeight: 32,
                                                          ),
                                                          padding: EdgeInsets.zero,
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
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
                                                          icon: const Icon(
                                                            Icons.add_circle_outline,
                                                            color: Color(0xFF023047),
                                                            size: 20,
                                                          ),
                                                          onPressed: () => cartProvider.addItem(itemId),
                                                          constraints: const BoxConstraints(
                                                            minWidth: 32,
                                                            minHeight: 32,
                                                          ),
                                                          padding: EdgeInsets.zero,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    onPressed: () => cartProvider.removeItemCompletely(itemId),
                                                    constraints: const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                    padding: EdgeInsets.zero,
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
                            ),
                    ),
                    
                    // Order Summary
                    if (!cartProvider.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bill details
                            const Text(
                              "BILL DETAILS",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF023047),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Item Total",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  "₹${total.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "GST",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const Text(
                                  "Included",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Divider(),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Grand Total",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF023047),
                                  ),
                                ),
                                Text(
                                  "₹${total.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFFB703),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Place order button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: startPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB703),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.payment),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Place Order • ₹${total.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
