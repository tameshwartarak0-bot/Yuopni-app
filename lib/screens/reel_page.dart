import 'package:flutter/material.dart';
import '../global.dart';

class ReelPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PageView.builder(itemCount: 5, scrollDirection: Axis.vertical, itemBuilder: (_, i) {
      return Stack(children: [
        Container(color: Colors.primaries[i % Colors.primaries.length], child: Center(child: Text("Demo Reel ${i+1}\nBina Login Dekho", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)))),
        Positioned(left: 10, bottom: 30, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("@user_${i+1}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          Text("Original Song - Demo Audio 🎵", style: TextStyle(color: Colors.white70)),
        ])),
        Positioned(right: 10, bottom: 100, child: Column(children: [
          IconButton(icon: Icon(Icons.favorite, size: 35, color: Colors.white), onPressed: () {
            doIfLoggedIn(context, () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Liked Reel ${i+1}!")));
            });
          }),
          Text("12.5k", style: TextStyle(color: Colors.white)), SizedBox(height: 15),
          IconButton(icon: Icon(Icons.comment, size: 35, color: Colors.white), onPressed: () {
            doIfLoggedIn(context, () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Comment karo!")));
            });
          }),
          Text("500", style: TextStyle(color: Colors.white)), SizedBox(height: 15),
          IconButton(icon: Icon(Icons.bookmark, size: 35, color: Colors.white), onPressed: () {
            doIfLoggedIn(context, () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved!")));
            });
          }),
          Text("Save", style: TextStyle(color: Colors.white)), SizedBox(height: 15),
          IconButton(icon: Icon(Icons.person_add, size: 35, color: Colors.white), onPressed: () {
            doIfLoggedIn(context, () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Followed!")));
            });
          }),
          Text("Follow", style: TextStyle(color: Colors.white)), SizedBox(height: 15),
          IconButton(icon: Icon(Icons.share, size: 35, color: Colors.white), onPressed: () {
            // Share par login nahi - sab kar sakte hain
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Share kiya!")));
          }),
          Text("Share", style: TextStyle(color: Colors.white)),
        ]))
      ]);
    });
  }
}