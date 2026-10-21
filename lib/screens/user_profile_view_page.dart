import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

class UserProfileViewPage extends StatefulWidget {
  final String userId;
  const UserProfileViewPage({super.key, required this.userId});
  @override State<UserProfileViewPage> createState() => _UserProfileViewPageState();
}

class _UserProfileViewPageState extends State<UserProfileViewPage> {
  Map<String, dynamic>? userData;
  bool isFriend = false;
  bool isLoading = true;
  int friendsCount = 0;
  int postsCount = 0;
  List<QueryDocumentSnapshot> userPostsDocs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    var myUid = FirebaseAuth.instance.currentUser!.uid;
    var userSnap = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    var follow = await Supabase.instance.client.from('follows').select().eq('follower_uid', myUid).eq('following_uid', widget.userId).maybeSingle();
    var friends = await Supabase.instance.client.from('follows').select().eq('follower_uid', widget.userId);
    var postsSnap = await FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: widget.userId).orderBy('createdAt', descending: true).get();

    setState(() {
      userData = userSnap.data();
      isFriend = follow != null;
      friendsCount = (friends as List).length;
      postsCount = postsSnap.docs.length;
      userPostsDocs = postsSnap.docs;
      isLoading = false;
    });
  }

  Future<void> _toggleFriend() async {
    var myUid = FirebaseAuth.instance.currentUser!.uid;
    if (isFriend) {
      await Supabase.instance.client.from('follows').delete().eq('follower_uid', myUid).eq('following_uid', widget.userId);
    } else {
      await Supabase.instance.client.from('follows').insert({'follower_uid': myUid, 'following_uid': widget.userId});
    }
    setState(()=> isFriend = !isFriend);
    _loadData();
  }

  void _showFriendsBottom() async {
    var friendsData = await Supabase.instance.client.from('follows').select().eq('follower_uid', widget.userId);
    if(!mounted) return;
    showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_){
      if ((friendsData as List).isEmpty) return const SizedBox(height: 200, child: Center(child: Text("No Friends Yet")));
      return SizedBox(height: 400, child: Column(children: [const SizedBox(height: 10), Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))), const SizedBox(height: 10), Text("Friends ($friendsCount)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Expanded(child: ListView.builder(itemCount: friendsData.length, itemBuilder: (_, i){
        var f = friendsData[i];
        return ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text("Yuopni User", style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(f['following_uid'].toString().substring(0,6)));
      }))]));
    });
  }

  void _openVideo(String url){
    if(url.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayPage(videoUrl: url)));
  }

  Widget _buildPostItem(QueryDocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String thumb = (data['thumbnail'] ?? '').toString();
    String media = (data['mediaUrl'] ?? data['videoUrl'] ?? '').toString();
    // Thumbnail logic - Supabase wala thumb sabse pehle
    String displayUrl = thumb.isNotEmpty ? thumb : media;
    if(thumb.isEmpty && media.contains('cloudinary')){
      displayUrl = media.replaceAll(".mp4", ".jpg").replaceFirst("/video/upload/", "/video/upload/so_0,w_400,h_700,c_fill/");
    }
    int views = (data['views'] ?? data['views_count'] ?? 0) is int ? (data['views'] ?? 0) : 0;
    bool isVideo = data['isVideo'] == true || media.contains('.mp4');

    return GestureDetector(
      onTap: (){ if(isVideo) _openVideo(media); },
      child: Stack(fit: StackFit.expand, children: [
        displayUrl.isNotEmpty ? CachedNetworkImage(imageUrl: displayUrl, fit: BoxFit.cover, placeholder: (_,__)=> Container(color: Colors.grey[300]), errorWidget: (_,__,___)=> Container(color: Colors.black, child: const Center(child: Icon(Icons.play_arrow, color: Colors.white)))) : Container(color: Colors.black),
        if(isVideo) Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black54, Colors.transparent]))),
        if(isVideo) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 28)),
        if(isVideo) Positioned(bottom: 4, left: 4, child: Row(children: [const Icon(Icons.visibility, color: Colors.white, size: 12), const SizedBox(width: 2), Text("$views", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
    String name = userData?['username'] ?? userData?['name'] ?? "User";
    String photo = userData?['photoUrl'] ?? userData?['photo'] ?? "";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), iconTheme: const IconThemeData(color: Colors.white)),
      body: Column(children: [
        const SizedBox(height: 20),
        CircleAvatar(radius: 50, backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, backgroundColor: Colors.orange),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.5)), // Ubhra hua
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Column(children: [Text("$postsCount", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)), const Text("Posts", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600))]),
          const SizedBox(width: 30),
          GestureDetector(onTap: _showFriendsBottom, child: Column(children: [Text("$friendsCount", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)), const Text("Friends", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600))])),
        ]),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(onPressed: _toggleFriend, icon: Icon(isFriend ? Icons.check : Icons.person_add, size: 18), label: Text(isFriend ? "Friends" : "Add Friend"), style: ElevatedButton.styleFrom(backgroundColor: isFriend ? Colors.grey[300] : Colors.black, foregroundColor: isFriend ? Colors.black : Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)))),
          const SizedBox(width: 12),
          if (isFriend) ElevatedButton.icon(onPressed: (){ /* message_page.dart me navigate kar */ }, icon: const Icon(Icons.message, size: 18), label: const Text("Message"), style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)))),
        ]),
        const SizedBox(height: 15),
        const Divider(height: 1),
        Expanded(child: userPostsDocs.isEmpty ? const Center(child: Text("No Posts Yet", style: TextStyle(color: Colors.grey))) : GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 1, mainAxisSpacing: 1), itemCount: userPostsDocs.length, itemBuilder: (_, i) => _buildPostItem(userPostsDocs[i]))),
      ]),
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