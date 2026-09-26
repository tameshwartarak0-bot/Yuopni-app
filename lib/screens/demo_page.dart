import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart'; // <-- CHANGE 1: yaha login_page ki jagah main_screen

class DemoPage extends StatefulWidget {
  @override
  _DemoPageState createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  PageController _controller = PageController();
  int _current = 0;

  List<Map<String, String>> demos = [
    {"title": "Yuopni me Swagat Hai", "desc": "India ka apna Short Video App", "icon": "🔥"},
    {"title": "Reel Banao Viral Jao", "desc": "Full songs ke sath reel banao", "icon": "🎵"},
    {"title": "100% Secure", "desc": "Tumhara data safe rahega", "icon": "🔒"},
  ];

  void _finishDemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenDemo', true);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainScreen())); // <-- CHANGE 2: LoginPage ki jagah MainScreen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        Expanded(child: PageView.builder(
          controller: _controller,
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: demos.length,
          itemBuilder: (_, i) => Center(child: Padding(padding: EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(demos[i]['icon']!, style: TextStyle(fontSize: 80)),
            SizedBox(height: 20),
            Text(demos[i]['title']!, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            SizedBox(height: 15),
            Text(demos[i]['desc']!, style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
          ]))),
        )),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) => Container(margin: EdgeInsets.all(4), width: _current==i? 20:8, height: 8, decoration: BoxDecoration(color: _current==i? Colors.pink: Colors.white24, borderRadius: BorderRadius.circular(10))))),
        Padding(padding: EdgeInsets.all(20), child: Row(children: [
          TextButton(onPressed: _finishDemo, child: Text("Skip")),
          Spacer(),
          ElevatedButton(onPressed: (){ if(_current==2) _finishDemo(); else _controller.nextPage(duration: Duration(milliseconds: 300), curve: Curves.ease); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.pink), child: Text(_current==2? "Start": "Next")),
        ])),
      ]),
    );
  }
}