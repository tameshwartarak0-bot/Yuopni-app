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

// GLOBAL - Reel ko pause karne ke liye
ValueNotifier<bool> pauseReelsNotifier = ValueNotifier(false);

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  DateTime? _lastBackPress;

  bool _checkLogin() {
    if (fb_auth.FirebaseAuth.instance.currentUser == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return false;
    }
    return true;
  }

  void _onTap(int i) {
    // 1 = Create button (beech wala)
    if (i == 1) {
      if (!_checkLogin()) return;
      pauseReelsNotifier.value = true;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.black,
        builder: (_) => CreateSheet()
      ).whenComplete(() {
        pauseReelsNotifier.value = false;
      });
      return;
    }

    // 3 = Message (i=3) -> login jaruri
    if (i == 3) {
      if (!_checkLogin()) return;
    }

    // 4 = Profile (i=4) -> login check nahi karna, _buildProfileTab khud handle karega
    // Isse double login khulne ka bug khatam

    pauseReelsNotifier.value = (i != 2);
    setState(() => _index = i > 1 ? i - 1 : i);
  }

  Future<bool> _onWillPop() async {
    if (_index != 0) {
      setState(() => _index = 0);
      pauseReelsNotifier.value = true;
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
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return ProfilePage();
        }
        // Guest hai to LoginPage dikhao (push nahi, direct yahi dikhega)
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
        body: pages[_index],
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