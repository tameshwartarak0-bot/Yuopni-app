import 'package:flutter/material.dart';
import '../global.dart';
import 'home_page.dart';
import 'reel_page.dart';
import 'message_page.dart';
import 'profile_page.dart';
import '../widgets/create_sheet.dart';
import 'search_page.dart';
import 'notification_page.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  DateTime? _lastBackPress; // Double back ke liye
  final pages = [HomePage(), ReelPage(), MessagePage(), ProfilePage()];

  void _onTap(int i) {
    if (i == 1) {
      showModalBottomSheet(context: context, backgroundColor: Colors.black, builder: (_) => CreateSheet());
      return;
    }
    setState(() => _index = i > 1 ? i - 1 : i);
  }

  // Yahi logic back button ko control karega
  Future<bool> _onWillPop() async {
    // 1. Agar Home par nahi ho, to pehle Home par lao, app band mat karo
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }

    // 2. Agar Home par ho to Double Back Press se band hoga
    if (_lastBackPress == null || DateTime.now().difference(_lastBackPress!) > Duration(seconds: 2)) {
      _lastBackPress = DateTime.now();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Dubara back dabao app band karne ke liye"),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.white24,
        ),
      );
      return false; // App band nahi hoga
    }
    return true; // Ab app band hoga
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope se back button ka control milta hai
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Yuopni", style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchPage()))),
            IconButton(icon: Icon(Icons.notifications), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationPage()))),
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
          items: [
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