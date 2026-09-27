import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../global.dart';
import '../widgets/login_dialog.dart';

class UploadPage extends StatefulWidget {
  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  File? _file;
  bool _isVideo = false;
  bool _uploading = false;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _songCtrl = TextEditingController();
  final AudioPlayer _player = AudioPlayer();
  String _songUrl = "";
  
  @override
  void initState(){
    super.initState();
    _player.setLoopMode(LoopMode.one);
  }
  
  Future<void> pickFile(bool isVideo) async {
    final picker = ImagePicker();
    final picked = isVideo 
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);
    if(picked != null){
      setState((){
        _file = File(picked.path);
        _isVideo = isVideo;
      });
    }
  }

  Future<void> uploadNow() async {
    if (FirebaseAuth.instance.currentUser == null && !isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Post karne ke liye pehle Login karo")));
      await showDialog(context: context, builder: (_) => LoginDialog());
      return;
    }
    if(_file == null){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pehle Photo/Video select karo")));
      return;
    }

    setState(()=> _uploading = true);
    try{
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final ext = _isVideo ? 'mp4' : 'jpg';
      final folder = _isVideo ? 'reels' : 'posts';
      
      // 1. Storage upload
      final ref = FirebaseStorage.instance.ref().child('$folder/$uid/$id.$ext');
      await ref.putFile(_file!);
      final url = await ref.getDownloadURL();

      // 2. Firestore data - Yahi se Home/Demo/Reel/Profile me ayega
      final postData = {
        'postId': id,
        'uid': uid,
        'username': FirebaseAuth.instance.currentUser!.displayName ?? 'Yuopni User',
        'userPhoto': FirebaseAuth.instance.currentUser!.photoURL ?? '',
        'title': _titleCtrl.text,
        'caption': _descCtrl.text,
        'imageUrl': _isVideo ? '' : url,
        'videoUrl': _isVideo ? url : '',
        'songUrl': _songUrl.isEmpty ? _songCtrl.text : _songUrl,
        'songName': _titleCtrl.text,
        'likes': [],
        'createdAt': FieldValue.serverTimestamp(),
        'type': _isVideo ? 'reel' : 'post',
      };

      // Charo jagah save - Fix for Home + Demo + Profile + Reel
      await FirebaseFirestore.instance.collection('posts').doc(id).set(postData);
      if(_isVideo){
        await FirebaseFirestore.instance.collection('reels').doc(id).set(postData);
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('my_posts').doc(id).set(postData);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Successful! Home aur Demo me check karo")));
      setState((){
        _file = null;
        _titleCtrl.clear();
        _descCtrl.clear();
      });

    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(()=> _uploading = false);
  }

  @override
  void dispose(){
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Post / Upload")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _titleCtrl, decoration: InputDecoration(labelText: "Title / Tag likho", border: OutlineInputBorder())),
          SizedBox(height: 12),
          TextField(controller: _descCtrl, decoration: InputDecoration(labelText: "Description likho", border: OutlineInputBorder()), maxLines: 3),
          SizedBox(height: 12),
          TextField(
            controller: _songCtrl, 
            decoration: InputDecoration(labelText: "Song URL paste karo (Reel ke liye)", border: OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(Icons.play_arrow), onPressed: () async {
              if(_songCtrl.text.isNotEmpty){
                await _player.setUrl(_songCtrl.text);
                _player.play(); // yahi par start karke dekh payega
                setState(()=> _songUrl = _songCtrl.text);
              }
            })),
          ),
          SizedBox(height: 12),
          GestureDetector(
            onTap: ()=> pickFile(false),
            child: Container(height: 150, width: double.infinity, color: Colors.white12, child: _file == null ? Icon(Icons.video_library, size: 50) : _isVideo ? Icon(Icons.videocam, size: 50, color: Colors.green) : Image.file(_file!, fit: BoxFit.cover)),
          ),
          SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: ()=> pickFile(false), child: Text("Photo Chuno"))),
            SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: ()=> pickFile(true), child: Text("Video/Reel Chuno"))),
          ]),
          SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _uploading ? null : uploadNow,
            child: _uploading ? CircularProgressIndicator(color: Colors.white) : Text("Upload Karo")
          )),
        ]),
      ),
    );
  }
}