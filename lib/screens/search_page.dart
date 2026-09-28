import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _ctrl = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      setState(() => _query = _ctrl.text.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Reel, Video, Song, ID search karo...",
              border: InputBorder.none,
              suffixIcon: _query.isNotEmpty? IconButton(icon: Icon(Icons.clear), onPressed: ()=> _ctrl.clear()) : null,
            ),
          ),
          bottom: TabBar(tabs: [
            Tab(text: "Users"),
            Tab(text: "Posts"),
            Tab(text: "Reels"),
          ]),
        ),
        body: _query.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.search, size: 60, color: Colors.grey),
              SizedBox(height: 10),
              Text("Search me sab aayega - Reel, Video, Song, User ID", style: TextStyle(color: Colors.grey)),
            ]))
            : TabBarView(
                children: [
                  // USERS TAB
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').orderBy('username_search').startAt([_query]).endAt([_query + '\uf8ff']).limit(15).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return Center(child: CircularProgressIndicator());
                      if (snap.data!.docs.isEmpty) return Center(child: Text("Koi user nahi mila"));
                      return ListView.builder(
                        itemCount: snap.data!.docs.length,
                        itemBuilder: (_, i) {
                          var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(backgroundImage: (d['photoURL']??'').toString().isNotEmpty? NetworkImage(d['photoURL']) : null, child: (d['photoURL']??'').toString().isEmpty? Icon(Icons.person): null),
                            title: Text(d['username']?? d['displayName']?? 'User'),
                            subtitle: Text(d['email']?? ''),
                          );
                        },
                      );
                    },
                  ),
                  // POSTS TAB
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('posts').where('title', isGreaterThanOrEqualTo: _query).where('title', isLessThan: _query + 'z').limit(15).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return Center(child: CircularProgressIndicator());
                      if (snap.data!.docs.isEmpty) return Center(child: Text("Koi post nahi mila"));
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                        itemCount: snap.data!.docs.length,
                        itemBuilder: (_, i) {
                          var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                          String url = (d['mediaUrl']?? d['imageUrl']?? '').toString();
                          return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_,__,___)=> Icon(Icons.broken_image));
                        },
                      );
                    },
                  ),
                  // REELS TAB
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('reels').where('title', isGreaterThanOrEqualTo: _query).where('title', isLessThan: _query + 'z').limit(15).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return Center(child: CircularProgressIndicator());
                      if (snap.data!.docs.isEmpty) return Center(child: Text("Koi reel nahi mili"));
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                        itemCount: snap.data!.docs.length,
                        itemBuilder: (_, i) {
                          var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                          String url = (d['mediaUrl']?? d['videoUrl']?? '').toString();
                          return Stack(fit: StackFit.expand, children: [
                            CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                            Center(child: Icon(Icons.play_circle_fill, color: Colors.white70)),
                          ]);
                        },
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}