import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'demo_page.dart';
import 'phone_login_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: "628684774390-ie7v92pseos2fgh4j2temlg7flrckia1.apps.googleusercontent.com",
  );

  Future<void> _loginWithGmail() async {
    setState(() => _loading = true);
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCred = await _auth.signInWithCredential(credential);
      final User? user = userCred.user;
      if (user!= null) {
        var snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        bool hasUsername = false;
        if(snap.exists){
          var data = snap.data() as Map<String,dynamic>?;
          if(data!= null && data['username']!= null && data['username'].toString().isNotEmpty){
            hasUsername = true;
          }
        }

        if (!snap.exists ||!hasUsername) {
          if(mounted){
            setState(() => _loading = false);
            _showUsernameDialog(user);
            return;
          }
        } else {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'email': user.email,
            'name': (snap.data() as Map)['username'], // edited naam hi name rahega
            'googleName': user.displayName,
            'photo': user.photoURL,
            'photoURL': user.photoURL,
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('seenDemo', true);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Error: $e"), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _loading = false);
  }

  // 2nd PHOTO JAISA POPUP - ID SET KARNE KA
  void _showUsernameDialog(User user) {
    TextEditingController usernameCtrl = TextEditingController(text: user.displayName?? "");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flutter logo jaisa icon
              Icon(Icons.flutter_dash, size: 60, color: Colors.blue),
              SizedBox(height: 15),
              Text("Choose your ID", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500)),
              SizedBox(height: 8),
              Text("to continue to yuopni", style: TextStyle(color: Colors.white70, fontSize: 14)),
              SizedBox(height: 25),
              // Input field Google account list jaisa
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  controller: usernameCtrl,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Apna naam / ID likho",
                    hintStyle: TextStyle(color: Colors.white38),
                    icon: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.deepOrange,
                      backgroundImage: user.photoURL!=null? NetworkImage(user.photoURL!): null,
                      child: user.photoURL==null? Text(user.displayName?[0]??"T", style: TextStyle(color: Colors.white)): null,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Divider(color: Colors.white24),
              SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                  onPressed: () async {
                    String newUsername = usernameCtrl.text.trim();
                    if (newUsername.length < 3) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ID 3 akshar se bada rakho")));
                      return;
                    }
                    String usernameLower = newUsername.toLowerCase().replaceAll(" ", "_");

                    var check = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: usernameLower).get();
                    if (check.docs.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ye ID pehle se hai"), backgroundColor: Colors.red));
                      return;
                    }

                    List<String> searchKeys = [];
                    for(int i=1; i<=newUsername.length; i++) searchKeys.add(newUsername.substring(0,i).toLowerCase());
                    for(int i=1; i<=usernameLower.length; i++) searchKeys.add(usernameLower.substring(0,i));

                    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                      'uid': user.uid,
                      'email': user.email,
                      'name': newUsername, // YAHI TAMESHWAR TARAK KI JAGAH SHOW HOGA
                      'username': usernameLower,
                      'displayName': newUsername,
                      'googleName': user.displayName,
                      'username_search': usernameLower,
                      'searchKeys': searchKeys,
                      'photo': user.photoURL,
                      'photoURL': user.photoURL,
                      'createdAt': FieldValue.serverTimestamp(),
                      'lastLogin': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('seenDemo', true);
                    if(mounted) Navigator.pop(context);
                  },
                  child: Text("Continue", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              SizedBox(height: 15),
              Text("Ye naam hi profile me Tameshwar Tarak ki jagah dikhega", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resetDemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenDemo', false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DemoPage()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_fill, size: 100, color: Colors.pink),
              const SizedBox(height: 20),
              const Text("Yuopni", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text("Real Gmail + Mobile Login - Firebase Secure", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 50),
              _loading? const CircularProgressIndicator(color: Colors.pink)
              : Column(children: [
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: Image.network("https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg", height: 20), label: const Text("Continue with Gmail", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), onPressed: _loginWithGmail)),
                  const SizedBox(height: 15),
                  const Row(children: [Expanded(child: Divider(color: Colors.white24)), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("OR", style: TextStyle(color: Colors.grey))), Expanded(child: Divider(color: Colors.white24))]),
                  const SizedBox(height: 15),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.phone_android, color: Colors.white), label: const Text("Continue with Mobile Number", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: const BorderSide(color: Colors.white), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneLoginPage())))),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}