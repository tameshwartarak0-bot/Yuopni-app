import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../global.dart';
import 'home_page.dart';
import 'reel_page.dart';
import 'message_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import '../widgets/create_sheet.dart';
import 'search_page.dart';
import 'notification_page.dart';

ValueNotifier<bool> pauseReelsNotifier = ValueNotifier(false);

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  DateTime? _lastBackPress;

  bool get _isLoggedIn => fb_auth.FirebaseAuth.instance.currentUser != null;

  void _onTap(int i) {
    // 1 = Create
    if (i == 1) {
      if (!_isLoggedIn) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
        return;
      }
      pauseReelsNotifier.value = true;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.black,
        builder: (_) => CreateSheet()
      ).whenComplete(() {
        // FINAL FIX: Sirf Reel page pe ho tabhi resume karo
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          // Agar Camera/Upload khula toh current nahi hoga, toh pause hi rehne do
          if (ModalRoute.of(context)?.isCurrent == true) {
            if (_index == 1) {
              pauseReelsNotifier.value = false; // Sirf Reel pe ho toh bajao
            } else {
              pauseReelsNotifier.value = true; // Home/Message/Profile pe ho toh band rakho
            }
          }
        });
      });
      return;
    }

    // 3 = Message
    if (i == 3 && !_isLoggedIn) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }

    // FIX: Sirf Reel index (1) pe false, baaki sab pe true
    pauseReelsNotifier.value = (i != 2);
    setState(() => _index = i > 1 ? i - 1 : i);
  }

  Future<bool> _onWillPop() async {
    if (_index != 0) {
      setState(() => _index = 0);
      pauseReelsNotifier.value = true; // Home pe aaye toh Reel band
      return false;
    }
    if (_lastBackPress == null || DateTime.now().difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = DateTime.now();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Dubara back dabao app band karne ke liye"),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.white24,
        ),
      );
      return false;
    }
    return true;
  }

  Widget _buildProfileTab() {
    return StreamBuilder<fb_auth.User?>(
      stream: fb_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (fb_auth.FirebaseAuth.instance.currentUser != null) {
            return ProfilePage();
          }
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return ProfilePage();
        }
        if (fb_auth.FirebaseAuth.instance.currentUser != null) {
          return ProfilePage();
        }
        return const LoginPage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(),
      ReelPage(),
      MessagePage(),
      _buildProfileTab(),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text("Yuopni", style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchPage()))),
            IconButton(icon: const Icon(Icons.notifications), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationPage()))),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index == 0 ? 0 : _index + 1,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: "Create"),
            BottomNavigationBarItem(icon: Icon(Icons.video_library), label: "Reel"),
            BottomNavigationBarItem(icon: Icon(Icons.message), label: "Message"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }
}