import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_screen.dart';
import 'login_page.dart';

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});
  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final PageController _controller = PageController();
  int _current = 0;

  final List<Map<String, String>> demos = [
    {"title": "Yuopni me Swagat Hai", "desc": "India ka apna Short Video App", "icon": "🔥"},
    {"title": "Reel Banao Viral Jao", "desc": "Full songs ke sath reel banao", "icon": "🎵"},
    {"title": "100% Secure", "desc": "Tumhara data Firestore me safe rahega", "icon": "🔒"},
  ];

  Future<void> _finishDemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenDemo', true);
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user!= null) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MainScreen()), (route) => false);
    } else {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginPage()), (route) => false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: demos.length,
            itemBuilder: (_, i) => Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(demos[i]['icon']!, style: const TextStyle(fontSize: 80)),
                  const SizedBox(height: 20),
                  Text(demos[i]['title']!, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 15),
                  Text(demos[i]['desc']!, style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
                ]),
              ),
            ),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) => Container(margin: const EdgeInsets.all(4), width: _current == i? 20 : 8, height: 8, decoration: BoxDecoration(color: _current == i? Colors.pink : Colors.white24, borderRadius: BorderRadius.circular(10))))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            TextButton(onPressed: _finishDemo, child: const Text("Skip", style: TextStyle(color: Colors.white))),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                if (_current == 2) {
                  _finishDemo();
                } else {
                  _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
              child: Text(_current == 2? "Start" : "Next"),
            ),
          ]),
        ),
      ]),
    );
  }
}