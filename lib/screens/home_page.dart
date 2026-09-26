import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../global.dart';
import '../widgets/login_dialog.dart';

class HomePage extends StatelessWidget {
  final filters = ["All", "For You", "Trending", "Movie", "Song", "Comedy", "Gaming"];

  void checkLogin(BuildContext context, Function action) {
    if (FirebaseAuth.instance.currentUser == null &&!isLoggedIn) {
      showDialog(context: context, builder: (_) => LoginDialog());
    } else {
      action();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 10, itemBuilder: (_, i) => Padding(padding: EdgeInsets.all(8), child: Column(children: [CircleAvatar(radius: 28, backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=${i+1}")), Text("user $i")])))),
        SizedBox(height: 40, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: filters.length, itemBuilder: (_, i) => Container(margin: EdgeInsets.symmetric(horizontal: 5), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), child: Text(filters[i])))),
        Expanded(child: ListView.builder(itemCount: 5, itemBuilder: (_, i) => Card(color: Colors.white10, child: Column(children: [
          ListTile(
            title: Text("Demo Post ${i+1}"),
            subtitle: Text("Reel / Movie / Song - Bina login dekho"),
            trailing: IconButton(icon: Icon(Icons.person_add), onPressed: () {
              checkLogin(context, () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Followed!")));
              });
            })
          ),
          Container(height: 150, color: Colors.black26, child: Center(child: Icon(Icons.play_circle, size: 50))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            IconButton(icon: Icon(Icons.favorite_border), onPressed: () {
              checkLogin(context, () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Liked!")));
              });
            }),
            IconButton(icon: Icon(Icons.comment_outlined), onPressed: () {
              checkLogin(context, () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Comment karo!")));
              });
            }),
            IconButton(icon: Icon(Icons.bookmark_border), onPressed: () {
              checkLogin(context, () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved!")));
              });
            }),
            IconButton(icon: Icon(Icons.share), onPressed: () {
              // Share par login nahi chahiye - sab dekh/share kar sakte hain
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Share kiya!")));
            }),
          ])
        ]))))
      ],
    );
  }
}