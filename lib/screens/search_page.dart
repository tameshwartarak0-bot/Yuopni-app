import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_view_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String query = "";
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
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
          onChanged: (v) => setState(()=> query = v.trim().toLowerCase()),
        ),
      ),
      body: Column(children: [
        TabBar(controller: _tabCtrl, labelColor: Colors.pink, unselectedLabelColor: Colors.white54, indicatorColor: Colors.pink, tabs: const [Tab(text: "Users"), Tab(text: "Posts"), Tab(text: "Reels")]),
        Expanded(child: TabBarView(controller: _tabCtrl, children: [_buildUsers(), _buildPosts(), _buildReels()])),
      ]),
    );
  }

  Widget _buildUsers() {
    if (query.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search, size: 80, color: Colors.white38), SizedBox(height: 15), Text("Search You", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), Text("Find friends, posts & reels", style: TextStyle(color: Colors.white38))]));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var filtered = snap.data!.docs.where((d){
          var data = d.data() as Map<String, dynamic>;
          String name = (data['username'] ?? data['name'] ?? "").toString().toLowerCase();
          return name.contains(query);
        }).toList();
        if (filtered.isEmpty) return const Center(child: Text("No User Found", style: TextStyle(color: Colors.white54)));
        return ListView.builder(itemCount: filtered.length, itemBuilder: (_, i){
          var data = filtered[i].data() as Map<String, dynamic>;
          String uid = filtered[i].id;
          if (uid == FirebaseAuth.instance.currentUser?.uid) return const SizedBox.shrink();
          String name = data['username'] ?? data['name'] ?? "User";
          String photo = data['photoUrl'] ?? data['photo'] ?? "";
          return ListTile(leading: CircleAvatar(backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, backgroundColor: Colors.grey[800]), title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text(data['email'] ?? "", style: const TextStyle(color: Colors.white54, fontSize: 12)), onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> UserProfileViewPage(userId: uid))));
        });
      },
    );
  }

  Widget _buildPosts() {
    if (query.isEmpty) return const Center(child: Text("Search You - Posts", style: TextStyle(color: Colors.white54)));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').snapshots(),
      builder: (c, snap){
        if(!snap.hasData) return const Center(child: CircularProgressIndicator());
        var filtered = snap.data!.docs.where((d){
          var data = d.data() as Map<String, dynamic>;
          String title = (data['title'] ?? data['title_lower'] ?? "").toString().toLowerCase();
          bool isVideo = data['isVideo'] == true;
          return title.contains(query) && !isVideo;
        }).toList();
        if(filtered.isEmpty) return Center(child: Text("No Posts for '$query'", style: const TextStyle(color: Colors.white54)));
        return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: filtered.length, itemBuilder: (_, i){
          var d = filtered[i].data() as Map<String, dynamic>;
          String thumb = d['thumbnail'] ?? d['mediaUrl'] ?? "";
          return CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, errorWidget: (_,__,___)=> Container(color: Colors.grey[900]));
        });
      },
    );
  }

  Widget _buildReels() {
    if (query.isEmpty) return const Center(child: Text("Search You - Reels", style: TextStyle(color: Colors.white54)));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').snapshots(),
      builder: (c, snap){
        if(!snap.hasData) return const Center(child: CircularProgressIndicator());
        var filtered = snap.data!.docs.where((d){
          var data = d.data() as Map<String, dynamic>;
          String title = (data['title'] ?? data['title_lower'] ?? "").toString().toLowerCase();
          bool isVideo = data['isVideo'] == true || (data['mediaUrl'] ?? "").toString().contains(".mp4");
          return title.contains(query) && isVideo;
        }).toList();
        if(filtered.isEmpty) return Center(child: Text("No Reels for '$query'", style: const TextStyle(color: Colors.white54)));
        return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: filtered.length, itemBuilder: (_, i){
          var d = filtered[i].data() as Map<String, dynamic>;
          String thumb = d['thumbnail'] ?? "";
          String videoUrl = d['mediaUrl'] ?? "";
          String display = thumb.isNotEmpty ? thumb : videoUrl.replaceAll(".mp4", ".jpg").replaceFirst("/video/upload/", "/video/upload/so_0/");
          return Stack(fit: StackFit.expand, children: [CachedNetworkImage(imageUrl: display, fit: BoxFit.cover, errorWidget: (_,__,___)=> Container(color: Colors.black)), const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 30))]);
        });
      },
    );
  }
}