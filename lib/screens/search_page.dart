import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_profile_view_page.dart';
import '../reel_page.dart'; // tera reel play page

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchCtrl = TextEditingController();
  String query = "";

  Widget _buildThumb(Map<String, dynamic> data){
    String thumb = (data['thumbnail'] ?? '').toString();
    String media = (data['mediaUrl'] ?? data['videoUrl'] ?? '').toString();
    bool isVideo = data['isVideo'] == true || media.contains('.mp4') || media.contains('video');
    String display = thumb;
    if(display.isEmpty && isVideo && media.contains('cloudinary')){
      display = media.replaceAll('.mp4', '.jpg').replaceFirst('/video/upload/', '/video/upload/so_0,w_400,h_700,c_fill/');
    }
    if(display.isEmpty) display = media;

    return Stack(fit: StackFit.expand, children: [
      display.isNotEmpty ? CachedNetworkImage(imageUrl: display, fit: BoxFit.cover, errorWidget: (_,__,___)=> Container(color: Colors.black)) : Container(color: Colors.black),
      if(isVideo) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36)),
      if(isVideo) Positioned(bottom: 4, left: 4, child: Row(children: [const Icon(Icons.visibility, color: Colors.white, size: 12), const SizedBox(width: 2), Text("${data['views'] ?? data['views_count'] ?? 0}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=> Navigator.pop(context)),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Search You", hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
          onChanged: (v)=> setState(()=> query = v.trim().toLowerCase()),
        ),
      ),
      body: query.isEmpty ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search, size: 70, color: Colors.white24), SizedBox(height: 10), Text("Search You", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), Text("Search ID, Post, Reel", style: TextStyle(color: Colors.white54))])) :
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('posts').snapshots(),
        builder: (c, postSnap){
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (c2, userSnap){
              if(!postSnap.hasData || !userSnap.hasData) return const Center(child: CircularProgressIndicator());

              var users = userSnap.data!.docs.where((d){
                var data = d.data() as Map<String, dynamic>;
                String name = (data['username'] ?? data['name'] ?? "").toString().toLowerCase();
                if(d.id == FirebaseAuth.instance.currentUser?.uid) return false;
                return name.contains(query);
              }).toList();

              var posts = postSnap.data!.docs.where((d){
                var data = d.data() as Map<String, dynamic>;
                String title = (data['title'] ?? data['title_lower'] ?? data['description'] ?? "").toString().toLowerCase();
                String uname = (data['username'] ?? "").toString().toLowerCase();
                return title.contains(query) || uname.contains(query);
              }).toList();

              if(users.isEmpty && posts.isEmpty) return Center(child: Text("No result for '$query'", style: const TextStyle(color: Colors.white54)));

              return ListView(
                children: [
                  if(users.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.all(10), child: Text("Users", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                    ...users.map((u){
                      var data = u.data() as Map<String, dynamic>;
                      String name = data['username'] ?? data['name'] ?? "User";
                      String photo = data['photoUrl'] ?? data['photo'] ?? "";
                      return ListTile(leading: CircleAvatar(backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null), title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> UserProfileViewPage(userId: u.id))));
                    }),
                    const Divider(color: Colors.white12),
                  ],
                  if(posts.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.all(10), child: Text("Posts & Reels", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                    GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: posts.length, itemBuilder: (_, i){
                      var d = posts[i].data() as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: (){
                          // Reel wahi play ho jayega
                          Navigator.push(context, MaterialPageRoute(builder: (_)=> ReelPage(initialIndex: i, myReels: posts)));
                        },
                        child: _buildThumb(d),
                      );
                    }),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}