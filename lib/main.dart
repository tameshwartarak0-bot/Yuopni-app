import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/demo_page.dart';
import 'screens/login_page.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  // Pehli baar seenDemo false hoga, to DemoPage khulega
  bool seenDemo = false; // Testing ke liye force Demo khol rahe hain
  User? firebaseUser = FirebaseAuth.instance.currentUser;

  runApp(YuopniApp(seenDemo: seenDemo, isLoggedIn: firebaseUser != null));
}

class YuopniApp extends StatelessWidget {
  final bool seenDemo;
  final bool isLoggedIn;
  YuopniApp({required this.seenDemo, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yuopni',
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: _getStartPage(),
    );
  }

  // Yahi logic Demo -> Login -> Home karta hai
  Widget _getStartPage() {
    if (!seenDemo) {
      return DemoPage(); // 1. Pehle Demo
    }
    if (!isLoggedIn) {
      return LoginPage(); // 2. Fir Login
    }
    return MainScreen(); // 3. Fir Home
  }
}
