import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- NAYA
import 'screens/demo_page.dart';
import 'screens/login_page.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // SUPABASE INIT - TUMHARA NAYA
  await Supabase.initialize(
    url: 'https://aynsnbgulloedotmjlcq.supabase.co',
    anonKey: 'sb_publishable_nFfjqpnLm5FUZD7GbVXlYw_X3vkM_sj',
  );

  final prefs = await SharedPreferences.getInstance();
  bool seenDemo = prefs.getBool('seenDemo') ?? false;
  User? firebaseUser = FirebaseAuth.instance.currentUser;
  runApp(YuopniApp(seenDemo: seenDemo, isLoggedIn: firebaseUser != null));
}

class YuopniApp extends StatefulWidget {
  final bool seenDemo;
  final bool isLoggedIn;
  YuopniApp({required this.seenDemo, required this.isLoggedIn});

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
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleLink(initialUri);
      }
    } catch (e) {
      debugPrint("Initial link error: $e");
    }
    _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    }, onError: (e) {
      debugPrint("Link stream error: $e");
    });
  }

  void _handleLink(Uri uri) {
    debugPrint("Yuopni Link Aaya: $uri");
    if (uri.host.contains("yuopni.com") && uri.path.contains("/video")) {
      String? videoId = uri.queryParameters['id'];
      String? type = uri.queryParameters['type'] ?? 'long_videos';
      if (videoId != null && _navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
          SnackBar(content: Text("Video khul raha hai: $videoId")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Yuopni',
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: _getStartPage(),
    );
  }

  Widget _getStartPage() {
    if (!widget.seenDemo) return DemoPage();
    return MainScreen();
  }
}