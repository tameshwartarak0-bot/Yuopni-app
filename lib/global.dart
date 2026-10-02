import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/login_dialog.dart';

// Home pe % dikhane ke liye - UploadPage + HomePage dono yahi use karenge
ValueNotifier<double> globalUploadProgress = ValueNotifier(0);
ValueNotifier<bool> isUploadingGlobal = ValueNotifier(false);

bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

Future<void> doIfLoggedIn(BuildContext context, Function action) async {
  if (FirebaseAuth.instance.currentUser == null) {
    await showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const LoginDialog()
    );
    // Dialog ke baad check
    if (FirebaseAuth.instance.currentUser != null) {
      if (context.mounted) {
        action();
      }
    }
  } else {
    action();
  }
}