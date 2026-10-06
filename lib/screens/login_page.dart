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
      if (user != null) {
        DocumentReference userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        var snap = await userDoc.get();
        
        // Check karo username hai ya nahi
        bool hasUsername = false;
        if(snap.exists){
          var data = snap.data() as Map<String,dynamic>?;
          if(data != null && data['username'] != null && data['username'].toString().isNotEmpty){
            hasUsername = true;
          }
        }

        if (!snap.exists || !hasUsername) {
          // Naya user - ID banane ka popup dikhao
          if(mounted){
            setState(() => _loading = false);
            _showUsernameDialog(user, user.displayName ?? "user");
            return;
          }
        } else {
          // Purana user - direct login
          await userDoc.set({
            'email': user.email,
            'name': user.displayName,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  // ID EDIT WALA POPUP
  void _showUsernameDialog(User user, String googleName) {
    TextEditingController usernameCtrl = TextEditingController(
      text: googleName.toLowerCase().replaceAll(" ", "_")
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Apna ID banao ✨", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ye naam search me dikhega, yahi edit kar sakte ho", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 15),
            TextField(
              controller: usernameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.alternate_email, color: Colors.pink),
                hintText: "jaise - rahul_07",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            onPressed: () async {
              String newUsername = usernameCtrl.text.trim().toLowerCase().replaceAll(" ", "_");
              if (newUsername.length < 3) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID 3 akshar se bada rakho")));
                return;
              }
              
              // Check duplicate ID
              var check = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: newUsername).get();
              if (check.docs.isNotEmpty) {
                if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ye ID pehle se hai, dusra try karo"), backgroundColor: Colors.red));
                return;
              }

              // Search ke liye keys banao
              List<String> searchKeys = [];
              for(int i=1; i<=newUsername.length; i++){
                searchKeys.add(newUsername.substring(0,i));
              }
              // google name se bhi
              String gLow = googleName.toLowerCase();
              for(int i=1; i<=gLow.length; i++){
                searchKeys.add(gLow.substring(0,i));
              }

              DocumentReference userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
              await userDoc.set({
                'uid': user.uid,
                'email': user.email,
                'name': googleName,
                'googleName': googleName,
                'username': newUsername,
                'username_search': newUsername.toLowerCase(),
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
            child: const Text("Save & Continue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _resetDemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenDemo', false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DemoPage()),
      (r) => false,
    );
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
              _loading
                  ? const CircularProgressIndicator(color: Colors.pink)
                  : Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Image.network("https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg", height: 20),
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
                      const SizedBox(height: 15),
                      const Row(children: [
                        Expanded(child: Divider(color: Colors.white24)),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("OR", style: TextStyle(color: Colors.grey))),
                        Expanded(child: Divider(color: Colors.white24)),
                      ]),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.phone_android, color: Colors.white),
                          label: const Text("Continue with Mobile Number", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: const BorderSide(color: Colors.white),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneLoginPage()));
                          },
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 20),
              const Text("Tumhara data Firestore me safe rahega\nApp band karne par bhi delete nahi hoga", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 30),
              TextButton(
                onPressed: _resetDemo,
                child: const Text("DEMO", style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2)),
              )
            ],
          ),
        ),
      ),
    );
  }
}