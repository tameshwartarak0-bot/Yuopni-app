import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/login_dialog.dart';

bool isLoggedIn = false;

// Guest Mode ka common function - Like/Comment/Follow/Save/Post par login check
void doIfLoggedIn(BuildContext context, Function action) {
  if (FirebaseAuth.instance.currentUser == null && !isLoggedIn) {
    showDialog(context: context, builder: (_) => LoginDialog());
  } else {
    action();
  }
}