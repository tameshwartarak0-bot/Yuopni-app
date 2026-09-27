import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class UploadPage extends StatefulWidget {
  const UploadPage({super.key});
  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _songCtrl = TextEditingController();
  File? _file;
  bool _isVideo = false;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xfile != null) setState(() { _file = File(xfile.path); _isVideo = false; });
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final xfile = await picker.pickVideo(source: ImageSource.gallery);
    if (xfile != null) setState(() { _file = File(xfile.path); _isVideo = true; });
  }

  Future<void> _upload() async {
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pehle Photo ya Video chuno")));
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title likho")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final time = DateTime.now().millisecondsSinceEpoch;
      final ext = _isVideo ? "mp4" : "jpg";
      final fileName = "$time.$ext";

      // 1. Upload to Storage - Sahi Path
      final ref = FirebaseStorage.instance.ref().child("posts").child(uid).child(fileName);
      await ref.putFile(_file!); // Pehle upload

      // 2. Uske BAAD URL lo - Yehi fix hai
      String downloadUrl = await ref.getDownloadURL();

      // 3. Firestore me save
      String collectionName = _isVideo ? "reels" : "posts";

      await FirebaseFirestore.instance.collection(collectionName).add({
        'uid': uid,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'songUrl': _songCtrl.text.trim(),
        'mediaUrl': downloadUrl, // Ab ye milega
        'fileName': fileName,
        'isVideo': _isVideo,
        'username': FirebaseAuth.instance.currentUser!.displayName ?? "User",
        'userPhoto': FirebaseAuth.instance.currentUser!.photoURL ?? "",
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'timestamp': time,
      });

      // Home ke posts me bhi save (taki home, demo, profile 3 me dikhe)
      await FirebaseFirestore.instance.collection('all_posts').add({
        'uid': uid,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'songUrl': _songCtrl.text.trim(),
        'mediaUrl': downloadUrl,
        'isVideo': _isVideo,
        'username': FirebaseAuth.instance.currentUser!.displayName ?? "User",
        'userPhoto': FirebaseAuth.instance.currentUser!.photoURL ?? "",
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': time,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload Success!")));
        Navigator.pop(context);
      }
    } catch (e) {
      print("Upload error $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Post / Upload"), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _titleCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Title / Tag likho", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Description likho", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 12),
          TextField(controller: _songCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Song URL paste karo (Reel ke liye)", suffixIcon: const Icon(Icons.play_arrow), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 12),
          Container(
            height: 180,
            width: double.infinity,
            color: Colors.white10,
            child: _file == null
                ? const Icon(Icons.videocam, size: 60, color: Colors.green)
                : _isVideo
                    ? const Icon(Icons.video_file, size: 60, color: Colors.green)
                    : Image.file(_file!, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _pickImage, child: const Text("Photo Chuno"))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: _pickVideo, child: const Text("Video/Reel Chuno"))),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _upload,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade200, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _isUploading ? const CircularProgressIndicator() : const Text("Upload Karo"),
            ),
          ),
        ]),
      ),
    );
  }
}