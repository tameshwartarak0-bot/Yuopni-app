import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginDialog extends StatelessWidget {
  const LoginDialog({super.key});

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) return;

      String displayName = user.displayName?? googleUser.displayName?? "Yuopni User";
      String email = user.email?? "";

      // SEARCH KE LIYE KEYWORDS BANAO
      List<String> searchKeys = [];
      String lowerName = displayName.toLowerCase();
      searchKeys.add(lowerName); // pura naam
      searchKeys.addAll(lowerName.split(' ')); // pehla naam, dusra naam alag
      if (email.isNotEmpty) {
        searchKeys.add(email.toLowerCase()); // pura email
        searchKeys.add(email.split('@')[0].toLowerCase()); // email ka pehla hissa
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'username': displayName,
        'username_search': lowerName,
        'searchKeys': searchKeys, // YE NAYA HAI - isse search 100% kaam karega
        'email': email,
        'email_search': email.toLowerCase(),
        'photoURL': user.photoURL?? "",
        'userPhoto': user.photoURL?? "",
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Welcome $displayName!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Fail: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Login Karo"),
      content: const Text("Like, Comment, Post, Upload karne ke liye login zaroori hai"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text("Google se Login"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
          onPressed: () => signInWithGoogle(context),
        ),
      ],
    );
  }
}