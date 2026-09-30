import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/login_dialog.dart';
import 'reel_page.dart';

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

    // Duplicate na ho
    savedAccounts.removeWhere((a) => a['uid'] == user.uid);
    savedAccounts.add(acc);

    await prefs.setString('yuopni_saved_accounts', jsonEncode(savedAccounts));
  }

  Future<void> _logout() async {
    await _saveCurrentAccount();
    await FirebaseAuth.instance.signOut();
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
            const Text("Switch Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            // Current User
            ListTile(
              leading: CircleAvatar(backgroundImage: FirebaseAuth.instance.currentUser?.photoURL!= null? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!) : null),
              title: Text(FirebaseAuth.instance.currentUser?.displayName?? "Current User"),
              subtitle: Text(FirebaseAuth.instance.currentUser?.email?? ""),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
            const Divider(),
            // Saved Accounts
           ...savedAccounts.where((a) => a['uid']!= FirebaseAuth.instance.currentUser?.uid).map((acc) => ListTile(
              leading: acc['photo']!= ""? CircleAvatar(backgroundImage: NetworkImage(acc['photo'])) : CircleAvatar(child: Text(acc['name'][0])),
              title: Text(acc['name']),
              subtitle: Text(acc['email']),
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${acc['name']} ke liye dobara login karo")));
                await FirebaseAuth.instance.signOut();
                if (mounted) showDialog(context: context, builder: (_) => const LoginDialog());
              },
            )),
            const SizedBox(height: 10),
            // Add Account Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Add / Login Another Account"),
                onPressed: () async {
                  Navigator.pop(context);
                  await _saveCurrentAccount();
                  await FirebaseAuth.instance.signOut();
                  if (mounted) showDialog(context: context, builder: (_) => const LoginDialog());
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Logout", style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  Navigator.pop(context);
                  await _logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 10),
          const Text("Login karke apna profile dekho"),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: () => showDialog(context: context, builder: (_) => const LoginDialog()), child: const Text("Login"))
        ]),
      );
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
            Text(user.displayName?? "Yuopni User", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(user.email?? "", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(onPressed: _switchAccountDialog, child: const Text("Switch Account")),
              const SizedBox(width: 10),
              ElevatedButton(onPressed: _logout, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text("Logout")),
            ]),
            const SizedBox(height: 5),
            Text("${savedAccounts.length} account saved", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            const TabBar(labelColor: Colors.black, tabs: [Tab(icon: Icon(Icons.grid_on), text: "Posts"), Tab(icon: Icon(Icons.video_library), text: "Reels")]),
            Expanded(
              child: TabBarView(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: user.uid).orderBy('timestamp', descending: true).limit(30).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      if (snap.data!.docs.isEmpty) return const Center(child: Text("Abhi koi Post nahi"));
                      return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: snap.data!.docs.length, itemBuilder: (_, i) {
                        var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                        String url = (d['mediaUrl']?? d['imageUrl']?? '').toString();
                        return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, placeholder: (_, __) => Container(color: Colors.black12), errorWidget: (_, __, ___) => const Icon(Icons.broken_image));
                      });
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('reels').where('uid', isEqualTo: user.uid).orderBy('timestamp', descending: true).limit(30).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      if (snap.data!.docs.isEmpty) return const Center(child: Text("Abhi koi Reel nahi"));
                      var reels = snap.data!.docs;
                      return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: reels.length, itemBuilder: (_, i) {
                        var d = reels[i].data() as Map<String, dynamic>;
                        String thumb = (d['thumbnail']?? '').toString();
                        bool isImageThumb = thumb.startsWith('http') &&!thumb.contains('.mp4');
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReelPage(initialIndex: i, myReels: reels))),
                          child: Stack(fit: StackFit.expand, children: [
                            isImageThumb? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.black)) : Container(color: Colors.black87, child: const Icon(Icons.videocam, color: Colors.white24, size: 40)),
                            Container(color: Colors.black26),
                            const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30)),
                          ]),
                        );
                      });
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