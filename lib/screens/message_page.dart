import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class MessagePage extends StatefulWidget {
  @override
  _MessagePageState createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  TextEditingController _searchCtrl = TextEditingController();
  String _search = "";
  String myUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState(){
    super.initState();
    _searchCtrl.addListener(()=> setState(()=> _search = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("Messages", style: TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        // Search bar - ID se search
        Padding(
          padding: EdgeInsets.all(10),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "ID se search karo...",
              hintStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
            ),
          ),
        ),

        Expanded(
          child: _search.isNotEmpty
          // SEARCH RESULT - ID se user dhoondo
         ? StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('searchKeys', arrayContains: _search).limit(20).snapshots(),
            builder: (c,snap){
              if(!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
              if(snap.data!.docs.isEmpty) return Center(child: Text("Koi ID nahi mili", style: TextStyle(color: Colors.white54)));
              return ListView.builder(
                itemCount: snap.data!.docs.length,
                itemBuilder: (_,i){
                  var d = snap.data!.docs[i].data() as Map<String,dynamic>;
                  if(d['uid'] == myUid) return SizedBox();
                  String username = d['username']?? d['name']?? 'User';
                  String photo = (d['photo']?? d['photoURL']?? '').toString();
                  return ListTile(
                    leading: CircleAvatar(backgroundImage: photo.isNotEmpty? NetworkImage(photo): null, child: photo.isEmpty? Icon(Icons.person): null),
                    title: Text(username, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("Tap to chat", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: Icon(Icons.chat_bubble, color: Colors.pink),
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (_)=> ChatPage(otherUid: d['uid'], otherUsername: username, otherPhoto: photo)));
                    },
                  );
                }
              );
            }
          )
          // NORMAL CHAT LIST - Jisse pehle chat kiya hai
          : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: myUid).orderBy('lastTime', descending: true).snapshots(),
            builder: (c,snap){
              if(!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
              if(snap.data!.docs.isEmpty) return Center(child: Text("Koi chat nahi hai\nUpar ID search karke chat start karo", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)));
              return ListView.builder(
                itemCount: snap.data!.docs.length,
                itemBuilder: (_,i){
                  var d = snap.data!.docs[i].data() as Map<String,dynamic>;
                  List parts = d['participants'];
                  String otherUid = parts[0] == myUid? parts[1] : parts[0];
                  Map names = d['userNames']?? {};
                  Map photos = d['userPhotos']?? {};
                  String otherName = names[otherUid]?? 'User';
                  String otherPhoto = (photos[otherUid]?? '').toString();
                  String lastMsg = d['lastMsg']?? '';

                  return ListTile(
                    leading: CircleAvatar(backgroundImage: otherPhoto.isNotEmpty? NetworkImage(otherPhoto): null, child: otherPhoto.isEmpty? Icon(Icons.person): null),
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
}