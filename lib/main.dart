import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'screens/demo_page.dart';
import 'screens/main_screen.dart';
import 'screens/login_page.dart';
import 'screens/reel_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: 'https://aynsnbgulloedotmjlcq.supabase.co',
    anonKey: 'sb_publishable_nFfjqpnLm5FUZD7GbVXlYw_X3vkM_sj',
  );
  final prefs = await SharedPreferences.getInstance();
  bool seenDemo = prefs.getBool('seenDemo')?? false;
  runApp(YuopniApp(seenDemo: seenDemo));
}

class YuopniApp extends StatefulWidget {
  final bool seenDemo;
  const YuopniApp({required this.seenDemo, super.key});
  @override
  State<YuopniApp> createState() => _YuopniAppState();
}

class _YuopniAppState extends State<YuopniApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri!= null) _handleLink(uri);
    } catch (_) {}
    _appLinks.uriLinkStream.listen((uri) => _handleLink(uri));
  }

  void _handleLink(Uri uri) async {
    bool isOurLink = uri.host.contains("yuopni-1c5e9") || uri.scheme == "yuopni";
    if (!isOurLink) return;
    String? videoId = uri.queryParameters['id']?.trim();
    if (videoId == null || videoId.isEmpty) return;
    for (int i = 0; i < 20; i++) {
      if (_navigatorKey.currentState!= null) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    try {
      var doc = await FirebaseFirestore.instance.collection('posts').doc(videoId).get();
      if (!doc.exists || doc.data() == null) return;
      if (_navigatorKey.currentState!= null) {
        _navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => ReelPage(myReels: [doc], initialIndex: 0)));
      }
    } catch (e) {
      debugPrint("DeepLink error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      // AB LOGIN CHECK YAHAN SE HATA DIYA
      home: Builder(builder: (context) {
        if (!widget.seenDemo) {
          return const DemoPage();
        }
        // Chahe user login ho ya na ho, sidha MainScreen khulega
        return MainScreen();
      }),
    );
  }
}