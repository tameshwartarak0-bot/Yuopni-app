import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      // FIX 1: Naya account banane ke liye pehle logout karo - isse account chooser ayega
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

      if (user != null) {
        // FIX 2: createdAt ko kabhi overwrite mat karo
        DocumentReference userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        var snap = await userDoc.get();
        
        if (!snap.exists) {
          await userDoc.set({
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName,
            'photo': user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } else {
          await userDoc.set({
            'email': user.email,
            'name': user.displayName,
            'photo': user.photoURL,
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('seenDemo', true);
        await prefs.setString('userEmail', user.email ?? "");
        await prefs.setString('userName', user.displayName ?? "");
        await prefs.setString('userPhoto', user.photoURL ?? "");
        
        // FIX 3: Yahan Navigator push mat karo - main.dart ka StreamBuilder khud MainScreen pe le jayega
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
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
              const Text("Real Gmail Login - Firebase Secure", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 50),
              _loading
                  ? const CircularProgressIndicator(color: Colors.pink)
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Image.network(
                          "https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg",
                          height: 20,
                        ),
                        label: const Text("Continue with Gmail", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _loginWithGmail,
                      ),
                    ),
              const SizedBox(height: 20),
              const Text(
                "Tumhara data Firestore me safe rahega\nApp band karne par bhi delete nahi hoga",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}