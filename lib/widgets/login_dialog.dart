import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../global.dart';

class LoginDialog extends StatelessWidget {
  
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // user ne cancel kiya

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Firebase login
      UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if(user == null) return;

      String displayName = user.displayName ?? googleUser.displayName ?? "Yuopni User";
      String email = user.email ?? "";
      
      // FIX: Firestore me user save - jisse Message page me search hoga
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'username': displayName,
        'username_search': displayName.toLowerCase(), // Search ke liye main