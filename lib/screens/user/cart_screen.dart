// lib/screens/user/cart_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:provider/provider.dart';
import 'package:canteen_app/providers/cart_provider.dart';
import 'package:google_fonts/google_fonts.dart';

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
      'theme': {
        'color': '#FFB703'
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Processing order..."),
          ],
        ),
      ),
    );

    try {
      // Create order in Firestore
      final user = FirebaseAuth.instance.currentUser;
      final orderData = <String, dynamic>{
        'userId': user?.uid ?? '',
        'items': <String, dynamic>{}, // Fixed: Explicit Map type
        'total': total,
        'status': 'Placed',
        'timestamp': FieldValue.serverTimestamp(),
        'paymentId': response.paymentId,
      };

      // Add items to order - Fixed the type issue
      final Map<String, dynamic> orderItems = {};
      cartProvider.cart.forEach((itemId, quantity) {
        final item = menuMap[itemId];
        if (item != null) {
          orderItems[itemId] = {
            'name': item['name'],
            'price': item['price'],
            'quantity': quantity,
            'subtotal': item['price'] * quantity,
          };
        }
      });
      orderData['items'] = orderItems; // Assign the complete map

      final docRef = await FirebaseFirestore.instance.collection('orders').add(orderData);
      
      // Clear cart
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
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Order Placed!",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your order has been placed successfully.",
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order Details:",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Order ID: ${docRef.id.substring(0, 8).toUpperCase()}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "Payment ID: ${response.paymentId?.substring(0, 16) ?? 'N/A'}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.grey,
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
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: "RETRY",
          textColor: Colors.white,
          onPressed: startPayment,
        ),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet: ${response.walletName}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Cart",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFFB703),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          // Recalculate total when cart changes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            recalcTotal();
          });

          return isLoading
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
                                final imageUrl = item['imageUrl'] ?? '';
                                final name = item['name'] ?? 'Unknown Item';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Food Image
                                        Container(
                                          width: 70,
                                          height: 70,
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
                                                        size: 30,
                                                        color: const Color(0xFFFFB703).withOpacity(0.7),
                                                      );
                                                    },
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.fastfood,
                                                  size: 30,
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
                                              const SizedBox(height: 8),
                                              
                                              // Price and quantity info
                                              Row(
                                                children: [
                                                  Text(
                                                    "₹$price",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFFFFB703),
                                                    ),
                                                  ),
                                                  Text(
                                                    " × $quantity = ₹${(price * quantity).toStringAsFixed(2)}",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
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
                                                            color: Color(0xFFFFB703),
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
                                                            color: Color(0xFFFFB703),
                                                            size: 20,
                                                          ),
                                                          onPressed: () => cartProvider.addItem(itemId), // Fixed: Only one argument
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
                            Text(
                              "BILL DETAILS",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFB703),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Subtotal
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Subtotal",
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                                Text(
                                  "₹${total.toStringAsFixed(2)}",
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Taxes (GST)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "GST (5%)",
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                                Text(
                                  "₹${(total * 0.05).toStringAsFixed(2)}",
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ],
                            ),
                            const Divider(thickness: 1),
                            
                            // Total
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Total",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "₹${(total * 1.05).toStringAsFixed(2)}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFFB703),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Place order button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: startPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB703),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  "PLACE ORDER - ₹${(total * 1.05).toStringAsFixed(2)}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
        },
      ),
    );
  }
}