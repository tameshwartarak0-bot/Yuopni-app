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
            suffixIcon: _searchText.isNotEmpty
               ? IconButton(icon: Icon(Icons.clear), onPressed: () => _searchCtrl.clear())
                : null,
          ),
        ),
      ),
      body: Column(
        children: [
          if (currentUid == null)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.message_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Messages dekhne ke liye Login karo"),
                  SizedBox(height: 12),
                  ElevatedButton(onPressed: () => showDialog(context: context, builder: (_) => LoginDialog()), child: Text("Login Karo"))
                ]),
              ),
            )
          else
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // FIX 1: Proper query with orderBy + limit
                stream: _searchText.isEmpty
                   ? FirebaseFirestore.instance.collection('users').doc(currentUid).collection('followers').limit(20).snapshots()
                    : FirebaseFirestore.instance
                         .collection('users')
                         .orderBy('username_search')
                         .startAt([_searchText])
                         .endAt([_searchText + '\uf8ff'])
                         .limit(10)
                         .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  List<QueryDocumentSnapshot> docs = [];
                  if (snapshot.hasData) docs = snapshot.data!.docs;

                  if (_searchText.isEmpty && docs.isEmpty) {
                    // FIX 2: Fallback bhi limit(15) ke saath
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').limit(15).snapshots(),
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

  Widget _buildList(List<QueryDocumentSnapshot> docs, String? currentUid) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (_, i) {
        var data = docs[i].data() as Map<String, dynamic>;
        String uid = data['uid']?? docs[i].id;
        String username = data['username']?? data['displayName']?? "user_$i";
        String photo = data['photoURL']?? data['userPhoto']?? "";

        if (uid == currentUid) return SizedBox.shrink();

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
            if (!ok) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$username se chat start")));
          },
        );
      },
    );
  }
}