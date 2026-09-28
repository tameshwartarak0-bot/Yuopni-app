import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

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
  double _progress = 0;

  static const String cloudName = "b7qkm3lk";
  static const String uploadPreset = "yuopni_upload";

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70); // 30 se 70 kar diya - quality sahi rahegi aur size kam
    if (xfile != null) setState(() { _file = File(xfile.path); _isVideo = false; });
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final xfile = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
    if (xfile != null) setState(() { _file = File(xfile.path); _isVideo = true; });
  }

  // YAHI MAIN FIX HAI - % KE SATH UPLOAD
  Future<String> _uploadToCloudinary(File file, bool isVideo, Function(double) onProgress) async {
    String type = isVideo ? "video" : "image";
    Dio dio = Dio();
    
    FormData formData = FormData.fromMap({
      'upload_preset': uploadPreset,
      'file': await MultipartFile.fromFile(file.path),
    });

    var response = await dio.post(
      "https://api.cloudinary.com/v1_1/$cloudName/$type/upload",
      data: formData,
      onSendProgress: (int sent, int total) {
        if (total != 0) {
          double p = sent / total * 100;
          onProgress(p);
        }
      },
    );

    if (response.data['secure_url'] == null) throw Exception("Cloudinary error: ${response.data}");
    return response.data['secure_url'];
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

    setState(() { _isUploading = true; _progress = 0; });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      String downloadUrl = await _uploadToCloudinary(_file!, _isVideo, (p) {
        if (mounted) setState(() => _progress = p);
      });

      String collectionName = _isVideo ? "reels" : "posts";

      await FirebaseFirestore.instance.collection(collectionName).add({
        'uid': uid,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'songUrl': _songCtrl.text.trim(),
        'mediaUrl': downloadUrl,
        'videoUrl': downloadUrl,
        'imageUrl': downloadUrl,
        'thumbnail': downloadUrl, // profile me yehi thumbnail ke roop me tez khulega
        'isVideo': _isVideo,
        'username': FirebaseAuth.instance.currentUser!.displayName ?? "User",
        'userPhoto': FirebaseAuth.instance.currentUser!.photoURL ?? "",
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [], // 0 nahi, [] rakho warna like button crash karega
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload Success!")));
        Navigator.pop(context);
      }
    } catch (e) {
      print("Upload error $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() { _isUploading = false; });
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
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.video_file, size: 60, color: Colors.green), Text(_file!.path.split('/').last, style: TextStyle(color: Colors.white70, fontSize: 12))])
                    : Image.file(_file!, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _isUploading? null : _pickImage, child: const Text("Photo Chuno"))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: _isUploading? null : _pickVideo, child: const Text("Video/Reel Chuno"))),
          ]),
          const SizedBox(height: 20),
          if (_isUploading)
            Column(children: [
              LinearProgressIndicator(value: _progress/100, backgroundColor: Colors.white24, color: Colors.purple.shade200),
              const SizedBox(height: 10),
              Text("${_progress.toStringAsFixed(0)}% Upload ho raha hai...", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("App band mat karo, notification me bhi dekh sakte ho", style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 12),
            ]),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _upload,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade200, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _isUploading ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 10), Text("${_progress.toStringAsFixed(0)}%")]) : const Text("Upload Karo", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}