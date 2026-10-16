import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';

class UploadPage extends StatefulWidget {
  final File? prefile;
  final bool isVideo;
  final bool isLong;
  final String songName;
  final String songUrl;
  const UploadPage({super.key, this.prefile, this.isVideo=false, this.isLong=false, this.songName="No Song", this.songUrl=""});

  @override State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final TextEditingController _captionCtrl = TextEditingController();
  bool _isUploading = false;
  double _progress = 0;

  Future<void> _upload() async {
    if(widget.prefile==null) return;
    setState((){ _isUploading=true; _progress=0.1; });
    try{
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String fileName = "${uid}_${DateTime.now().millisecondsSinceEpoch}.mp4";

      final supabase = Supabase.instance.client;

      // Bucket ka naam check kar - tere Supabase me 'videos' ya 'yuopni' bucket hoga
      // Agar bucket nahi hai to Supabase dashboard > Storage > New Bucket > 'videos' bana le (public)
      await supabase.storage.from('videos').upload(
        fileName, 
        widget.prefile!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false)
      );

      setState(()=> _progress=0.8);
      
      // Public URL lo
      String downloadUrl = supabase.storage.from('videos').getPublicUrl(fileName);

      print("SUPABASE VIDEO URL: $downloadUrl");
      print("SONG: ${widget.songName} URL: ${widget.songUrl}");

      var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      var userData = userDoc.data()?? {};

      await FirebaseFirestore.instance.collection('posts').add({
        'videoUrl': downloadUrl,
        'mediaUrl': downloadUrl, // Dono me same
        'caption': _captionCtrl.text.trim(),
        'songName': widget.songName,
        'songUrl': widget.songUrl,
        'userId': uid,
        'username': userData['username']?? FirebaseAuth.instance.currentUser?.displayName?? 'User',
        'userPhoto': userData['photoUrl']?? FirebaseAuth.instance.currentUser?.photoURL?? '',
        'likes': [],
        'createdAt': FieldValue.serverTimestamp(),
        'isLongVideo': widget.isLong,
      });

      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload ho gaya ✅")));
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_)=> const MainScreen()), (r)=> false);
      }
    }catch(e){
      print("Supabase Upload error $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: $e"), backgroundColor: Colors.red));
      setState(()=> _isUploading=false);
    }
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("New Post", style: TextStyle(color: Colors.white))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if(widget.prefile!=null)
            Container(height: 300, width: double.infinity, color: Colors.grey[900], child: const Icon(Icons.videocam, color: Colors.white, size: 80)),
          const SizedBox(height: 12),
          if(widget.songName!="No Song")
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.pink.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.music_note, color: Colors.pink, size: 16), const SizedBox(width: 6), Expanded(child: Text(widget.songName, style: const TextStyle(color: Colors.pink)))])),
          const SizedBox(height: 12),
          TextField(controller: _captionCtrl, style: const TextStyle(color: Colors.white), maxLines: 3, decoration: InputDecoration(hintText: "Caption likho...", hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          if(_isUploading) Column(children: [LinearProgressIndicator(value: _progress, color: Colors.pink), const SizedBox(height: 8), Text("${(_progress*100).toInt()}% Uploading to Supabase...", style: const TextStyle(color: Colors.white))]),
          const Spacer(),
          SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: _isUploading? null : _upload, child: Text(_isUploading? "Uploading..." : "Post Karo", style: const TextStyle(fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
  }
}