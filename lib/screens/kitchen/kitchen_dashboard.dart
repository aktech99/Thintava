// lib/screens/kitchen/kitchen_dashboard.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:canteen_app/services/auth_service.dart'; // Add this import

// Capitalize helper
String capitalize(String s) =>
    s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

class KitchenDashboard extends StatefulWidget {
  const KitchenDashboard({Key? key}) : super(key: key);

  @override
  State<KitchenDashboard> createState() => _KitchenDashboardState();
}

class _KitchenDashboardState extends State<KitchenDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _statusFilters = ['All', 'Placed', 'Cooking', 'Cooked', 'Pick Up'];
  String _currentFilter = 'All';
  final _authService = AuthService(); // Add this line

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentFilter = _statusFilters[_tabController.index];
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> getOrdersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final db = FirebaseFirestore.instance;
      final orderRef = db.collection('orders').doc(orderId);

      final updates = <String, Object>{'status': newStatus};
      if (newStatus == 'Cooked') {
        updates['cookedTime'] = FieldValue.serverTimestamp();
      }
      if (newStatus == 'Pick Up') {
        updates['pickedUpTime'] = FieldValue.serverTimestamp();
      }

      await orderRef.update(updates);
      
      // Show confirmation only if widget is still mounted
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${orderId.substring(0, 6)} updated to $newStatus'),
            backgroundColor: const Color(0xFFFFB703),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB703),
        foregroundColor: Colors.black87,
        title: const Text("Kitchen Dashboard", style: TextStyle(color: Colors.black87)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () => Navigator.pushReplacementNamed(context, '/kitchen-menu'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              // Use AuthService instead of FirebaseAuth directly
              await _authService.logout();
              Navigator.pushReplacementNamed(context, '/auth');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF004D40),
          indicatorWeight: 3,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black54,
          tabs: _statusFilters.map((status) => Tab(text: status)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFB703),
        foregroundColor: Colors.black87,
        onPressed: () {
          // Refresh by rebuilding the widget
          setState(() {});
        },
        child: const Icon(Icons.refresh),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    "Error loading orders",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Try Again"),
                  ),
                ],
              ),
            );
          }
          
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB703)),
              ),
            );
          }

          // Filter orders based on selected tab
          final allDocs = snapshot.data!.docs.where((d) {
            final s = d['status'];
            return s != 'Terminated' && s != 'PickedUp';
          }).toList();
          
          final docs = _currentFilter == 'All' 
              ? allDocs 
              : allDocs.where((d) => capitalize(d['status'] ?? '') == _currentFilter).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.food_bank_outlined, size: 80, color: Color(0xFFFFB703)),
                  const SizedBox(height: 24),
                  Text(
                    _currentFilter == 'All' 
                        ? "No active orders" 
                        : "No orders with status: $_currentFilter",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "All caught up! The kitchen is quiet for now.",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data()! as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EnhancedOrderCard(
                  key: ValueKey(doc.id),
                  orderId: doc.id,
                  data: data,
                  onUpdate: updateOrderStatus,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class EnhancedOrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Future<void> Function(String, String) onUpdate;

  const EnhancedOrderCard({
    Key? key,
    required this.orderId,
    required this.data,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<EnhancedOrderCard> createState() => _EnhancedOrderCardState();
}

class _EnhancedOrderCardState extends State<EnhancedOrderCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  Timestamp? _lastPickedTs;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _maybeStartTimer(widget.data);
  }

  @override
  void didUpdateWidget(covariant EnhancedOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTs = widget.data['pickedUpTime'] as Timestamp?;
    if (widget.data['status'] == 'Pick Up' && newTs != null && newTs != _lastPickedTs) {
      _maybeStartTimer(widget.data);
    }
  }

  void _maybeStartTimer(Map<String, dynamic> data) {
    _timer?.cancel();
    final status = data['status'];
    final ts = data['pickedUpTime'] as Timestamp?;
    if (status == 'Pick Up' && ts != null && mounted) {
      _lastPickedTs = ts;
      final expiry = ts.toDate().add(const Duration(minutes: 5));
      _remaining = expiry.difference(DateTime.now());
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          final diff = expiry.difference(DateTime.now());
          setState(() => _remaining = diff);
          if (diff.isNegative) {
            _timer?.cancel();
          }
        } else {
          _timer?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Get appropriate color for order status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Placed':
        return Colors.blue;
      case 'Cooking':
        return Colors.orange;
      case 'Cooked':
        return const Color(0xFFFFB703);  // Using yellow for cooked
      case 'Pick Up':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = capitalize(widget.data['status'] ?? '');
    final shortId = widget.orderId.substring(0, 6);
    
    // Handle items properly - they come as JSON object from Firestore
    final itemsData = widget.data['items'];
    List<Map<String, dynamic>> parsedItems = [];
    int totalItems = 0;
    
    if (itemsData != null) {
      try {
        if (itemsData is Map<String, dynamic>) {
          // Handle the map format: {"itemName": quantity}
          itemsData.forEach((key, value) {
            parsedItems.add({
              'name': key,
              'quantity': int.tryParse(value.toString()) ?? 1,
              'price': 0.0, // Default price if not available
            });
            totalItems += int.tryParse(value.toString()) ?? 1;
          });
        } else if (itemsData is String) {
          // Handle string format like "quantity: 1, price: 1.0, subtotal: 1.0, name: dosa"
          final parts = itemsData.split(',');
          Map<String, String> itemInfo = {};
          
          for (String part in parts) {
            final keyValue = part.trim().split(':');
            if (keyValue.length == 2) {
              itemInfo[keyValue[0].trim()] = keyValue[1].trim();
            }
          }
          
          parsedItems.add({
            'name': itemInfo['name'] ?? 'Unknown Item',
            'quantity': int.tryParse(itemInfo['quantity'] ?? '1') ?? 1,
            'price': double.tryParse(itemInfo['price'] ?? '0') ?? 0.0,
            'subtotal': double.tryParse(itemInfo['subtotal'] ?? '0') ?? 0.0,
          });
          totalItems = int.tryParse(itemInfo['quantity'] ?? '1') ?? 1;
        } else if (itemsData is List) {
          // Handle list format
          for (var item in itemsData) {
            if (item is Map) {
              parsedItems.add({
                'name': item['name'] ?? 'Unknown Item',
                'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
                'price': double.tryParse(item['price'].toString()) ?? 0.0,
                'subtotal': double.tryParse(item['subtotal'].toString()) ?? 0.0,
              });
              totalItems += int.tryParse(item['quantity'].toString()) ?? 1;
            }
          }
        }
      } catch (e) {
        print('Error parsing items data: $e');
        print('Items data: $itemsData');
      }
    }
    
    final timestamp = widget.data['timestamp'] as Timestamp?;
    final orderTime = timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
        : DateTime.now();
    
    // Format time
    final timeStr = '${orderTime.hour.toString().padLeft(2, '0')}:${orderTime.minute.toString().padLeft(2, '0')}';
    
    Widget timerWidget = const SizedBox();
    if (status == 'Pick Up') {
      if (_remaining.isNegative) {
        timerWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.timer_off, color: Colors.red, size: 10),
              SizedBox(width: 2),
              Text("EXP", 
                style: TextStyle(
                  color: Colors.red, 
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );
      } else {
        final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
        timerWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB703).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, color: Color(0xFFFFB703), size: 10),
              const SizedBox(width: 2),
              Text("$m:$s", 
                style: const TextStyle(
                  color: Color(0xFFFFB703), 
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getStatusColor(status).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Order #$shortId",
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Fixed layout to prevent overflow completely
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items info on its own row
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Items",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          totalItems > 0 
                              ? "$totalItems item${totalItems > 1 ? 's' : ''}"
                              : "No items",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status update section - completely separate to avoid overflow
                  Row(
                    children: [
                      // Status text
                      const Text(
                        "Status: ",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      // Dropdown in container with fixed constraints
                      Expanded(
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: status,
                              icon: const Icon(Icons.keyboard_arrow_down, size: 14),
                              isDense: true,
                              isExpanded: true,
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                              onChanged: (newStatus) {
                                if (newStatus != null && mounted) {
                                  widget.onUpdate(widget.orderId, newStatus);
                                }
                              },
                              items: ['Placed', 'Cooking', 'Cooked', 'Pick Up']
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                          s,
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Timer on separate line when present
                  if (status == 'Pick Up') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          "Timer: ",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        timerWidget,
                      ],
                    ),
                  ],
                ],
              ),
              if (_isExpanded) ...[
                const Divider(height: 24),
                const Text(
                  "Order Details",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (parsedItems.isNotEmpty)
                  ...parsedItems.map((item) {
                    String itemName = item['name'].toString();
                    int quantity = item['quantity'] ?? 1;
                    double price = item['price'] ?? 0.0;
                    double subtotal = item['subtotal'] ?? (price * quantity);
                    
                    // Ensure item name isn't too long
                    if (itemName.length > 20) {
                      itemName = '${itemName.substring(0, 17)}...';
                    }
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item name and quantity
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB703).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.restaurant,
                                  size: 14,
                                  color: Color(0xFFFFB703),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  itemName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB703),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Qty: $quantity',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Price details
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (price > 0) ...[
                                Text(
                                  'Price: ₹${price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Total: ₹${subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFFFB703),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ] else ...[
                                // If no price data, just show quantity info
                                Text(
                                  'Quantity: $quantity',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList()
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 32,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "No items in this order",
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.black54,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.black54,
                  ),
                ),
              ],
            ]
          ),
        ),
      ),
    );
  }
}