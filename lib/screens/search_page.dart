import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_view_page.dart'; // naya page niche diya hai

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
          decoration: const InputDecoration(
            hintText: "Search Yuopni...", // YAHAN CHANGE KIYA
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(()=> query = v.trim().toLowerCase()),
        ),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabCtrl,
            labelColor: Colors.pink,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.pink,
            tabs: const [Tab(text: "Users"), Tab(text: "Posts"), Tab(text: "Reels")],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildUsers(),
                _buildPosts(),
                _buildReels(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsers() {
    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.white38),
            SizedBox(height: 15),
            Text("Search You", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Text("Find friends, posts & reels on Yuopni", style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('username_search', isGreaterThanOrEqualTo: query)
          .where('username_search', isLessThan: query + 'z')
          .snapshots(),
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        // fallback search agar username_search field nahi hai
        var docs = snap.data!.docs;
        if (docs.isEmpty) {
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('users').get(),
            builder: (c2, s2) {
              if (!s2.hasData) return const Center(child: CircularProgressIndicator());
              var filtered = s2.data!.docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                String name = (data['username'] ?? data['name'] ?? "").toString().toLowerCase();
                return name.contains(query);
              }).toList();
              if (filtered.isEmpty) return const Center(child: Text("No User Found", style: TextStyle(color: Colors.white54)));
              return _userList(filtered);
            },
          );
        }
        return _userList(docs);
      },
    );
  }

  Widget _userList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (_, i) {
        var data = docs[i].data() as Map<String, dynamic>;
        String uid = docs[i].id;
        if (uid == FirebaseAuth.instance.currentUser?.uid) return const SizedBox.shrink();
        String name = data['username'] ?? data['name'] ?? "User";
        String photo = data['photoUrl'] ?? data['photo'] ?? data['userPhoto'] ?? "";
        return ListTile(
          leading: CircleAvatar(backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, backgroundColor: Colors.grey[800], child: photo.isEmpty ? Text(name[0].toUpperCase()) : null),
          title: Text(name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(data['email'] ?? "", style: const TextStyle(color: Colors.white54, fontSize: 12)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileViewPage(userId: uid))),
        );
      },
    );
  }

  Widget _buildPosts() => Center(child: Text("Search '$query' in Posts", style: const TextStyle(color: Colors.white54)));
  Widget _buildReels() => Center(child: Text("Search '$query' in Reels", style: const TextStyle(color: Colors.white54)));
}