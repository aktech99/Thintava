import 'package:flutter/material.dart';
import 'package:canteen_app/screens/auth/auth_menu.dart';
import 'package:canteen_app/screens/auth/login_screen.dart';
import 'package:canteen_app/screens/auth/register_screen.dart';
import 'package:canteen_app/screens/auth/phone_input_screen.dart';
import 'package:canteen_app/screens/user/user_home.dart';
import 'package:canteen_app/screens/user/menu_screen.dart';
import 'package:canteen_app/screens/user/cart_screen.dart';
import 'package:canteen_app/screens/user/order_tracking_screen.dart';
import 'package:canteen_app/screens/user/order_history_screen.dart';
import 'package:canteen_app/screens/user/profile_screen.dart';
import 'package:canteen_app/screens/admin/admin_home.dart';
import 'package:canteen_app/screens/admin/menu_management_screen.dart';
import 'package:canteen_app/screens/admin/admin_order_history_screen.dart';
import 'package:canteen_app/screens/admin/admin_live_orders_screen.dart';
import 'package:canteen_app/screens/admin/admin_session_management.dart';
import 'package:canteen_app/screens/admin/admin_kitchen_view_screen.dart';
import 'package:canteen_app/screens/kitchen/kitchen_home.dart';
import 'package:canteen_app/screens/kitchen/kitchen_dashboard.dart';
import 'package:canteen_app/screens/role_router.dart';

Map<String, Widget Function(BuildContext)> routes = {
  '/': (context) => const RoleRouter(),
  '/auth': (context) => const AuthMenu(),
  '/login': (context) => const LoginScreen(),
  '/register': (context) => const RegisterScreen(),
  '/phone': (context) => const PhoneInputScreen(),
  '/user/user-home': (context) => const UserHome(),
  '/admin/home': (context) => const AdminHome(),
  '/kitchen-menu': (context) => const KitchenHome(),
  '/menu': (context) => const MenuScreen(),
  '/cart': (context) => const CartScreen(),
  '/track': (context) => const OrderTrackingScreen(),
  '/history': (context) => const OrderHistoryScreen(),
  '/profile': (context) => const ProfileScreen(),
  '/admin/menu': (context) => const MenuManagementScreen(),
  '/admin/orders': (context) => const AdminOrderHistoryScreen(),
  '/admin/live': (context) => const AdminLiveOrdersScreen(),
  '/admin/sessions': (context) => const AdminSessionManagement(),
  '/admin/kitchen': (context) => const AdminKitchenViewScreen(),
  '/kitchen': (context) => const KitchenHome(),
  '/kitchen/dashboard': (context) => const KitchenDashboard(),
};