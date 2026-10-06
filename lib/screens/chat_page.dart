import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final String otherUid;
  final String otherUsername;
  final String otherPhoto;
  const ChatPage({super.key, required this.otherUid, required this.otherUsername, required this.otherPhoto});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _msgCtrl = TextEditingController();
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  // Stable chatId - hashCode se duplicate nahi banega
  String get chatId {
    List<String> ids = [myUid, widget.otherUid];
    ids.sort();
    return ids.join("_");
  }

  Future<void> _sendMessage() async {
    if(_msgCtrl.text.trim().isEmpty) return;
    String text = _msgCtrl.text.trim();
    _msgCtrl.clear();

    // Message add
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'text': text,
      'senderId': myUid,
      'receiverId': widget.otherUid,
      'time': FieldValue.serverTimestamp(),
    });

    // Last message update - null safe
    String myName = FirebaseAuth.instance.currentUser!.displayName??
                    FirebaseAuth.instance.currentUser!.email?.split('@')[0]?? "Me";
    String myPhoto = FirebaseAuth.instance.currentUser!.photoURL?? "";

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': [myUid, widget.otherUid],
      'lastMsg': text,
      'lastTime': FieldValue.serverTimestamp(),
      'userNames': {
        myUid: myName,
        widget.otherUid: widget.otherUsername
      },
      'userPhotos': {
        myUid: myPhoto,
        widget.otherUid: widget.otherPhoto
      }
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        title: Row(children: [
          CircleAvatar(
            backgroundColor: Colors.white10,
            backgroundImage: widget.otherPhoto.isNotEmpty? NetworkImage(widget.otherPhoto) : null,
            child: widget.otherPhoto.isEmpty? Icon(Icons.person, color: Colors.white): null
          ),
          SizedBox(width: 10),
          Expanded(child: Text(widget.otherUsername, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').orderBy('time', descending: true).snapshots(),
            builder: (c,snap){
              if(!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
              if(snap.data!.docs.isEmpty) return Center(child: Text("Say Hi 👋", style: TextStyle(color: Colors.white54)));
              return ListView.builder(
                reverse: true,
                itemCount: snap.data!.docs.length,
                itemBuilder: (_,i){
                  var d = snap.data!.docs[i].data() as Map<String,dynamic>;
                  bool isMe = d['senderId'] == myUid;
                  return Align(
                    alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe? Colors.pink : Colors.white10,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                          bottomLeft: isMe? Radius.circular(15): Radius.circular(0),
                          bottomRight: isMe? Radius.circular(0): Radius.circular(15),
                        )
                      ),
                      child: Text(d['text']??'', style: TextStyle(color: Colors.white)),
                    ),
                  );
                },
              );
            }
          ),
        ),
        Padding(
          padding: EdgeInsets.all(10),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _msgCtrl,
              style: TextStyle(color: Colors.white),
              onSubmitted: (_)=> _sendMessage(),
              decoration: InputDecoration(
                hintText: "Message ${widget.otherUsername}...",
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10)
              ),
            )),
            SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.pink,
              child: IconButton(icon: Icon(Icons.send, color: Colors.white), onPressed: _sendMessage)
            )
          ]),
        )
      ]),
    );
  }
}