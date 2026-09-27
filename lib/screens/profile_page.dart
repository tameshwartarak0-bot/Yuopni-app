import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/login_dialog.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          SizedBox(height: 10),
          Text("Login karke apna profile dekho"),
          SizedBox(height: 10),
          ElevatedButton(onPressed: () => showDialog(context: context, builder: (_) => LoginDialog()), child: Text("Login"))
        ]),
      );
    }

    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircleAvatar(radius: 50, backgroundImage: user.photoURL!= null? NetworkImage(user.photoURL!) : null),
        SizedBox(height: 10),
        Text(user.displayName?? "User", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(user.email?? ""),
        SizedBox(height: 20),
        ElevatedButton(onPressed: () async { await FirebaseAuth.instance.signOut(); }, child: Text("Logout"))
      ]),
    );
  }
}