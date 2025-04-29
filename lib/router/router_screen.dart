import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:todo_spring_2025/home/home_screen.dart';
import 'package:todo_spring_2025/login/login_screen.dart';

class RouterScreen extends StatelessWidget {
  final Function(int) onThemeChanged;

  const RouterScreen({super.key, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          return HomeScreen(onThemeChanged: onThemeChanged);
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}