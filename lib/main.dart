import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'screens/demo_page.dart';
import 'screens/login_page.dart';
import 'screens/main_screen.dart';
// Apna video player screen import karo
// import 'screens/video_detail_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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

    // 1. App band tha aur link se khula
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleLink(initialUri);
      }
    } catch (e) {
      debugPrint("Initial link error: $e");
    }

    // 2. App khula hai aur link aaya
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
        // Yahan apna Video Detail Screen open karo
        // Example:
        /*
        _navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => VideoDetailScreen(videoId: videoId, type: type),
        ));
        */
        
        // Filhal ke liye SnackBar
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
    // Login force nahi, direct Main
    return MainScreen();
  }
}