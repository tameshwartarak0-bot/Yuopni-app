import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    var myUid = FirebaseAuth.instance.currentUser!.uid;
    // User data
    var userSnap = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    // Check friend
    var follow = await Supabase.instance.client.from('follows').select().eq('follower_uid', myUid).eq('following_uid', widget.userId).maybeSingle();
    // Friends count of this user
    var friends = await Supabase.instance.client.from('follows').select().eq('follower_uid', widget.userId);
    var posts = await FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: widget.userId).get();

    setState(() {
      userData = userSnap.data();
      isFriend = follow != null;
      friendsCount = (friends as List).length;
      postsCount = posts.docs.length;
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    String name = userData?['username'] ?? userData?['name'] ?? "User";
    String photo = userData?['photoUrl'] ?? userData?['photo'] ?? "";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(name, style: const TextStyle(color: Colors.white)), iconTheme: const IconThemeData(color: Colors.white)),
      body: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(radius: 45, backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, backgroundColor: Colors.orange, child: photo.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 35, color: Colors.white)) : null),
          const SizedBox(height: 10),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Column(children: [Text("$postsCount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Text("Posts", style: TextStyle(color: Colors.grey))]),
            const SizedBox(width: 25),
            GestureDetector(onTap: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name ke $friendsCount Friends"))); }, child: Column(children: [Text("$friendsCount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Text("Friends", style: TextStyle(color: Colors.grey))])),
          ]),
          const SizedBox(height: 15),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton.icon(onPressed: _toggleFriend, icon: Icon(isFriend ? Icons.check : Icons.person_add), label: Text(isFriend ? "Friends" : "Add Friend"), style: ElevatedButton.styleFrom(backgroundColor: isFriend ? Colors.grey[300] : Colors.black, foregroundColor: isFriend ? Colors.black : Colors.white)),
            const SizedBox(width: 10),
            if (isFriend) // Message ka option sirf friend banne ke baad
              ElevatedButton.icon(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Message Page Jaldi Ayega"))); }, icon: const Icon(Icons.message), label: const Text("Message"), style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white)),
          ]),
          const SizedBox(height: 15),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: widget.userId).snapshots(),
              builder: (c, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                if (snap.data!.docs.isEmpty) return const Center(child: Text("No Posts Yet"));
                return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: snap.data!.docs.length, itemBuilder: (_, i) {
                  var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                  String thumb = d['thumbnail'] ?? d['mediaUrl'] ?? "";
                  return CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.black, child: const Icon(Icons.play_circle, color: Colors.white)));
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}