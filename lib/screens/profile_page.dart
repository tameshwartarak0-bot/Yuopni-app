import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../widgets/login_dialog.dart';
import 'reel_page.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Map<String, dynamic>> savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('yuopni_saved_accounts');
    if (data!= null) {
      setState(() {
        savedAccounts = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
    }
  }

  Future<void> _saveCurrentAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> acc = {
      'uid': user.uid,
      'name': user.displayName?? "User",
      'email': user.email?? "",
      'photo': user.photoURL?? "",
    };
    savedAccounts.removeWhere((a) => a['uid'] == user.uid);
    savedAccounts.add(acc);
    await prefs.setString('yuopni_saved_accounts', jsonEncode(savedAccounts));
  }

  Future<void> _logout() async {
    await _saveCurrentAccount();
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    await prefs.remove('userPhoto');
    await prefs.remove('isLoggedIn');
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
    }
  }

  Future<void> _deletePost(String postId, Map<String, dynamic> data) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Delete kare?", style: TextStyle(color: Colors.black)),
        content: const Text("Ye post hamesha ke liye delete ho jayegi.", style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm!= true) return;
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      if (data['videoPath']!= null && data['videoPath'].toString().isNotEmpty) {
        try {
          await Supabase.instance.client.storage.from('videos').remove([data['videoPath']]);
        } catch (_) {}
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post delete ho gayi")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _switchAccountDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 15),
            const Text("Switch Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
            const SizedBox(height: 10),
            ListTile(
              leading: CircleAvatar(backgroundImage: FirebaseAuth.instance.currentUser?.photoURL!= null? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!) : null),
              title: Text(FirebaseAuth.instance.currentUser?.displayName?? "Current User", style: const TextStyle(color: Colors.black)),
              subtitle: Text(FirebaseAuth.instance.currentUser?.email?? ""),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
            const Divider(),
           ...savedAccounts.where((a) => a['uid']!= FirebaseAuth.instance.currentUser?.uid).map((acc) => ListTile(
                  leading: acc['photo']!= ""? CircleAvatar(backgroundImage: NetworkImage(acc['photo'])) : CircleAvatar(child: Text(acc['name'][0])),
                  title: Text(acc['name'], style: const TextStyle(color: Colors.black)),
                  subtitle: Text(acc['email']),
                  onTap: () async { Navigator.pop(context); await _logout(); },
                )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text("Add / Login Another Account"), onPressed: () async { Navigator.pop(context); await _saveCurrentAccount(); await _logout(); })),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Logout", style: TextStyle(color: Colors.white)), onPressed: () async { Navigator.pop(context); await _logout(); })),
          ],
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _sortDocs(List<QueryDocumentSnapshot> docs) {
    docs.sort((a, b) {
      var da = (a.data() as Map<String, dynamic>);
      var db = (b.data() as Map<String, dynamic>);
      Timestamp? ta = da['createdAt'] is Timestamp? da['createdAt'] : da['timestamp'] is Timestamp? da['timestamp'] : null;
      Timestamp? tb = db['createdAt'] is Timestamp? db['createdAt'] : db['timestamp'] is Timestamp? db['timestamp'] : null;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return docs;
  }

  // VIDEO AUR IMAGE DONO VISIBLE
  Widget _buildMedia(String url) {
    bool isVideoFile = url.toLowerCase().contains('.mp4');
    if (url.isEmpty) {
      return Container(color: Colors.grey[300], child: const Center(child: Icon(Icons.videocam, color: Colors.black54, size: 28)));
    }
    if (isVideoFile) {
      return Container(
        color: Colors.black,
        child: Stack(fit: StackFit.expand, children: [
          Container(color: Colors.grey[900]),
          const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36)),
        ]),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey[300], child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))),
      errorWidget: (_, __, ___) => Container(color: Colors.grey[900], child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 30))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)), const SizedBox(height: 10), const Text("Login karke apna profile dekho", style: TextStyle(color: Colors.black)), const SizedBox(height: 10), ElevatedButton(onPressed: () => showDialog(context: context, builder: (_) => const LoginDialog()), child: const Text("Login"))]));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            const SizedBox(height: 40),
            Stack(children: [
              CircleAvatar(radius: 45, backgroundColor: Colors.deepOrange, backgroundImage: user.photoURL!= null? NetworkImage(user.photoURL!) : null, child: user.photoURL == null? Text((user.displayName?? "T")[0].toUpperCase(), style: const TextStyle(fontSize: 30, color: Colors.white)) : null),
              Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: _switchAccountDialog, child: const CircleAvatar(radius: 12, backgroundColor: Colors.black, child: Icon(Icons.switch_account, size: 14, color: Colors.white))))
            ]),
            const SizedBox(height: 10),
            Text(user.displayName?? "Yuopni User", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            Text(user.email?? "", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [ElevatedButton(onPressed: _switchAccountDialog, child: const Text("Switch Account")), const SizedBox(width: 10), ElevatedButton(onPressed: _logout, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), child: const Text("Logout"))]),
            const SizedBox(height: 5),
            Text("${savedAccounts.length} account saved", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            const TabBar(labelColor: Colors.black, unselectedLabelColor: Colors.grey, indicatorColor: Colors.black, indicatorWeight: 3, tabs: [Tab(icon: Icon(Icons.grid_on), text: "Posts"), Tab(icon: Icon(Icons.video_library), text: "Reels")]),
            const Divider(height: 1, color: Colors.black12),
            Expanded(
              child: TabBarView(
                children: [
                  // POSTS TAB
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: user.uid).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));
                      if (snap.data!.docs.isEmpty) return const Center(child: Text("Abhi koi Post nahi", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)));
                      var docs = _sortDocs(snap.data!.docs);
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          var doc = docs[i];
                          var d = doc.data() as Map<String, dynamic>;
                          String url = (d['mediaUrl']?? d['imageUrl']?? d['videoUrl']?? d['thumbnail']?? '').toString();
                          bool isVideo = d['isVideo'] == true || url.toLowerCase().contains('.mp4') || d['videoUrl']!= null;
                          return GestureDetector(
                            onTap: () {
                              if (isVideo) Navigator.push(context, MaterialPageRoute(builder: (_) => ReelPage(initialIndex: i, myReels: docs)));
                            },
                            child: Stack(fit: StackFit.expand, children: [
                              _buildMedia(url),
                              if (isVideo) Container(color: Colors.black26),
                              Positioned(top: 4, right: 4, child: InkWell(onTap: () => _deletePost(doc.id, d), child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: const Icon(Icons.delete, size: 14, color: Colors.white)))),
                            ]),
                          );
                        },
                      );
                    },
                  ),
                  // REELS TAB
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: user.uid).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));
                      var all = _sortDocs(snap.data!.docs);
                      var reels = all.where((doc) { var d = doc.data() as Map<String, dynamic>; var url = (d['mediaUrl']?? d['videoUrl']?? '').toString(); return d['isVideo'] == true || url.toLowerCase().contains('.mp4') || d['videoUrl']!= null; }).toList();
                      if (reels.isEmpty) return const Center(child: Text("Abhi koi Reel nahi", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)));
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                        itemCount: reels.length,
                        itemBuilder: (_, i) {
                          var doc = reels[i];
                          var d = doc.data() as Map<String, dynamic>;
                          String thumb = (d['thumbnail']?? d['mediaUrl']?? d['videoUrl']?? '').toString();
                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReelPage(initialIndex: i, myReels: reels))),
                            child: Stack(fit: StackFit.expand, children: [
                              _buildMedia(thumb),
                              Container(color: Colors.black26),
                              const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32)),
                              Positioned(top: 4, right: 4, child: InkWell(onTap: () => _deletePost(doc.id, d), child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: const Icon(Icons.delete, size: 14, color: Colors.white)))),
                            ]),
                          );
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