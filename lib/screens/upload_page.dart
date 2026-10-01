import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- NAYA ADD KIYA

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});
  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _file;
  bool _isVideo = false;
  bool _isLongVideo = false;
  bool _isUploading = false;
  double _progress = 0;
  VideoPlayerController? _previewCtrl;

  static const String cloudName = "b7qkm3lk";
  static const String uploadPreset = "yuopni_upload";
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();

  // SUPABASE CONFIG - TUMHARA
  static const String supabaseUrl = "https://aynsnbgulloedotmjlcq.supabase.co";
  static const String supabaseKey = "sb_publishable_nFfjqpnLm5FUZD7GbVXlYw_X3vkM_sj";
  static const String bucketName = "yuopni-videos";

  @override
  void initState() {
    super.initState();
    _initNotif();
    // Supabase init ek baar
    try {
      Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    } catch(e) {}
  }

  Future<void> _initNotif() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: android);
    await _notif.initialize(init);
    final androidPlugin = _notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    const channel = AndroidNotificationChannel(
      'yuopni_upload',
      'Yuopni Uploads',
      description: 'Yuopni upload progress',
      importance: Importance.max,
    );
    await androidPlugin?.createNotificationChannel(channel);
  }

  Future<void> _updateNotif(double p) async {
    if (p < 0) p = 0;
    if (p > 100) p = 100;
    final androidDetails = AndroidNotificationDetails(
      'yuopni_upload', 'Yuopni Uploads',
      channelDescription: 'Yuopni upload progress',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: p < 100,
      autoCancel: p >= 100,
      showProgress: true,
      maxProgress: 100,
      progress: p.toInt(),
      onlyAlertOnce: true,
    );
    final details = NotificationDetails(android: androidDetails);
    await _notif.show(0, 'Yuopni Upload - ${p.toStringAsFixed(0)}%', '${p.toStringAsFixed(0)}% ho raha hai...', details);
  }

  Future<void> _pickImage() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xfile != null) {
      _previewCtrl?.dispose();
      _previewCtrl = null;
      setState(() { _file = File(xfile.path); _isVideo = false; _isLongVideo = false; });
    }
  }

  Future<void> _pickVideo() async {
    final xfile = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
    if (xfile != null) {
      _previewCtrl?.dispose();
      _file = File(xfile.path);
      _isVideo = true; _isLongVideo = false;
      _previewCtrl = VideoPlayerController.file(_file!)..initialize().then((_) { if(mounted) setState((){}); });
      setState(() {});
    }
  }

  Future<void> _pickLongVideo() async {
    final xfile = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (xfile != null) {
      _previewCtrl?.dispose();
      _file = File(xfile.path);
      _isVideo = true; _isLongVideo = true;
      _previewCtrl = VideoPlayerController.file(_file!)..initialize().then((_) { if(mounted) setState((){}); });
      setState(() {});
    }
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

  // ===== YEH NAYA HAI - SUPABASE LONG VIDEO UPLOAD =====
  Future<String> _uploadLongToSupabase(File file, Function(double) onProgress) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final fileName = "${uid}_${DateTime.now().millisecondsSinceEpoch}.mp4";
      
      final supabase = Supabase.instance.client;
      
      // Upload
      await supabase.storage.from(bucketName).upload(
        fileName, 
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false)
      );

      // Public URL nikalo
      final String publicUrl = supabase.storage.from(bucketName).getPublicUrl(fileName);
      
      onProgress(100);
      await _updateNotif(100);
      
      return publicUrl;
    } catch (e) {
      throw Exception("Supabase Error: $e");
    }
  }

  Future<void> _upload() async {
    if (_file == null || _titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title aur file dono chahiye")));
      return;
    }
    setState(() { _isUploading = true; _progress = 0; });
    await _updateNotif(0);
    try {
      String url;
      if (_isLongVideo) {
        // AB SUPABASE PE JAYEGA
        url = await _uploadLongToSupabase(_file!, (p) { if(mounted) setState(()=> _progress=p); });
      } else {
        url = await _uploadToCloudinary(_file!, _isVideo, (p) { if(mounted) setState(()=> _progress=p); });
      }

      String title = _titleCtrl.text.trim();
      String collectionName = _isLongVideo ? "long_videos" : (_isVideo ? "reels" : "posts");

      DocumentReference docRef = FirebaseFirestore.instance.collection(collectionName).doc();
      String docId = docRef.id;
      String shareLink = "https://yuopni.com/video?id=$docId&type=$collectionName";

      await docRef.set({
        'uid': FirebaseAuth.instance.currentUser!.uid,
        'title': title,
        'title_search': title.toLowerCase(),
        'title_lower': title.toLowerCase(),
        'description': _descCtrl.text.trim(),
        'mediaUrl': url, 'videoUrl': url, 'imageUrl': url, 'thumbnail': url,
        'isVideo': _isVideo, 'isLongVideo': _isLongVideo,
        'duration': _previewCtrl?.value.duration.inSeconds ?? 0,
        'username': FirebaseAuth.instance.currentUser!.displayName ?? "User",
        'userPhoto': FirebaseAuth.instance.currentUser!.photoURL ?? "",
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [], 'views': 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'docId': docId,
        'shareLink': shareLink,
      });

      await _notif.cancel(0);
      await _notif.show(0, 'Upload Complete!', '$title upload ho gaya', const NotificationDetails(android: AndroidNotificationDetails('yuopni_upload','Yuopni Uploads', importance: Importance.high)));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Upload ho gaya! Share karo"),
          action: SnackBarAction(label: "Share", onPressed: (){
            Share.share("Yuopni pe dekho: $title\n$shareLink");
          }),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      await _notif.cancel(0);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() { _previewCtrl?.dispose(); _titleCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(_isLongVideo ? "Long Video Upload" : "Post / Upload"), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Title / Tag likho", labelStyle: const TextStyle(color: Colors.white54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Description likho", labelStyle: const TextStyle(color: Colors.white54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 12),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
              child: _file == null
                  ? const Icon(Icons.videocam, size: 60, color: Colors.green)
                  : _isVideo
                      ? (_previewCtrl?.value.isInitialized == true
                          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: AspectRatio(aspectRatio: _previewCtrl!.value.aspectRatio, child: VideoPlayer(_previewCtrl!)))
                          : Center(child: Text(_file!.path.split('/').last, style: const TextStyle(color: Colors.white70))))
                      : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_file!, fit: BoxFit.cover, width: double.infinity)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _isUploading ? null : _pickImage, child: const Text("Photo"))),
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton(onPressed: _isUploading ? null : _pickVideo, child: const Text("Reel 30s"))),
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton(onPressed: _isUploading ? null : _pickLongVideo, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text("Long Video"))),
              ],
            ),
            const SizedBox(height: 20),
            if (_isUploading)
              Column(
                children: [
                  LinearProgressIndicator(value: _progress/100, minHeight: 8, color: _isLongVideo ? Colors.red : Colors.green, backgroundColor: Colors.white24),
                  const SizedBox(height: 10),
                  Text("${_progress.toStringAsFixed(0)}% Upload ho raha hai...", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _upload,
                style: ElevatedButton.styleFrom(backgroundColor: _isLongVideo ? Colors.red : Colors.white, foregroundColor: _isLongVideo ? Colors.white : Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_isUploading ? "${_progress.toStringAsFixed(0)}% ..." : "Upload Karo"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}