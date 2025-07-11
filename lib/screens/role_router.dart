
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:canteen_app/screens/user/user_home.dart';
import 'package:canteen_app/screens/admin/admin_home.dart';
import 'package:canteen_app/screens/kitchen/kitchen_home.dart';
import 'package:canteen_app/screens/auth/auth_menu.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    return WillPopScope(
      onWillPop: () async {
        // Prevent back button navigation at the root level
        return false;
      },
      child: user == null
        ? const AuthMenu()
        : FutureBuilder<Map<String, dynamic>?>(
            future: authService.getUserData(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final userData = snapshot.data;
              final role = userData?['role'] as String? ?? 'user';

              switch (role) {
                case 'admin':
                  return const AdminHome();
                case 'kitchen':
                  return const KitchenHome();
                case 'user':
                default:
                  return const UserHome();
              }
            },
          ),
    );
  }
}
