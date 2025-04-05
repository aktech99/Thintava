
import 'package:canteen_app/screens/admin/admin_home.dart';
import 'package:canteen_app/screens/kitchen/kitchen_home.dart';
import 'package:canteen_app/screens/user/user_home.dart';
import 'package:canteen_app/services/auth_service.dart';
import 'package:flutter/material.dart';

class RoleRouter extends StatelessWidget {
  final String uid;
  const RoleRouter({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return FutureBuilder<String?>(
      future: auth.getUserRole(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Scaffold(body: Center(child: CircularProgressIndicator()));
        switch (snapshot.data) {
          case 'admin':
            return AdminHome();
          case 'kitchen':
            return KitchenHome();
          default:
            return UserHome();
        }
      },
    );
  }
}
