import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../global.dart';
import '../widgets/login_dialog.dart';

class ReelPage extends StatelessWidget {
  
  void checkLogin(BuildContext context, Function action) {
    if (FirebaseAuth.instance.currentUser == null && !isLoggedIn) {
      showDialog(context: context, builder: (_) => LoginDialog());
    } else {
      action();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(itemCount: 5, scrollDirection: Axis.vertical, itemBuilder: (_, i) {
      return Stack(children: [
        Container(color: Colors.primaries[i % Colors.primaries.length], child: Center(child: Text("Demo Reel ${i+1}\nBina Login Dekho", textAlign: TextAlign.center, style: TextStyle(fontSize: 20)))),
        Positioned(left: 10, bottom: 30, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("@user_${i+1}", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("Original Song - Demo Audio 🎵"),
        ])),
        Positioned(right: 10, bottom: 100, child: Column(children: [
          IconButton(icon: Icon(Icons.favorite, size: 35), onPressed: () {
            checkLogin(context, () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Liked Reel ${i+1}!")));
            });
          }),
          Text("12.5k"), SizedBox(height: 15),
          IconButton(icon: Icon(Icons.comment, size: 35), onPressed: () {
            checkLogin(context, () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Comment karo!")));
            });
          }),
          Text("500"), SizedBox(height: 15),
          IconButton(icon: Icon(Icons.bookmark, size: 35), onPressed: () {
            checkLogin(context, () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved!")));
            });
          }),
          Text("Save"), SizedBox(height: 15),
          IconButton(icon: Icon(Icons.person_add, size: 35), onPressed: () {
            checkLogin(context, () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Followed!")));
            });
          }),
          Text("Follow"), SizedBox(height: 15),
          IconButton(icon: Icon(Icons.share, size: 35), onPressed: () {
            // Share par login nahi - sab kar sakte hain
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Share kiya!")));
          }),
          Text("Share"),
        ]))
      ]);
    });
  }
}