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
  List<Map<String,dynamic>> _searchResult = [];
  bool _isSearching = false;

  @override
  void initState(){
    super.initState();
    myUid = FirebaseAuth.instance.currentUser?.uid;
    _searchCtrl.addListener(() {
      String s = _searchCtrl.text.trim().toLowerCase();
      setState(()=> _search = s);
      if(s.isNotEmpty){
        _doSearch(s);
      } else {
        setState(()=> _searchResult = []);
      }
    });
  }

  Future<void> _doSearch(String query) async {
    setState(()=> _isSearching = true);
    try {
      String q = query.toLowerCase().replaceAll(" ", "_");

      // 1. username exact se
      var snap1 = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: q).limit(10).get();

      // 2. name prefix se
      var snap2 = await FirebaseFirestore.instance.collection('users')
         .where('username_search', isGreaterThanOrEqualTo: q)
         .where('username_search', isLessThanOrEqualTo: q + '\uf8ff')
         .limit(10).get();

      // 3. name field se bhi (Tameshwar jaisa naam)
      var snap3 = await FirebaseFirestore.instance.collection('users').where('name', isGreaterThanOrEqualTo: query).where('name', isLessThanOrEqualTo: query + '\uf8ff').limit(10).get().catchError((_)=> null);

      Set<String> seen = {};
      List<Map<String,dynamic>> temp = [];
      for(var d in [...snap1.docs,...snap2.docs,...(snap3?.docs??[])]){
        var data = d.data() as Map<String,dynamic>;
        if(data['uid'] == myUid) continue;
        if(seen.contains(data['uid'])) continue;
        seen.add(data['uid']);
        temp.add(data);
      }

      // agar abhi bhi kuch nahi mila to saare users la ke filter karo (client side)
      if(temp.isEmpty){
        var all = await FirebaseFirestore.instance.collection('users').limit(50).get();
        for(var d in all.docs){
          var data = d.data() as Map<String,dynamic>;
          if(data['uid'] == myUid) continue;
          String uname = (data['username']??"").toString().toLowerCase();
          String name = (data['name']??"").toString().toLowerCase();
          if(uname.contains(q) || name.contains(query.toLowerCase())){
            if(!seen.contains(data['uid'])){
              temp.add(data);
              seen.add(data['uid']);
            }
          }
        }
      }

      setState(()=> _searchResult = temp);
    } catch(e){
      print("search error $e");
    }
    setState(()=> _isSearching = false);
  }

  @override
  void dispose(){
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if(myUid == null) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.pink)));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text("Messages", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "ID se search karo... jaise rahul_07",
              hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.white54),
              suffixIcon: _search.isNotEmpty? IconButton(icon: Icon(Icons.clear, color: Colors.white54), onPressed: ()=> _searchCtrl.clear()): null,
              filled: true,
              fillColor: Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),

        Expanded(
          child: _search.isNotEmpty
         ? _isSearching? Center(child: CircularProgressIndicator(color: Colors.pink))
            : _searchResult.isEmpty? Center(child: Text("Koi ID nahi mili: $_search", style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                itemCount: _searchResult.length,
                itemBuilder: (_,i){
                  var d = _searchResult[i];
                  String uid = d['uid']??"";
                  String displayName = (d['name']?? d['displayName']?? d['username']?? 'User').toString();
                  String username = (d['username']?? '').toString();
                  String photo = (d['photo']?? d['photoURL']?? '').toString();
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.white10, backgroundImage: photo.isNotEmpty? NetworkImage(photo): null, child: photo.isEmpty? Icon(Icons.person, color: Colors.white): null),
                    title: Text(displayName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(username.isNotEmpty? "@$username" : "Tap to chat", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: Icon(Icons.chat_bubble_outline, color: Colors.pink),
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (_)=> ChatPage(otherUid: uid, otherUsername: displayName, otherPhoto: photo)));
                    },
                  );
                }
              )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: myUid).snapshots(),
              builder: (c,snap){
                if(snap.hasError) return Center(child: Text("Error: ${snap.error}", style: TextStyle(color: Colors.white54)));
                if(snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Colors.pink));
                if(!snap.hasData || snap.data!.docs.isEmpty) return Center(child: Text("Koi chat nahi hai\nUpar ID search karke chat start karo", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)));

                var docs = snap.data!.docs;
                docs.sort((a,b){
                  var da = (a.data() as Map)['lastTime'] as Timestamp?;
                  var db = (b.data() as Map)['lastTime'] as Timestamp?;
                  if(da==null) return 1;
                  if(db==null) return -1;
                  return db.compareTo(da);
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
                    String otherName = (names[otherUid]?? 'User').toString();
                    String otherPhoto = (photos[otherUid]?? '').toString();
                    String lastMsg = (d['lastMsg']?? '').toString();
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.white10, backgroundImage: otherPhoto.isNotEmpty? NetworkImage(otherPhoto): null, child: otherPhoto.isEmpty? Icon(Icons.person, color: Colors.white): null),
                      title: Text(otherName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(lastMsg, style: TextStyle(color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> ChatPage(otherUid: otherUid, otherUsername: otherName, otherPhoto: otherPhoto))),
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