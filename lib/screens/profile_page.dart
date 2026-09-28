import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            SizedBox(height: 40),
            CircleAvatar(radius: 45, backgroundImage: user.photoURL!= null? NetworkImage(user.photoURL!) : null, child: user.photoURL == null? Icon(Icons.person, size: 45) : null),
            SizedBox(height: 10),
            Text(user.displayName?? "Yuopni User", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(user.email?? "", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(onPressed: () {}, child: Text("Edit Profile")),
              SizedBox(width: 10),
              ElevatedButton(onPressed: () async { await FirebaseAuth.instance.signOut(); }, child: Text("Logout"), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent)),
            ]),
            SizedBox(height: 10),
            TabBar(tabs: [Tab(icon: Icon(Icons.grid_on), text: "Posts"), Tab(icon: Icon(Icons.video_library), text: "Reels")]),
            Expanded(
              child: TabBarView(
                children: [
                  // POSTS TAB - FAST
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: user.uid).orderBy('createdAt', descending: true).limit(30).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return Center(child: CircularProgressIndicator());
                      if (snap.data!.docs.isEmpty) return Center(child: Text("Abhi koi Post nahi"));
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                        itemCount: snap.data!.docs.length,
                        itemBuilder: (_, i) {
                          var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                          String url = (d['mediaUrl']?? d['imageUrl']?? '').toString();
                          return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, placeholder: (_,__)=> Container(color: Colors.black12), errorWidget: (_,__,___)=> Icon(Icons.broken_image));
                        },
                      );
                    },
                  ),
                  // REELS TAB - FAST
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('reels').where('uid', isEqualTo: user.uid).orderBy('createdAt', descending: true).limit(30).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return Center(child: CircularProgressIndicator());
                      if (snap.data!.docs.isEmpty) return Center(child: Text("Abhi koi Reel nahi"));
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                        itemCount: snap.data!.docs.length,
                        itemBuilder: (_, i) {
                          var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                          String url = (d['mediaUrl']?? d['videoUrl']?? '').toString();
                          return Stack(fit: StackFit.expand, children: [
                            CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_,__,___)=> Container(color: Colors.black)),
                            Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30)),
                          ]);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}