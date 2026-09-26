import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';

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
    // Demo ke baad bina login ke direct MainScreen