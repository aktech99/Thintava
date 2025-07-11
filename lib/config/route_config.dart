import 'package:flutter/material.dart';
import 'package:canteen_app/screens/auth/auth_menu.dart';
import 'package:canteen_app/screens/auth/phone_input_screen.dart';
import 'package:canteen_app/screens/auth/otp_verification_screen.dart';
import 'package:canteen_app/screens/user/menu_screen.dart';
import 'package:canteen_app/screens/user/cart_screen.dart';
import 'package:canteen_app/screens/user/order_tracking_screen.dart';
import 'package:canteen_app/screens/user/order_history_screen.dart';
import 'package:canteen_app/screens/user/user_home.dart';
import 'package:canteen_app/screens/admin/admin_home.dart';
import 'package:canteen_app/screens/admin/menu_management_screen.dart';
import 'package:canteen_app/screens/admin/admin_order_history_screen.dart';
import 'package:canteen_app/screens/admin/admin_kitchen_view_screen.dart';
import 'package:canteen_app/screens/admin/admin_live_orders.dart';
import 'package:canteen_app/screens/kitchen/kitchen_dashboard.dart';
import 'package:canteen_app/screens/kitchen/kitchen_home.dart';
import 'package:canteen_app/screens/splash/splash_screen.dart';

class RouteConfig {
  static Map<String, WidgetBuilder> get routes {
    return {
      '/auth': (_) => const AuthMenu(),
      '/phone-input': (_) => const PhoneInputScreen(),
      '/phone-login': (_) => const PhoneInputScreen(isLogin: true),
      '/phone-register': (_) => const PhoneInputScreen(isLogin: false),
      '/menu': (_) => const MenuScreen(),
      '/cart': (_) => const CartScreen(),
      '/splash': (context) => const SplashScreen(),
      '/track': (_) => const OrderTrackingScreen(),
      '/kitchen': (_) => const KitchenDashboard(),
      '/kitchen-menu': (_) => const KitchenHome(),
      '/kitchen-dashboard': (_) => const KitchenDashboard(),
      '/admin/menu': (_) => const MenuManagementScreen(),
      '/admin/home': (_) => const AdminHome(),
      '/admin/live-orders': (_) => const AdminLiveOrdersScreen(),
      '/history': (_) => const OrderHistoryScreen(),
      '/admin/admin-history': (_) => const AdminOrderHistoryScreen(),
      '/admin/admin-kitchen-view': (_) => const AdminKitchenViewScreen(),
      '/user/user-home': (_) => const UserHome(),
    };
  }
}