import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'screens/demo_page.dart';
import 'screens/main_screen.dart';
import 'screens/login_page.dart'; // Tumhara login page ka naam

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: 'https://aynsnbgulloedotmjlcq.supabase.co',
    anonKey: 'sb_publishable_nFfjqpnLm5FUZD7GbVXlYw_X3vkM_sj',
  );
  final prefs = await SharedPreferences.getInstance();
  bool seenDemo = prefs.getBool('seenDemo') ?? false;
  
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
  void initState() { super.initState(); _initDeepLinks(); }
  
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleLink(uri);
    } catch (_) {}
    _appLinks.uriLinkStream.listen((uri) => _handleLink(uri));
  }
  
  void _handleLink(Uri uri) {
    if (uri.host.contains("yuopni.com") && uri.path.contains("/video")) {
      String? videoId = uri.queryParameters['id'];
      if (videoId != null && _navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(SnackBar(content: Text("Video: $videoId")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      // FIX: Auth ko live suno, ek baar check nahi
      home: !widget.seenDemo 
        ? DemoPage() 
        : StreamBuilder<fb_auth.User?>(
            stream: fb_auth.FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.white)));
              }
              // Agar user login hai to MainScreen, nahi to LoginPage
              if (snapshot.hasData && snapshot.data != null) {
                return MainScreen();
              } else {
                return LoginPage(); // Ya tumhara Auth page
              }
            },
          ),
    );
  }
}