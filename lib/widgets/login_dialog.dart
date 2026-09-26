import 'package:flutter/material.dart';
import '../global.dart';

class LoginDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Login / Signup Karo"),
      content: Text("Is feature ke liye login zaruri hai."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ElevatedButton(onPressed: () { isLoggedIn = true; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Successful!"))); }, child: Text("Login"))
      ],
    );
  }
}