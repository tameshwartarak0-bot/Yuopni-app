import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/demo_page.dart';
import 'screens/main_screen.dart';
import 'screens/reel_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: 'https://aynsnbgulloedotmjlcq.supabase.co',
    anonKey: 'sb_publishable_nFfjqpnLm5FUZD7GbVXlYw_X3vkM_sj',
  );
  // Prefs ko pehle se load karke rakho - Instagram yahi karta hai
  final prefs = await SharedPreferences.getInstance();
  runApp(YuopniApp(prefs: prefs));
}

class YuopniApp extends StatefulWidget {
  final SharedPreferences prefs;
  const YuopniApp({super.key, required this.prefs});
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
    await Future.delayed(const Duration(milliseconds: 800));
    if (_navigatorKey.currentState == null) return;
    try {
      var doc = await FirebaseFirestore.instance.collection('posts').doc(videoId).get();
      if (!doc.exists || doc.data() == null) return;
      _navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => ReelPage(myReels: [doc], initialIndex: 0)),
      );
    } catch (e) {
      debugPrint("DeepLink error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool seenDemo = widget.prefs.getBool('seenDemo') ?? false;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: StreamBuilder<fb_auth.User?>(
        stream: fb_auth.FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {
          // Sirf ek hi loading, double loading khatam
          if (authSnap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          }

          // 1. Login hai toh seedha MainScreen - Recent clear se bhi farak nahi
          if (authSnap.hasData && authSnap.data != null) {
            return MainScreen();
          }

          // 2. Login nahi hai toh prefs se direct decision - bina FutureBuilder ke
          if (seenDemo) {
            return MainScreen(); // Guest mode
          }
          return const DemoPage();
        },
      ),
    );
  }
}