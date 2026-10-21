import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'reel_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Map<String, dynamic>> savedAccounts = [];
  String myDisplayName = "";
  String myPhotoUrl = "";
  bool _loading = true;
  bool _uploading = false;
  final ImagePicker _picker = ImagePicker();

  final List<String> avatarUrls = [
    "https://api.dicebear.com/7.x/avataaars/png?seed=1",
    "https://api.dicebear.com/7.x/avataaars/png?seed=2",
    "https://api.dicebear.com/7.x/avataaars/png?seed=3",
    "https://api.dicebear.com/7.x/avataaars/png?seed=4",
    "https://api.dicebear.com/7.x/avataaars/png?seed=5",
    "https://api.dicebear.com/7.x/avataaars/png?seed=6",
    "https://api.dicebear.com/7.x/avataaars/png?seed=7",
    "https://api.dicebear.com/7.x/avataaars/png?seed=8",
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    var snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (snap.exists) {
      var d = snap.data() as Map<String, dynamic>;
      setState(() {
        myDisplayName = (d['username'] ?? d['name'] ?? "demo_me").toString();
        myPhotoUrl = (d['photoUrl'] ?? d['photo'] ?? "").toString();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
    await _saveCurrentAccount();
    await _loadSavedAccounts();
  }

  // ============ FRIENDS LIST LOGIC ============
  Future<void> _showFriendsList() async {
    String? myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) {
            return FutureBuilder(
              future: Supabase.instance.client.from('follows').select().eq('follower_uid', myUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.black));
                }
                var friends = snapshot.data as List? ?? [];
                if (friends.isEmpty) {
                  return Column(
                    children: [
                      const SizedBox(height: 15),
                      Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 20),
                      const Text("Friends", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                      const SizedBox(height: 40),
                      const Icon(Icons.people_outline, size: 60, color: Colors.grey),
                      const SizedBox(height: 10),
                      const Text("Abhi koi friend nahi", style: TextStyle(color: Colors.grey)),
                    ],
                  );
                }
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 15),
                    Text("Friends (${friends.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: friends.length,
                        itemBuilder: (_, i) {
                          var f = friends[i];
                          return ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.black, child: Text((f['following_uid'] ?? "U")[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                            title: Text(f['following_uid'].toString(), style: const TextStyle(color: Colors.black, fontSize: 14)),
                            trailing: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(80, 32)), child: const Text("Message", style: TextStyle(color: Colors.white, fontSize: 12))),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showDPOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(15),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 15),
          const Text("Profile Photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
          const SizedBox(height: 15),
          ListTile(leading: const Icon(Icons.camera_alt, color: Colors.black), title: const Text("Camera se lo", style: TextStyle(color: Colors.black)), onTap: () { Navigator.pop(ctx); _pickAndUpload(ImageSource.camera); }),
          ListTile(leading: const Icon(Icons.photo_library, color: Colors.black), title: const Text("Gallery se chuno", style: TextStyle(color: Colors.black)), onTap: () { Navigator.pop(ctx); _pickAndUpload(ImageSource.gallery); }),
          ListTile(leading: const Icon(Icons.face, color: Colors.black), title: const Text("Avatar chuno", style: TextStyle(color: Colors.black)), onTap: () { Navigator.pop(ctx); _showAvatarPicker(); }),
          if (myPhotoUrl.isNotEmpty) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Photo hatao", style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(ctx); _removePhoto(); }),
        ]),
      ),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Container(padding: const EdgeInsets.all(15), height: 300, child: Column(children: [const Text("Avatar Chuno", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)), const SizedBox(height: 15), Expanded(child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: avatarUrls.length, itemBuilder: (_, i) => GestureDetector(onTap: () { Navigator.pop(ctx); _updatePhotoUrl(avatarUrls[i]); }, child: CircleAvatar(backgroundImage: NetworkImage(avatarUrls[i])))))])));
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      setState(() => _uploading = true);
      var xfile = await _picker.pickImage(source: source, imageQuality: 70);
      if (xfile == null) { setState(() => _uploading = false); return; }
      File file = File(xfile.path);
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String fileName = "$uid/${DateTime.now().millisecondsSinceEpoch}.jpg";
      await Supabase.instance.client.storage.from('avatars').upload(fileName, file, fileOptions: const FileOptions(upsert: true));
      String publicUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
      await _updatePhotoUrl(publicUrl);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally { if (mounted) setState(() => _uploading = false); }
  }

  Future<void> _updatePhotoUrl(String url) async {
    setState(() => myPhotoUrl = url);
    String uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({'photo': url, 'photoUrl': url}, SetOptions(merge: true));
    try { await FirebaseAuth.instance.currentUser!.updatePhotoURL(url); } catch (_) {}
    await _saveCurrentAccount();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("DP update ho gayi ✅"), backgroundColor: Colors.green));
  }

  Future<void> _removePhoto() async {
    setState(() => myPhotoUrl = "");
    String uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({'photo': "", 'photoUrl': ""}, SetOptions(merge: true));
    await _saveCurrentAccount();
  }

  Future<void> _editName() async {
    TextEditingController ctrl = TextEditingController(text: myDisplayName);
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: Colors.white, title: const Text("Name Edit Karo", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), content: TextField(controller: ctrl, style: const TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Naya naam", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black), onPressed: () async { String newName = ctrl.text.trim(); if (newName.length < 2) return; await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).set({'name': newName, 'username': newName.toLowerCase().replaceAll(" ", "_")}, SetOptions(merge: true)); setState(() => myDisplayName = newName); await _saveCurrentAccount(); if (mounted) Navigator.pop(ctx); }, child: const Text("Save", style: TextStyle(color: Colors.white)))]));
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('yuopni_saved_accounts');
    if (data != null) setState(() { savedAccounts = List<Map<String, dynamic>>.from(jsonDecode(data)); });
  }

  Future<void> _saveCurrentAccount() async {
    final user = FirebaseAuth.instance.currentUser; if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    String name = myDisplayName.isNotEmpty ? myDisplayName : "User";
    Map<String, dynamic> acc = {'uid': user.uid, 'name': name, 'email': user.email ?? "", 'photo': myPhotoUrl};
    List<Map<String, dynamic>> current = []; String? old = prefs.getString('yuopni_saved_accounts');
    if (old != null) current = List<Map<String, dynamic>>.from(jsonDecode(old));
    current.removeWhere((a) => a['uid'] == user.uid); current.add(acc); savedAccounts = current;
    await prefs.setString('yuopni_saved_accounts', jsonEncode(savedAccounts)); if (mounted) setState(() {});
  }

  Future<void> _removeAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    savedAccounts.removeWhere((a) => a['uid'] == uid);
    await prefs.setString('yuopni_saved_accounts', jsonEncode(savedAccounts)); if (mounted) setState(() {});
  }

  Future<void> _switchAccountDialog() async {
    await _loadSavedAccounts(); await _saveCurrentAccount();
    showModalBottomSheet(context: context, backgroundColor: Colors.white, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Container(padding: const EdgeInsets.all(15), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))), const SizedBox(height: 15), const Text("Switch Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)), const SizedBox(height: 10), ...savedAccounts.where((a) => a['uid'] != FirebaseAuth.instance.currentUser?.uid).map((acc) => ListTile(leading: acc['photo'] != "" ? CircleAvatar(radius: 22, backgroundImage: NetworkImage(acc['photo'])) : CircleAvatar(radius: 22, child: Text(acc['name'][0].toUpperCase())), title: Text(acc['name'], style: const TextStyle(color: Colors.black)), trailing: IconButton(icon: const Icon(Icons.delete, size: 20), onPressed: () => _removeAccount(acc['uid'])), onTap: () async { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login with ${acc['email']}"))); })), const SizedBox(height: 10), SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Logout", style: TextStyle(color: Colors.white)), onPressed: () async { Navigator.pop(ctx); try { await GoogleSignIn().signOut(); } catch (_) {} await FirebaseAuth.instance.signOut(); })), SizedBox(height: MediaQuery.of(ctx).viewInsets.bottom + 10)])));
  }

  List<QueryDocumentSnapshot> _sortDocs(List<QueryDocumentSnapshot> docs) {
    docs.sort((a, b) {
      var da = a.data() as Map<String, dynamic>; var db = b.data() as Map<String, dynamic>;
      Timestamp? ta = da['createdAt'] is Timestamp ? da['createdAt'] : da['timestamp'] is Timestamp ? da['timestamp'] : null;
      Timestamp? tb = db['createdAt'] is Timestamp ? db['createdAt'] : db['timestamp'] is Timestamp ? db['timestamp'] : null;
      if (ta == null && tb == null) return 0; if (ta == null) return 1; if (tb == null) return -1; return tb.compareTo(ta);
    });
    return docs;
  }

  // ===== FIXED THUMBNAIL + VIEWS WIDGET =====
  Widget _buildReelItem(Map<String, dynamic> data) {
    String thumb = (data['thumbnail'] ?? '').toString();
    String mediaUrl = (data['mediaUrl'] ?? data['videoUrl'] ?? '').toString();
    int views = (data['views'] ?? data['views_count'] ?? data['viewsCount'] ?? 0) as int;
    // Agar views int nahi hai toh try parse
    if (views == 0) {
      var v = data['views'];
      if (v is String) views = int.tryParse(v) ?? 0;
    }

    String displayUrl = thumb.isNotEmpty ? thumb : mediaUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail ya Video ka placeholder
        displayUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: displayUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.grey[900]!, Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 36)),
                ),
              )
            : Container(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.grey[900]!, Colors.black])),
                child: const Center(child: Icon(Icons.videocam, color: Colors.white54, size: 30)),
              ),
        // Gradient for views visibility
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 50,
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent])),
          ),
        ),
        // Play icon center
        const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32)),
        // Views count corner
        Positioned(
          bottom: 5,
          left: 5,
          child: Row(
            children: [
              const Icon(Icons.visibility, color: Colors.white, size: 14),
              const SizedBox(width: 3),
              Text(_formatViews(views), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) return "${(views / 1000000).toStringAsFixed(1)}M";
    if (views >= 1000) return "${(views / 1000).toStringAsFixed(1)}K";
    return views.toString();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            const SizedBox(height: 50),
            Stack(children: [
              GestureDetector(onTap: _showDPOptions, child: Stack(alignment: Alignment.center, children: [CircleAvatar(radius: 50, backgroundColor: Colors.deepOrange, backgroundImage: myPhotoUrl.isNotEmpty && myPhotoUrl.startsWith('http') ? NetworkImage(myPhotoUrl) : null, child: myPhotoUrl.isEmpty ? Text((myDisplayName.isNotEmpty ? myDisplayName[0] : "T").toUpperCase(), style: const TextStyle(fontSize: 35, color: Colors.white)) : null), if (_uploading) const CircleAvatar(radius: 50, backgroundColor: Colors.black54, child: CircularProgressIndicator(color: Colors.white)) ])),
              Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: _showDPOptions, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, size: 16, color: Colors.white)))),
              Positioned(bottom: 30, left: 75, child: GestureDetector(onTap: _switchAccountDialog, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black12)), child: const Icon(Icons.switch_account, size: 16, color: Colors.black)))),
            ]),
            const SizedBox(height: 12),
            _loading ? const CircularProgressIndicator(strokeWidth: 2) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(myDisplayName.isNotEmpty ? myDisplayName : "demo_me", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)), const SizedBox(width: 8), GestureDetector(onTap: _editName, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.edit, size: 12, color: Colors.white), SizedBox(width: 4), Text("Edit", style: TextStyle(color: Colors.white, fontSize: 12))])))]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton.icon(onPressed: _showFriendsList, icon: const Icon(Icons.people, size: 16), label: const Text("Friends"), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))),
              const SizedBox(width: 12),
              OutlinedButton.icon(onPressed: _editName, icon: const Icon(Icons.edit, size: 16, color: Colors.black), label: const Text("Edit Profile", style: TextStyle(color: Colors.black)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))),
            ]),
            const SizedBox(height: 15),
            const TabBar(labelColor: Colors.black, unselectedLabelColor: Colors.grey, indicatorColor: Colors.black, tabs: [Tab(icon: Icon(Icons.grid_on), text: "Posts"), Tab(icon: Icon(Icons.video_library), text: "Reels")]),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(children: [
                // POSTS TAB
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid).snapshots(),
                  builder: (c, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));
                    if (snap.data!.docs.isEmpty) return const Center(child: Text("Abhi koi Post nahi", style: TextStyle(color: Colors.black)));
                    var docs = _sortDocs(snap.data!.docs);
                    return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: docs.length, itemBuilder: (_, i) {
                      var d = docs[i].data() as Map<String, dynamic>;
                      return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReelPage(initialIndex: i, myReels: docs))), child: _buildReelItem(d));
                    });
                  },
                ),
                // REELS TAB
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid).snapshots(),
                  builder: (c, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));
                    var all = _sortDocs(snap.data!.docs);
                    var reels = all.where((doc) { var d = doc.data() as Map<String, dynamic>; return d['isVideo'] == true || (d['mediaUrl'] ?? '').toString().contains('.mp4') || (d['type'] ?? '') == 'reel'; }).toList();
                    if (reels.isEmpty) return const Center(child: Text("Abhi koi Reel nahi", style: TextStyle(color: Colors.black)));
                    return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: reels.length, itemBuilder: (_, i) {
                      var d = reels[i].data() as Map<String, dynamic>;
                      return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReelPage(initialIndex: i, myReels: reels))), child: _buildReelItem(d));
                    });
                  },
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}