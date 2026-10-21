import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'user_profile_view_page.dart';

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
    String display = thumb.isNotEmpty ? thumb : media;
    if(display.isEmpty) display = media;
    // Cloudinary ke purane video ke liye thumb banao
    if(thumb.isEmpty && isVideo && media.contains('cloudinary')){
      display = media.replaceAll('.mp4', '.jpg').replaceFirst('/video/upload/', '/video/upload/so_0,w_400,h_700,c_fill/');
    }
    return Stack(fit: StackFit.expand, children: [
      display.isNotEmpty ? CachedNetworkImage(imageUrl: display, fit: BoxFit.cover, errorWidget: (_,__,___)=> Container(color: Colors.black)) : Container(color: Colors.black),
      if(isVideo) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36)),
      if(isVideo) Positioned(bottom: 4, left: 4, child: Row(children: [const Icon(Icons.visibility, color: Colors.white, size: 12), const SizedBox(width: 2), Text("${data['views'] ?? 0}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))])),
    ]);
  }

  void _openVideo(String videoUrl) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayPage(videoUrl: videoUrl)));
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
      body: query.isEmpty ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search, size: 70, color: Colors.white24), SizedBox(height: 10), Text("Search You", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)), Text("Search ID, Post, Reel", style: TextStyle(color: Colors.white54))])) :
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
              return ListView(children: [
                if(users.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.all(10), child: Text("Users", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                  ...users.map((u){
                    var data = u.data() as Map<String, dynamic>;
                    String name = data['username'] ?? data['name'] ?? "User";
                    String photo = data['photoUrl'] ?? data['photo'] ?? "";
                    return ListTile(leading: CircleAvatar(backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, backgroundColor: Colors.grey[800]), title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> UserProfileViewPage(userId: u.id))));
                  }),
                  const Divider(color: Colors.white12),
                ],
                if(posts.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.all(10), child: Text("Posts & Reels", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
                  GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: posts.length, itemBuilder: (_, i){
                    var d = posts[i].data() as Map<String, dynamic>;
                    String videoUrl = (d['mediaUrl'] ?? d['videoUrl'] ?? "").toString();
                    bool isVideo = d['isVideo'] == true || videoUrl.contains('.mp4');
                    return GestureDetector(onTap: (){ if(isVideo && videoUrl.isNotEmpty) _openVideo(videoUrl); }, child: _buildThumb(d));
                  }),
                ],
              ]);
            },
          );
        },
      ),
    );
  }
}

class VideoPlayPage extends StatefulWidget {
  final String videoUrl;
  const VideoPlayPage({super.key, required this.videoUrl});
  @override State<VideoPlayPage> createState() => _VideoPlayPageState();
}
class _VideoPlayPageState extends State<VideoPlayPage> {
  late VideoPlayerController _ctrl;
  @override void initState(){ super.initState(); _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))..initialize().then((_){ setState((){}); _ctrl.play(); _ctrl.setLooping(true); }); }
  @override void dispose(){ _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)), body: Center(child: _ctrl.value.isInitialized ? AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl)) : const CircularProgressIndicator(color: Colors.white)));
  }
}