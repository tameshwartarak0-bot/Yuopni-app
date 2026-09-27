import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../global.dart';
import '../widgets/login_dialog.dart';

class MessagePage extends StatefulWidget {
  @override
  _MessagePageState createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  TextEditingController _searchCtrl = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchText = _searchCtrl.text.trim().toLowerCase());
    });
  }

  // Login check - har tap par
  Future<bool> _checkLogin() async {
    if (FirebaseAuth.instance.currentUser == null && !isLoggedIn) {
      await showDialog(context: context, builder: (_) => LoginDialog());
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: "ID Search... username likho",
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: _searchText.isNotEmpty ? IconButton(icon: Icon(Icons.clear), onPressed: ()=> _searchCtrl.clear()) : null,
          ),
        ),
      ),
      body: Column(
        children: [
          // Agar login nahi hai to
          if (currentUid == null)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.message_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Messages dekhne ke liye Login karo"),
                  SizedBox(height: 12),
                  ElevatedButton(onPressed: ()=> showDialog(context: context, builder: (_)=> LoginDialog()), child: Text("Login Karo"))
                ]),
              ),
            )
          else
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // Search hai to users search, nahi to followers show
                stream: _searchText.isEmpty
                  ? FirebaseFirestore.instance.collection('users').doc(currentUid).collection('followers').snapshots() // tere followers
                  : FirebaseFirestore.instance.collection('users').where('username_search', isGreaterThanOrEqualTo: _searchText).where('username_search', isLessThan: _searchText + 'z').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  // Search result
                  List<QueryDocumentSnapshot> docs = [];
                  if (snapshot.hasData) docs = snapshot.data!.docs;

                  // Agar search khali hai aur follower collection khali hai to - saare users dikhao (starting ke liye)
                  if (_searchText.isEmpty && docs.isEmpty) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').limit(30).snapshots(),
                      builder: (c, snap2) {
                        if (!snap2.hasData) return Center(child: CircularProgressIndicator());
                        return _buildList(snap2.data!.docs, currentUid);
                      },
                    );
                  }

                  if (docs.isEmpty) {
                    return Center(child: Text(_searchText.isEmpty ? "Abhi koi follower nahi" : "ID '$_searchText' nahi mila"));
                  }

                  return _buildList(docs, currentUid);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs, String currentUid) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (_, i) {
        var data = docs[i].data() as Map<String, dynamic>;
        // follower collection me uid hoga, users collection me data
        String uid = data['uid'] ?? docs[i].id;
        String username = data['username'] ?? "user_$i";
        String photo = data['photoURL'] ?? data['userPhoto'] ?? "";

        if(uid == currentUid) return SizedBox(); // khud ko mat dikhao

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty ? Icon(Icons.person) : null,
          ),
          title: Text(username),
          subtitle: Text(_searchText.isEmpty ? "Follower • Message karo" : "Tap to chat"),
          trailing: Icon(Icons.chat_bubble_outline),
          onTap: () async {
            bool ok = await _checkLogin();
            if(!ok) return;
            // Yaha par chat page par le jao
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$username se chat start")));
            // Navigator.push(context, MaterialPageRoute(builder: (_)=> ChatPage(otherUid: uid, otherName: username)));
          },
        );
      },
    );
  }
}