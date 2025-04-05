import 'dart:async';
import 'package:canteen_app/screens/kitchen/kitchen_home.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

// Import your other screen files.
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/user/menu_screen.dart';
import 'screens/user/cart_screen.dart';
import 'screens/user/order_tracking_screen.dart';
import 'package:canteen_app/screens/admin/admin_home.dart';
import 'package:canteen_app/screens/admin/menu_management_screen.dart';
import 'package:canteen_app/screens/kitchen/kitchen_dashboard.dart';
import 'package:canteen_app/screens/user/order_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Platform-specific Firebase initialization.
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCPsu2kuSKa9KezLhZNJWUF4B_n5kMqo4g",
        authDomain: "thintava-ee4f4.firebaseapp.com",
        projectId: "thintava-ee4f4",
        storageBucket: "thintava-ee4f4.firebasestorage.app",
        messagingSenderId: "626390741302",
        appId: "1:626390741302:ios:0579424d3bba31c12ec397",
        measurementId: "",
      ),
    );
    // On web, set persistence.
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } else {
    await Firebase.initializeApp();
    // On mobile, persistence is automatic.
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thintava',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF4CAF50),
          secondary: const Color(0xFFFF9800),
          tertiary: const Color(0xFF2196F3),
          background: const Color(0xFFF5F5F5),
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: const BorderSide(
              color: Color(0xFF4CAF50),
              width: 1.5,
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 8,
          shadowColor: Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF4CAF50),
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/auth': (_) => const AuthMenu(),
        '/menu': (_) => const MenuScreen(),
        '/cart': (context) {
          final cart = ModalRoute.of(context)!.settings.arguments as Map<String, int>;
          return CartScreen(cart: cart);
        },
        '/track': (_) => const OrderTrackingScreen(),
        '/kitchen': (_) => const KitchenDashboard(),
        '/kitchen-menu': (_) => const KitchenHome(),
        '/admin/menu': (_) => const MenuManagementScreen(),
        '/admin/home': (_) => const AdminHome(),
        '/history': (_) => const OrderHistoryScreen(),
      },
    );
  }
}

/// SPLASH SCREEN WITH ROLE-BASED ROUTING
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  
  @override
  _SplashScreenState createState() => _SplashScreenState();
}
 
class _SplashScreenState extends State<SplashScreen> {
  late final StreamSubscription<User?> _authSubscription;
  
  @override
  void initState() {
    super.initState();
    // Listen to auth changes.
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      Future.delayed(const Duration(seconds: 2), () async {
        if (mounted) {
          if (user != null) {
            // If logged in, fetch the user's role from Firestore.
            DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            String role = userDoc.exists ? (userDoc.data()?['role'] ?? 'user') : 'user';
            
            // Route based on role.
            if (role == 'admin') {
              Navigator.pushReplacementNamed(context, '/admin/home');
            } else if (role == 'kitchen') {
              Navigator.pushReplacementNamed(context, '/kitchen-menu');
            } else {
              Navigator.pushReplacementNamed(context, '/menu');
            }
          } else {
            Navigator.pushReplacementNamed(context, '/auth');
          }
        }
      });
    });
  }
  
  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Show a splash UI while waiting for auth state.
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.5),
            radius: 1.0,
            colors: [Color(0xFF4CAF50), Colors.black87],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.restaurant_menu,
                  size: 70,
                  color: Color(0xFF4CAF50),
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                "Getting things ready...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AUTH MENU (Login/Register Options)
class AuthMenu extends StatelessWidget {
  const AuthMenu({super.key});
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
  
    return Scaffold(
      body: Stack(
        children: [
          // Curved header background.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: ClipPath(
              clipper: CurvedClipper(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          // App content with animations.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  FadeInWidget(
                    delay: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              )
                            ],
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 36,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Thintava',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInWidget(
                    delay: 300,
                    child: Text(
                      'Delicious food at your fingertips',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Animated card with login/register options.
                  FadeInWidget(
                    delay: 600,
                    child: Card(
                      elevation: 12,
                      shadowColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                        child: Column(
                          children: [
                            Text(
                              'Welcome Back',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to continue',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) => const LoginScreen(),
                                      transitionDuration: const Duration(milliseconds: 300),
                                      transitionsBuilder: (_, animation, __, child) {
                                        return SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(1, 0),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                                child: Text(
                                  "Login",
                                  style: GoogleFonts.poppins(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) => const RegisterScreen(),
                                      transitionDuration: const Duration(milliseconds: 300),
                                      transitionsBuilder: (_, animation, __, child) {
                                        return SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(1, 0),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                                child: Text(
                                  "Register",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  FadeInWidget(
                    delay: 800,
                    child: Text(
                      'Version 1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// MENU SCREEN (Home for logged-in users)
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

  Future<bool> _onWillPop() async {
    // Show confirmation dialog on back press.
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to exit the app?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final menuStream =
        FirebaseFirestore.instance.collection('menuItems').snapshots();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          // Optionally, if MenuScreen is the root, you might not need a back button.
          // Here, a custom back button is provided that shows an exit confirmation.
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: "Back",
            onPressed: () async {
              if (await _onWillPop()) {
                // Optionally exit the app (e.g., using SystemNavigator.pop())
              }
            },
          ),
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
              colors: [
                Color.fromARGB(255, 255, 255, 255),
                Color.fromARGB(255, 255, 255, 255)
              ],
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

/// CUSTOM CLIPPER FOR CURVED HEADER DESIGN
class CurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    // Start from top left.
    path.lineTo(0, size.height - 60);
    // Create a smooth curve.
    var firstControlPoint = Offset(size.width / 2, size.height);
    var firstEndPoint = Offset(size.width, size.height - 60);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);
    path.lineTo(size.width, 0);
    // Close the path.
    path.close();
    return path;
  }
  
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// FADE IN WIDGET FOR ANIMATIONS
class FadeInWidget extends StatelessWidget {
  final Widget child;
  final int delay;
  const FadeInWidget({Key? key, required this.child, this.delay = 0})
      : super(key: key);
      
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      // Optionally, you can uncomment the delay:
      // delay: Duration(milliseconds: delay),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
