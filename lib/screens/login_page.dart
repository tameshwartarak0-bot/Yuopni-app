import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // FIX: Yahan Web Client ID add kiya hai - Isse Error 10 fix hoga
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: "628684774390-ie7v92pseos2fgh4j2temlg7flrckia1.apps.googleusercontent.com",
  );

  Future<void> _loginWithGmail() async {
    setState(() => _loading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) { setState(() => _loading = false); return; }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCred = await _auth.signInWithCredential(credential);
      final User? user = userCred.user;

      if (user != null) {
        // Firestore me data save - Kabhi delete nahi hoga
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'name': user.displayName,
          'photo': user.photoURL,
          'lastLogin': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('seenDemo', true);
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userEmail', user.email ?? "");

        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainScreen()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Error: $e")));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Padding(padding: EdgeInsets.all(25), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.play_circle_fill, size: 100, color: Colors.pink),
        SizedBox(height: 20),
        Text("Yuopni", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
        Text("Real Gmail Login - Firebase Secure", style: TextStyle(color: Colors.grey)),
        SizedBox(height: 50),
        _loading? CircularProgressIndicator(): SizedBox(width: double.infinity, child: ElevatedButton.icon(
          icon: Image.network("https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg", height: 20),
          label: Text("Continue with Gmail", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          onPressed: _loginWithGmail,
        )),
        SizedBox(height: 20),
        Text("Tumhara data Firestore me safe rahega\nApp band karne par bhi delete nahi hoga", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]))),
    );
  }
}