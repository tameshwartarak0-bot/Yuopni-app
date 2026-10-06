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
  TextEditingController _msgCtrl = TextEditingController();
  String myUid = FirebaseAuth.instance.currentUser!.uid;
  String get chatId => myUid.hashCode <= widget.otherUid.hashCode? "${myUid}_${widget.otherUid}" : "${widget.otherUid}_$myUid";

  void _sendMessage() async {
    if(_msgCtrl.text.trim().isEmpty) return;
    String text = _msgCtrl.text.trim();
    _msgCtrl.clear();

    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'text': text,
      'senderId': myUid,
      'receiverId': widget.otherUid,
      'time': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': [myUid, widget.otherUid],
      'lastMsg': text,
      'lastTime': FieldValue.serverTimestamp(),
      'userNames': {
        myUid: FirebaseAuth.instance.currentUser!.displayName?? "Me",
        widget.otherUid: widget.otherUsername
      },
      'userPhotos': {
        myUid: FirebaseAuth.instance.currentUser!.photoURL?? "",
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
        title: Row(children: [
          CircleAvatar(backgroundImage: widget.otherPhoto.isNotEmpty? NetworkImage(widget.otherPhoto) : null, child: widget.otherPhoto.isEmpty? Icon(Icons.person) : null),
          SizedBox(width: 10),
          Text(widget.otherUsername, style: TextStyle(color: Colors.white, fontSize: 16))
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').orderBy('time', descending: true).snapshots(),
            builder: (c,snap){
              if(!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
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
                        borderRadius: BorderRadius.circular(15)
                      ),
                      child: Text(d['text'], style: TextStyle(color: Colors.white)),
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
              decoration: InputDecoration(
                hintText: "Message...",
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)
              ),
            )),
            SizedBox(width: 8),
            CircleAvatar(backgroundColor: Colors.pink, child: IconButton(icon: Icon(Icons.send, color: Colors.white), onPressed: _sendMessage))
          ]),
        )
      ]),
    );
  }
}