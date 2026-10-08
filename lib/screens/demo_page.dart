import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_screen.dart';
import 'login_page.dart'; // FIX: screens/ hataya

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});
  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final PageController _controller = PageController();
  int _current = 0;

  final List<Map<String, String>> demos = [
    {"title": "Yuopni me Swagat Hai", "desc": "India ka apna Short Video App - Desi content, desi style", "icon": "🔥"},
    {"title": "Reel Banao, Viral Jao", "desc": "Trending songs ke sath 15 sec me banao mast reels", "icon": "🎵"},
    {"title": "100% Secure & Safe", "desc": "Tumhara data Firestore me fully safe rahega", "icon": "🔒"},
  ];

  Future<void> _finishDemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenDemo', true);
    if (!mounted) return;

    // CHANGE: Login ho ya na ho, hamesha MainScreen khulega - bina login ke bhi demo chalega
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainScreen()),
      (route) => false
    );
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
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _current = i),
              itemCount: demos.length,
              itemBuilder: (_, i) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(demos[i]['icon']!, style: const TextStyle(fontSize: 90)),
                      const SizedBox(height: 30),
                      Text(
                        demos[i]['title']!,
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center
                      ),
                      const SizedBox(height: 15),
                      Text(
                        demos[i]['desc']!,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center
                      ),
                    ]
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.all(4),
              width: _current == i? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _current == i? Colors.pink : Colors.white24,
                borderRadius: BorderRadius.circular(10)
              )
            ))
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(children: [
              TextButton(
                onPressed: _finishDemo,
                child: const Text("Skip", style: TextStyle(color: Colors.white, fontSize: 16))
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (_current == 2) {
                    _finishDemo();
                  } else {
                    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                ),
                child: Text(_current == 2? "Start" : "Next", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}