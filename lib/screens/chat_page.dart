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
  final ScrollController _scrollCtrl = ScrollController();
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
    myUid = FirebaseAuth.instance.currentUser?.uid; // fresh uid
    if(myUid == null) return;

    var me = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    myName = (me.data()?['name']?? FirebaseAuth.instance.currentUser?.displayName)?? "User";
    myPhoto = (me.data()?['photo']?? FirebaseAuth.instance.currentUser?.photoURL)?? "";

    List<String> ids = [myUid!, widget.otherUid];
    ids.sort();
    chatId = ids.join("_");

    var chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    var chatSnap = await chatRef.get();

    if(!chatSnap.exists){
      await chatRef.set({
        'chatId': chatId,
        'participants': [myUid, widget.otherUid], // dono ka auth uid
        'userNames': {myUid!: myName, widget.otherUid: widget.otherUsername},
        'userPhotos': {myUid!: myPhoto, widget.otherUid: widget.otherPhoto},
        'lastMsg': "",
        'lastTime': FieldValue.serverTimestamp(),
      });
    } else {
      // purane chat me bhi participants pakka update karo - yahi tera bug fix hai
      await chatRef.set({
        'participants': [myUid, widget.otherUid],
        'userNames': {myUid!: myName, widget.otherUid: widget.otherUsername},
        'userPhotos': {myUid!: myPhoto, widget.otherUid: widget.otherPhoto},
      }, SetOptions(merge: true));
    }
    if(mounted) setState((){});
  }

  Future<void> _sendText() async {
    if(_msgCtrl.text.trim().isEmpty) return;
    String text = _msgCtrl.text.trim();
    _msgCtrl.clear();
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'sender': currentUid,
      'type': 'text',
      'text': text,
      'time': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMsg': text,
      'lastMessage': text, // dono field rakh diye taaki MessagePage me jo bhi use ho
      'lastTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _scrollToBottom();
  }

  Future<void> _sendMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    final XFile? file = isVideo? await picker.pickVideo(source: source) : await picker.pickImage(source: source, imageQuality: 70);
    if(file == null) return;
    setState(()=> _sending = true);
    try{
      String currentUid = FirebaseAuth.instance.currentUser!.uid;
      String fileName = "${currentUid}_${DateTime.now().millisecondsSinceEpoch}.${isVideo? 'mp4':'jpg'}";
      String path = "chat_media/$fileName";
      await Supabase.instance.client.storage.from('videos').upload(path, File(file.path));
      String url = Supabase.instance.client.storage.from('videos').getPublicUrl(path);

      await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
        'sender': currentUid,
        'type': isVideo? 'video' : 'image',
        'mediaUrl': url,
        'time': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'lastMsg': isVideo? "📹 Video" : "📷 Photo",
        'lastMessage': isVideo? "📹 Video" : "📷 Photo",
        'lastTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _scrollToBottom();
    }catch(e){
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload fail: $e"), backgroundColor: Colors.red));
    }
    setState(()=> _sending = false);
  }

  void _scrollToBottom(){
    Future.delayed(Duration(milliseconds: 300), (){
      if(_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent+200, duration: Duration(milliseconds: 300), curve: Curves.easeOut);
    });
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

  void _openMediaViewer(String url, bool isVideo){
    Navigator.push(context, MaterialPageRoute(builder: (_)=> MediaViewerPage(url: url, isVideo: isVideo)));
  }

  @override
  Widget build(BuildContext context) {
    if(chatId==null) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.pink)));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Row(children: [CircleAvatar(backgroundImage: widget.otherPhoto.isNotEmpty? NetworkImage(widget.otherPhoto): null, radius: 18, child: widget.otherPhoto.isEmpty? Text(widget.otherUsername[0].toUpperCase()): null), SizedBox(width: 10), Text(widget.otherUsername, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]), iconTheme: IconThemeData(color: Colors.white)),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').orderBy('time', descending: false).snapshots(),
          builder: (c,snap){
            if(!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.pink));
            var docs = snap.data!.docs;
            if(docs.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_)=> _scrollToBottom());
            return ListView.builder(
              controller: _scrollCtrl,
              padding: EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (_,i){
                var d = docs[i].data() as Map<String,dynamic>;
                bool isMe = d['sender']==FirebaseAuth.instance.currentUser!.uid;
                String type = d['type']??'text';
                return Align(
                  alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width*0.72),
                    decoration: BoxDecoration(color: isMe? Colors.pink : Color(0xFF222222), borderRadius: BorderRadius.circular(14)),
                    child: type=='text'? Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Text(d['text']??"", style: TextStyle(color: Colors.white, fontSize: 15)))
                    : type=='image'? GestureDetector(
                      onTap: ()=> _openMediaViewer(d['mediaUrl'], false),
                      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: d['mediaUrl'], width: 200, fit: BoxFit.cover, placeholder: (_,__ )=> Container(width:200,height:150,color: Colors.white10, child: Center(child: CircularProgressIndicator(color: Colors.pink))))),
                    )
                    : type=='video'? GestureDetector(
                      onTap: ()=> _openMediaViewer(d['mediaUrl'], true),
                      child: Stack(alignment: Alignment.center, children: [
                        ClipRRect(borderRadius: BorderRadius.circular(10), child: Container(width: 200, height: 280, color: Colors.black, child: Icon(Icons.videocam, color: Colors.white24, size: 40))),
                        Icon(Icons.play_circle_fill, color: Colors.white, size: 55),
                        Positioned(bottom: 8, left: 8, child: Text("Video • Tap to play", style: TextStyle(color: Colors.white, fontSize: 11, backgroundColor: Colors.black54))),
                      ]),
                    )
                    : type=='reel'? GestureDetector(
                      onTap: ()=> _openMediaViewer(d['videoUrl'], true),
                      child: Container(width: 190, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ClipRRect(borderRadius: BorderRadius.circular(10), child: Stack(alignment: Alignment.center, children: [
                          d['thumbnail']!=null && d['thumbnail'].toString().isNotEmpty? CachedNetworkImage(imageUrl: d['thumbnail'], height: 250, width: 190, fit: BoxFit.cover) : Container(height: 250, width: 190, color: Colors.grey[900], child: Icon(Icons.movie, color: Colors.white24, size: 40)),
                          Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
                          Positioned(top: 8, left: 8, child: Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)), child: Text("Reel", style: TextStyle(color: Colors.white, fontSize: 10)))),
                        ])),
                        SizedBox(height: 5),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text(d['caption']?? "🎬 Reel", style: TextStyle(color: Colors.white, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ])),
                    )
                    : Padding(padding: EdgeInsets.all(10), child: Text("Unsupported message", style: TextStyle(color: Colors.white54))),
                  ),
                );
              }
            );
          }
        )),
        if(_sending) Padding(padding: EdgeInsets.all(8), child: Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.pink, strokeWidth: 2)), SizedBox(width: 10), Text("Uploading...", style: TextStyle(color: Colors.white54))])),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Color(0xFF121212),
          child: Row(children: [
            IconButton(icon: Icon(Icons.add_a_photo, color: Colors.pink), onPressed: _showAttachSheet),
            Expanded(child: Container(padding: EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(25)), child: TextField(controller: _msgCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Message...", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none)))),
            SizedBox(width: 6),
            CircleAvatar(backgroundColor: Colors.pink, child: IconButton(icon: Icon(Icons.send, color: Colors.white, size: 18), onPressed: _sendText)),
          ]),
        )
      ]),
    );
  }
}

class MediaViewerPage extends StatefulWidget {
  final String url;
  final bool isVideo;
  const MediaViewerPage({required this.url, required this.isVideo, super.key});
  @override
  State<MediaViewerPage> createState()=> _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage>{
  VideoPlayerController? _ctrl;
  bool _init = false;
  @override
  void initState(){
    super.initState();
    if(widget.isVideo){
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))..initialize().then((_){
        if(mounted){ setState(()=> _init=true); _ctrl!.setLooping(true); _ctrl!.play(); }
      });
    }
  }
  @override
  void dispose(){ _ctrl?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: IconThemeData(color: Colors.white)),
      body: Center(
        child: widget.isVideo? _init && _ctrl!=null? AspectRatio(aspectRatio: _ctrl!.value.aspectRatio, child: VideoPlayer(_ctrl!)) : CircularProgressIndicator(color: Colors.pink)
        : InteractiveViewer(child: CachedNetworkImage(imageUrl: widget.url, fit: BoxFit.contain)),
      ),
    );
  }
}