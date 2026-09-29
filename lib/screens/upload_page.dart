import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:video_player/video_player.dart';

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
  bool _isLongVideo = false; // Naya add kiya
  bool _isUploading = false;
  double _progress = 0;
  VideoPlayerController? _previewCtrl;

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
    await _notif.show(0, _isLongVideo ? 'Long Video Upload' : 'Yuopni Upload', '${p.toStringAsFixed(0)}% ho raha hai...', details);
  }

  Future<void> _pickImage() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xfile != null) {
      _previewCtrl?.dispose();
      setState(() { _file = File(xfile.path); _isVideo = false; _isLongVideo = false; });
    }
  }

  // Tumhara purana wala Reel - 30 sec only
  Future<void> _pickVideo() async {
    final xfile = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
    if (xfile != null) {
      _file = File(xfile.path);
      _isVideo = true;
      _isLongVideo = false;
      _previewCtrl = VideoPlayerController.file(_file!)..initialize().then((_)=> setState((){}));
      setState(() {});
    }
  }

  // NAYA - Long Video - 4-5 ghanta tak Full Timing
  Future<void> _pickLongVideo() async {
    final xfile = await ImagePicker().pickVideo(source: ImageSource.gallery); // yaha limit nahi hai
    if (xfile != null) {
      _file = File(xfile.path);
      _isVideo = true;
      _isLongVideo = true;
      _previewCtrl = VideoPlayerController.file(_file!)..initialize().then((_)=> setState((){}));
      setState(() {});
    }
  }

  Future<String> _uploadToCloudinary(File file, bool isVideo, Function(double) onProgress) async {
    Dio dio = Dio();
    // Long video ke liye timeout 60 min tak
    dio.options.connectTimeout = Duration(minutes: 60);
    dio.options.receiveTimeout = Duration(minutes: 60);
    dio.options.sendTimeout = Duration(minutes: 60);

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
      
      // Collection decide hoga - Long video alag jayega
      String collectionName = _isLongVideo ? "long_videos" : (_isVideo ? "reels" : "posts");

      await FirebaseFirestore.instance.collection(collectionName).add({
        'uid': FirebaseAuth.instance.currentUser!.uid,
        'title': title,
        'title_search': title.toLowerCase(),
        'title_lower': title.toLowerCase(),
        'description': _descCtrl.text.trim(),
        'mediaUrl': url, 'videoUrl': url, 'imageUrl': url, 
        'thumbnail': _isVideo ? url.replaceAll('.mp4', '.jpg') : url,
        'isVideo': _isVideo,
        'isLongVideo': _isLongVideo,
        'duration': _previewCtrl?.value.duration.inSeconds ?? 0,
        'username': FirebaseAuth.instance.currentUser!.displayName ?? "User",
        'userPhoto': FirebaseAuth.instance.currentUser!.photoURL ?? "",
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [], 'views': 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
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
  void dispose(){
    _previewCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(_isLongVideo ? "Long Video Upload" : "Post / Upload"), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _titleCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Title / Tag likho", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, maxLines: 4, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Description likho", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
          const SizedBox(height: 12),
          Container(height: 200, width: double.infinity, color: Colors.white10, 
            child: _file == null 
            ? Icon(Icons.videocam, size: 60, color: Colors.green) 
            : _isVideo 
              ? (_previewCtrl?.value.isInitialized == true 
                ? Stack(alignment: Alignment.center, children: [AspectRatio(aspectRatio: _previewCtrl!.value.aspectRatio, child: VideoPlayer(_previewCtrl!)), Icon(Icons.play_circle, color: Colors.white70, size: 50), Positioned(bottom: 5, child: Text("${_previewCtrl!.value.duration.inMinutes}:${(_previewCtrl!.value.duration.inSeconds%60).toString().padLeft(2,'0')} ${_isLongVideo? '(Long Video)': '(Reel 30s)'}", style: TextStyle(color: Colors.white, fontSize: 12)))])
                : Center(child: Text(_file!.path.split('/').last, style: TextStyle(color: Colors.white70)))) 
              : Image.file(_file!, fit: BoxFit.cover)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _isUploading? null : _pickImage, child: Text("Photo"))), 
            SizedBox(width: 6), 
            Expanded(child: OutlinedButton(onPressed: _isUploading? null : _pickVideo, style: OutlinedButton.styleFrom(foregroundColor: Colors.pink), child: Text("Reel 30s"))),
            SizedBox(width: 6),
            Expanded(child: OutlinedButton(onPressed: _isUploading? null : _pickLongVideo, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: Text("Long Video"))),
          ]),
          const SizedBox(height: 20),
          if (_isUploading) Column(children: [LinearProgressIndicator(value: _progress/100, minHeight: 8, color: _isLongVideo? Colors.red : Colors.green), SizedBox(height: 10), Text("${_progress.toStringAsFixed(0)}% Upload ho raha hai...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(_isLongVideo? "5 ghante ka video hai to time lagega - background me chalega" : "Notification bar me bhi dekh sakte ho", style: TextStyle(color: Colors.white54, fontSize: 11))]),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isUploading? null : _upload, style: ElevatedButton.styleFrom(backgroundColor: _isLongVideo? Colors.red : Colors.white, foregroundColor: _isLongVideo? Colors.white: Colors.black), child: Text(_isUploading ? "${_progress.toStringAsFixed(0)}%" : "Upload Karo"))),
        ]),
      ),
    );
  }
}