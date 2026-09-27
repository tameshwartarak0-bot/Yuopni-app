import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/login_dialog.dart';

bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

void doIfLoggedIn(BuildContext context, Function action) async {
  if (FirebaseAuth.instance.currentUser == null) {
    await showDialog(context: context, builder: (_) => LoginDialog());
    if (FirebaseAuth.instance.currentUser != null) {
      action();
    }
  } else {
    action();
  }
}