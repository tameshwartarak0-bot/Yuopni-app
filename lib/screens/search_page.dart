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
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: TextField(
            controller: _ctrl,
            autofocus: true,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "ID, Reel, Video search karo...",
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
              suffixIcon: _query.isNotEmpty? IconButton(icon: Icon(Icons.clear, color: Colors.white), onPressed: ()=> _ctrl.clear()) : null,
            ),
          ),
          bottom: TabBar(
            indicatorColor: Colors.pink,
            labelColor: Colors.pink,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: "Users"),
              Tab(text: "Posts"),
              Tab(text: "Reels"),
            ]),
        ),
        body: _query.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.search, size: 60, color: Colors.grey),
              SizedBox(height: 10),
              Text("Search me ID se user ayega - Jo ID login me banayi hai", style: TextStyle(color: Colors.grey)),
            ]))
            : TabBarView(
                children: [
                  // USERS TAB - Ab username se 100% ayega
                  StreamBuilder<QuerySnapshot>(
                    stream: _query.length < 1
                    ? null
                      : FirebaseFirestore.instance.collection('users').where('searchKeys', arrayContains: _query).limit(20).snapshots(),
                    builder: (c, snap) {
                      if (_query.length < 1) return Center(child: Text("1 akshar likho", style: TextStyle(color: Colors.white)));
                      if (!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
                      if (snap.data!.docs.isEmpty) {
                        // Fallback 1: username_search se
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').orderBy('username_search').startAt([_query]).endAt([_query + '\uf8ff']).limit(20).snapshots(),
                          builder: (c2, snap2){
                            if (!snap2.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
                            if (snap2.data!.docs.isEmpty) {
                              // Fallback 2: direct username se
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('users').where('username_search', isGreaterThanOrEqualTo: _query).where('username_search', isLessThan: _query + 'z').limit(20).snapshots(),
                                builder: (c3, snap3){
                                  if (!snap3.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
                                  if (snap3.data!.docs.isEmpty) return Center(child: Text("Koi user nahi mila: $_query", style: TextStyle(color: Colors.white)));
                                  return _buildUserList(snap3.data!.docs);
                                }
                              );
                            }
                            return _buildUserList(snap2.data!.docs);
                          }
                        );
                      }
                      return _buildUserList(snap.data!.docs);
                    },
                  ),
                  // POSTS TAB
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('posts').where('title_search', isGreaterThanOrEqualTo: _query).where('title_search', isLessThan: _query + '\uf8ff').limit(15).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
                      if (snap.data!.docs.isEmpty) return Center(child: Text("Koi post nahi mila", style: TextStyle(color: Colors.white)));
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                        itemCount: snap.data!.docs.length,
                        itemBuilder: (_, i) {
                          var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                          String url = (d['thumbnail']?? d['mediaUrl']?? d['imageUrl']?? '').toString();
                          return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 300, errorWidget: (_,__,___)=> Icon(Icons.broken_image, color: Colors.white));
                        },
                      );
                    },
                  ),
                  // REELS TAB
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('reels').where('title_search', isGreaterThanOrEqualTo: _query).where('title_search', isLessThan: _query + '\uf8ff').limit(15).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
                      if (snap.data!.docs.isEmpty) return Center(child: Text("Koi reel nahi mili", style: TextStyle(color: Colors.white)));
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                        itemCount: snap.data!.docs.length,
                        itemBuilder: (_, i) {
                          var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                          String url = (d['thumbnail']?? d['mediaUrl']?? d['videoUrl']?? '').toString();
                          return Stack(fit: StackFit.expand, children: [
                            CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 300),
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

  Widget _buildUserList(List<QueryDocumentSnapshot> docs){
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (_, i) {
        var d = docs[i].data() as Map<String, dynamic>;
        String photo = (d['photo']?? d['photoURL']?? '').toString();
        String username = (d['username']?? d['name']?? 'User').toString();
        String email = (d['email']?? '').toString();
        String googleName = (d['googleName']?? d['name']?? '').toString();

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.white10,
            backgroundImage: photo.isNotEmpty? NetworkImage(photo) : null,
            child: photo.isEmpty? Icon(Icons.person, color: Colors.white): null
          ),
          title: Text(username, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(googleName + " • " + email, style: TextStyle(color: Colors.white54, fontSize: 12)),
          onTap: (){
            // Yaha profile page pe le ja sakta hai
          },
        );
      },
    );
  }
}