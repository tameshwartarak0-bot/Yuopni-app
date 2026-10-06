import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

class ChatPage extends StatefulWidget {
  final String otherUid;
  final String otherUsername;
  final String otherPhoto;
  const ChatPage({required this.otherUid, required this.otherUsername, required this.otherPhoto, super.key});
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _msgCtrl = TextEditingController();
  String? myUid;
  String? myName;
  String? myPhoto;
  String? chatId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    myUid = FirebaseAuth.instance.currentUser?.uid;
    _initChat();
  }

  Future<void> _initChat() async {
    var me = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    myName = (me.data()?['name']?? FirebaseAuth.instance.currentUser?.displayName)?? "User";
    myPhoto = (me.data()?['photo']?? FirebaseAuth.instance.currentUser?.photoURL)?? "";

    List<String> ids = [myUid!, widget.otherUid]..sort();
    chatId = ids.join("_");

    var chatSnap = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    if(!chatSnap.exists){
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': [myUid, widget.otherUid],
        'userNames': {myUid!: myName, widget.otherUid: widget.otherUsername},
        'userPhotos': {myUid!: myPhoto, widget.otherUid: widget.otherPhoto},
        'lastMsg': "",
        'lastTime': FieldValue.serverTimestamp(),
      });
    }
    setState((){});
  }

  Future<void> _sendText() async {
    if(_msgCtrl.text.trim().isEmpty) return;
    String text = _msgCtrl.text.trim();
    _msgCtrl.clear();
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'sender': myUid,
      'type': 'text',
      'text': text,
      'time': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMsg': text,
      'lastTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _sendMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    final XFile? file = isVideo? await picker.pickVideo(source: source) : await picker.pickImage(source: source, imageQuality: 70);
    if(file == null) return;
    setState(()=> _sending = true);
    try{
      String fileName = "${myUid}_${DateTime.now().millisecondsSinceEpoch}.${isVideo? 'mp4':'jpg'}";
      String path = "chat_media/$fileName";
      await Supabase.instance.client.storage.from('videos').upload(path, File(file.path));
      String url = Supabase.instance.client.storage.from('videos').getPublicUrl(path);

      await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
        'sender': myUid,
        'type': isVideo? 'video' : 'image',
        'mediaUrl': url,
        'time': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'lastMsg': isVideo? "📹 Video" : "📷 Photo",
        'lastTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload fail: $e")));
    }
    setState(()=> _sending = false);
  }

  void _showAttachSheet(){
    showModalBottomSheet(context: context, backgroundColor: Color(0xFF1E1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))), builder: (_)=> Container(
      padding: EdgeInsets.all(15),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _attachBtn(Icons.photo, "Photo", ()=> _sendMedia(ImageSource.gallery, false)),
        _attachBtn(Icons.camera_alt, "Camera", ()=> _sendMedia(ImageSource.camera, false)),
        _attachBtn(Icons.videocam, "Video", ()=> _sendMedia(ImageSource.gallery, true)),
      ]),
    ));
  }

  Widget _attachBtn(IconData ic, String label, VoidCallback tap){
    return GestureDetector(onTap: (){ Navigator.pop(context); tap(); }, child: Column(children: [CircleAvatar(radius: 28, backgroundColor: Colors.pink, child: Icon(ic, color: Colors.white)), SizedBox(height: 6), Text(label, style: TextStyle(color: Colors.white))]));
  }

  @override
  Widget build(BuildContext context) {
    if(chatId==null) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.pink)));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Row(children: [CircleAvatar(backgroundImage: widget.otherPhoto.isNotEmpty? NetworkImage(widget.otherPhoto): null, radius: 18), SizedBox(width: 10), Text(widget.otherUsername, style: TextStyle(color: Colors.white, fontSize: 16))]), iconTheme: IconThemeData(color: Colors.white)),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').orderBy('time', descending: false).snapshots(),
          builder: (c,snap){
            if(!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
            var docs = snap.data!.docs;
            return ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (_,i){
                var d = docs[i].data() as Map<String,dynamic>;
                bool isMe = d['sender']==myUid;
                String type = d['type']??'text';
                return Align(
                  alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: type=='text'? EdgeInsets.symmetric(horizontal: 14, vertical: 10) : EdgeInsets.all(6),
                    decoration: BoxDecoration(color: isMe? Colors.pink : Color(0xFF222222), borderRadius: BorderRadius.circular(14)),
                    child: type=='text'? Text(d['text']??"", style: TextStyle(color: Colors.white))
                    : type=='image'? ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: d['mediaUrl'], width: 200, fit: BoxFit.cover))
                    : type=='video'? Container(width: 200, height: 280, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)), child: Stack(alignment: Alignment.center, children: [Icon(Icons.play_circle_fill, color: Colors.white, size: 50), Positioned(bottom: 6, left: 6, child: Text("Video", style: TextStyle(color: Colors.white, fontSize: 11)))]))
                    : type=='reel'? GestureDetector(
                      onTap: (){
                        // yahan reel open kara sakta hai
                      },
                      child: Container(width: 180, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(height: 240, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)), child: Stack(fit: StackFit.expand, children: [
                          d['thumbnail']!=null && d['thumbnail'].toString().isNotEmpty? CachedNetworkImage(imageUrl: d['thumbnail'], fit: BoxFit.cover) : Container(color: Colors.grey[900]),
                          Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 45)),
                        ])),
                        SizedBox(height: 4),
                        Text("🎬 Reel - Tap to view", style: TextStyle(color: Colors.white, fontSize: 12)),
                      ]))
                    : Text("Unsupported", style: TextStyle(color: Colors.white)),
                  ),
                );
              }
            );
          }
        )),
        if(_sending) Padding(padding: EdgeInsets.all(8), child: Row(children: [CircularProgressIndicator(color: Colors.pink, strokeWidth: 2), SizedBox(width: 10), Text("Uploading...", style: TextStyle(color: Colors.white54))])),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Color(0xFF121212),
          child: Row(children: [
            IconButton(icon: Icon(Icons.add_a_photo, color: Colors.pink), onPressed: _showAttachSheet),
            Expanded(child: TextField(controller: _msgCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Message...", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none))),
            IconButton(icon: Icon(Icons.send, color: Colors.pink), onPressed: _sendText),
          ]),
        )
      ]),
    );
  }
}