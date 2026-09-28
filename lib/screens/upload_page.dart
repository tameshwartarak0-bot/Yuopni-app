import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});
  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _file;
  bool _isVideo = false;
  bool _isUploading = false;
  double _progress = 0;

  static const String cloudName = "b7qkm3lk";
  static const String uploadPreset = "yuopni_upload";
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: android);
    _notif.initialize(init);
  }

  Future<void> _updateNotif(double p) async {
    var androidDetails = AndroidNotificationDetails(
      'yuopni_upload', 'Yuopni Uploads',
      channelDescription: 'Upload progress',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: p < 100,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: p.toInt(),
    );
    var details = NotificationDetails(android: androidDetails);
    await _notif.show(0, 'Yuopni Upload', '${p.toStringAsFixed(0)}% ho raha hai...', details);
  }

  Future<void> _pickImage() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xfile != null) setState(() { _file = File(xfile.path); _isVideo = false; });
  }

  Future<void> _pickVideo() async {
    final xfile = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
    if (xfile != null) setState(() { _file = File(xfile.path); _isVideo = true; });
  }

  Future<String> _uploadToCloudinary(File file, bool isVideo, Function(double) onProgress) async {
    Dio dio = Dio();
    FormData formData = FormData.fromMap({
      'upload_preset': uploadPreset,
      'file': await MultipartFile.fromFile(file.path),
    });
    var response = await dio.post(
      "https://api.cloudinary.com/v1_1/$cloudName/${isVideo ? "video" : "image"}/upload",
      data: formData,
      onSendProgress: (sent, total) {
        if (total != 0) {
          double p = sent / total * 100;
          onProgress(p);
          _updateNotif(p);
        }
      },
    );
    return response.data['secure_url'];
  }

  Future<void> _upload() async {
    if (_file == null || _titleCtrl.text.trim().isEmpty) return;
    setState(() { _isUploading = true; _progress = 0; });
    try {
      String url = await _uploadToCloudinary(_file!, _isVideo, (p) {
        if (mounted) setState(() => _progress = p);
      });
      String title = _titleCtrl.text.trim();
      await FirebaseFirestore.instance.collection(_isVideo ? "reels" : "posts").add({
        'uid': FirebaseAuth.instance.currentUser!.uid,
        'title': title,
        'title_search': title.toLowerCase(),
        'title_lower': title.toLowerCase(),
        'description': _descCtrl.text.trim(),
        'mediaUrl': url, 'videoUrl': url, 'imageUrl': url, 'thumbnail': url,
        'isVideo': _isVideo,
        'username': FirebaseAuth.instance.currentUser!.displayName ?? "User",
        'userPhoto': FirebaseAuth.instance.currentUser!.photoURL ?? "",
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [], 'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await _notif.show(0, 'Upload Complete!', '$title upload ho gaya', NotificationDetails(android: AndroidNotificationDetails('yuopni_upload','Yuopni Uploads', importance: Importance.high)));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      await _notif.cancel(0);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
          TextField(controller: _titleCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Title / Tag likho", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, maxLines: 4, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Description likho", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 12),
          Container(height: 180, width: double.infinity, color: Colors.white10, child: _file == null ? Icon(Icons.videocam, size: 60, color: Colors.green) : _isVideo ? Center(child: Text(_file!.path.split('/').last, style: TextStyle(color: Colors.white70))) : Image.file(_file!, fit: BoxFit.cover)),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: OutlinedButton(onPressed: _isUploading? null : _pickImage, child: Text("Photo Chuno"))), SizedBox(width: 10), Expanded(child: OutlinedButton(onPressed: _isUploading? null : _pickVideo, child: Text("Video Chuno")))]),
          const SizedBox(height: 20),
          if (_isUploading) Column(children: [LinearProgressIndicator(value: _progress/100, minHeight: 8), SizedBox(height: 10), Text("${_progress.toStringAsFixed(0)}% Upload ho raha hai...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("Notification bar me bhi dekh sakte ho", style: TextStyle(color: Colors.white54, fontSize: 11))]),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isUploading? null : _upload, child: Text(_isUploading ? "${_progress.toStringAsFixed(0)}%" : "Upload Karo"))),
        ]),
      ),
    );
  }
}