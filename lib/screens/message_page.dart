import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class MessagePage extends StatefulWidget {
  @override
  _MessagePageState createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = "";
  String? myUid;

  @override
  void initState(){
    super.initState();
    myUid = FirebaseAuth.instance.currentUser?.uid;
    _searchCtrl.addListener(()=> setState(()=> _search = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose(){
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if(myUid == null){
      return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.pink)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("Messages", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: EdgeInsets.all(10),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "ID se search karo... jaise rahul_07",
              hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: Colors.white54),
              suffixIcon: _search.isNotEmpty? IconButton(icon: Icon(Icons.clear, color: Colors.white54), onPressed: ()=> _searchCtrl.clear()): null,
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
            ),
          ),
        ),

        Expanded(
          child: _search.isNotEmpty
          // --- SEARCH MODE ---
        ? StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('searchKeys', arrayContains: _search).limit(20).snapshots(),
            builder: (c,snap){
              if(!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));

              // Agar searchKeys se nahi mila to username_search se try karo
              if(snap.data!.docs.isEmpty){
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').orderBy('username_search').startAt([_search]).endAt([_search + '\uf8ff']).limit(20).snapshots(),
                  builder: (c2,snap2){
                    if(!snap2.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
                    if(snap2.data!.docs.isEmpty) return Center(child: Text("Koi ID nahi mili: $_search", style: TextStyle(color: Colors.white54)));
                    return _buildSearchList(snap2.data!.docs);
                  }
                );
              }
              return _buildSearchList(snap.data!.docs);
            }
          )
          // --- CHAT LIST MODE ---
          : StreamBuilder<QuerySnapshot>(
            // Index error se bachne ke liye orderBy hata diya, list ko app me sort karenge
            stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: myUid).snapshots(),
            builder: (c,snap){
              if(!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
              if(snap.data!.docs.isEmpty) return Center(child: Text("Koi chat nahi hai\nUpar ID search karke chat start karo", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)));

              // lastTime se sort
              var docs = snap.data!.docs;
              docs.sort((a,b){
                var at = (a.data() as Map)['lastTime'] as Timestamp?;
                var bt = (b.data() as Map)['lastTime'] as Timestamp?;
                if(at==null || bt==null) return 0;
                return bt.compareTo(at);
              });

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_,i){
                  var d = docs[i].data() as Map<String,dynamic>;
                  List parts = d['participants']?? [];
                  if(parts.length < 2) return SizedBox();
                  String otherUid = parts[0] == myUid? parts[1] : parts[0];
                  Map names = d['userNames']?? {};
                  Map photos = d['userPhotos']?? {};
                  String otherName = names[otherUid]?? names[parts[0]]?? 'User';
                  String otherPhoto = (photos[otherUid]?? '').toString();
                  String lastMsg = d['lastMsg']?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.white10,
                      backgroundImage: otherPhoto.isNotEmpty? NetworkImage(otherPhoto): null,
                      child: otherPhoto.isEmpty? Icon(Icons.person, color: Colors.white): null
                    ),
                    title: Text(otherName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(lastMsg, style: TextStyle(color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (_)=> ChatPage(otherUid: otherUid, otherUsername: otherName, otherPhoto: otherPhoto)));
                    },
                  );
                }
              );
            }
          )
        )
      ]),
    );
  }

  Widget _buildSearchList(List<QueryDocumentSnapshot> docs){
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (_,i){
        var d = docs[i].data() as Map<String,dynamic>;
        if(d['uid'] == myUid) return SizedBox(); // khud ko hide
        String username = (d['username']?? d['name']?? 'User').toString();
        String photo = (d['photo']?? d['photoURL']?? '').toString();
        String googleName = (d['googleName']?? '').toString();
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.white10,
            backgroundImage: photo.isNotEmpty? NetworkImage(photo): null,
            child: photo.isEmpty? Icon(Icons.person, color: Colors.white): null
          ),
          title: Text(username, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(googleName.isNotEmpty? googleName : "Tap to chat", style: TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: Icon(Icons.chat_bubble, color: Colors.pink, size: 20),
          onTap: (){
            Navigator.push(context, MaterialPageRoute(builder: (_)=> ChatPage(otherUid: d['uid'], otherUsername: username, otherPhoto: photo)));
          },
        );
      }
    );
  }
}