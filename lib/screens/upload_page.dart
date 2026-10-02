import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../global.dart'; // FIX: Yahi se % aayega

class UploadPage extends StatefulWidget {
  final File? prefile;
  final bool? isVideo;
  final bool? isLong;
  final String? songName;
  const UploadPage({super.key, this.prefile, this.isVideo, this.isLong, this.songName});
  @override State<UploadPage> createState() => _UploadPageState();
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
  String _song = "No Song";

  static const String cloudName = "b7qkm3lk";
  static const String uploadPreset = "yuopni_upload";
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  static const String bucketName = "yuopni-videos";

  @override
  void initState() {
    super.initState();
    _initNotif();
    if(widget.prefile != null){
      _file = widget.prefile;
      _isVideo = widget.isVideo ?? false;
      _isLongVideo = widget.isLong ?? false;
      _song = widget.songName ?? "No Song";
      if(_isVideo){
        _previewCtrl = VideoPlayerController.file(_file!)..initialize().then((_) { if(mounted) setState(()=>_previewCtrl!.setLooping(true)); });
      }
      _descCtrl.text = _song != "No Song" ? "Song: $_song" : "";
    }
  }

  Future<void> _initNotif() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notif.initialize(const InitializationSettings(android: android));
    final androidPlugin = _notif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel('yuopni_upload','Yuopni Uploads', importance: Importance.max));
  }

  Future<void> _updateNotif(double p) async {
    if (p < 0) p = 0; if (p > 100) p = 100;
    globalUploadProgress.value = p;
    isUploadingGlobal.value = p < 100;
    await _notif.show(0, 'Yuopni Upload - ${p.toStringAsFixed(0)}%', p < 100 ? '${p.toStringAsFixed(0)}% $_song' : 'Upload Complete!', NotificationDetails(android: AndroidNotificationDetails('yuopni_upload','Yuopni Uploads', importance: Importance.max, priority: Priority.high, ongoing: p < 100, autoCancel: p >= 100, showProgress: true, maxProgress: 100, progress: p.toInt(), onlyAlertOnce: true)));
  }

  String _fmt(int sec){ final m = sec ~/ 60; final s = sec % 60; return "$m:${s.toString().padLeft(2,'0')}"; }

  Future<void> _pickImage() async { final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70); if(x!=null){ _previewCtrl?.dispose(); _previewCtrl=null; setState((){ _file=File(x.path); _isVideo=false; _isLongVideo=false; }); } }
  Future<void> _pickVideo() async { final x = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 15)); if(x!=null){ _previewCtrl?.dispose(); _file=File(x.path); _isVideo=true; _isLongVideo=false; _previewCtrl=VideoPlayerController.file(_file!)..initialize().then((_) { if(mounted){ if(_previewCtrl!.value.duration.inMinutes>15){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reel 15 min se zyada nahi"))); setState(()=>_file=null); return; } _previewCtrl!.setLooping(true); setState((){}); } }); setState((){}); } }
  Future<void> _pickLongVideo() async { final x = await ImagePicker().pickVideo(source: ImageSource.gallery); if(x!=null){ _previewCtrl?.dispose(); _file=File(x.path); _isVideo=true; _isLongVideo=true; _previewCtrl=VideoPlayerController.file(_file!)..initialize().then((_) { if(mounted){ if(_previewCtrl!.value.duration.inMinutes>90){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("90 min se zyada nahi"))); setState(()=>_file=null); return; } _previewCtrl!.setLooping(true); setState((){}); } }); setState((){}); } }

  Future<String> _uploadToCloudinary(File file, bool isVideo, Function(double) onProgress) async {
    dio.Dio dioClient = dio.Dio();
    dio.FormData formData = dio.FormData.fromMap({'upload_preset': uploadPreset, 'file': await dio.MultipartFile.fromFile(file.path)});
    var res = await dioClient.post("https://api.cloudinary.com/v1_1/$cloudName/${isVideo ? "video" : "image"}/upload", data: formData, onSendProgress: (s,t){ if(t!=0){ double p=s/t*100; onProgress(p); _updateNotif(p); } });
    return res.data['secure_url'];
  }

  Future<String> _uploadLongToSupabase(File file, Function(double) onProgress) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = "${uid}_${DateTime.now().millisecondsSinceEpoch}.mp4";
    final supa = Supabase.instance.client;
    onProgress(10); await _updateNotif(10);
    await supa.storage.from(bucketName).upload(name, file, fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
    onProgress(90); await _updateNotif(90);
    final url = supa.storage.from(bucketName).getPublicUrl(name);
    onProgress(100); await _updateNotif(100);
    return url;
  }

  Future<void> _upload() async {
    if (_file == null || _titleCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title aur file dono chahiye"))); return; }
    setState((){ _isUploading=true; _progress=0; }); isUploadingGlobal.value=true; await _updateNotif(0);
    try{
      String url; if(_isLongVideo){ url=await _uploadLongToSupabase(_file!, (p){ if(mounted) setState(()=>_progress=p); }); } else { url=await _uploadToCloudinary(_file!, _isVideo, (p){ if(mounted) setState(()=>_progress=p); }); }
      String title=_titleCtrl.text.trim();
      DocumentReference docRef=FirebaseFirestore.instance.collection('posts').doc(); // FIX: Hamesha posts
      String docId=docRef.id; String shareLink="https://yuopni.com/video?id=$docId";
      await docRef.set({
        'uid': FirebaseAuth.instance.currentUser!.uid,
        'title': title, 'title_search': title.toLowerCase(), 'title_lower': title.toLowerCase(),
        'description': _descCtrl.text.trim(), 'songName': _song,
        'mediaUrl': url, 'videoUrl': url, 'imageUrl': url, 'thumbnail': url,
        'isVideo': _isVideo, 'isLongVideo': _isLongVideo,
        'duration': _previewCtrl?.value.duration.inSeconds ?? 0,
        'durationText': _previewCtrl!=null ? _fmt(_previewCtrl!.value.duration.inSeconds) : "0:00",
        'username': FirebaseAuth.instance.currentUser!.displayName ?? "User",
        'userPhoto': FirebaseAuth.instance.currentUser!.photoURL ?? "",
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [], 'views': 0, 'docId': docId, 'shareLink': shareLink,
      });
      await _notif.cancel(0);
      isUploadingGlobal.value=false; globalUploadProgress.value=0;
      if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload ho gaya! $_song"), action: SnackBarAction(label: "Share", onPressed: (){ Share.share("Yuopni pe dekho: $title\n$shareLink"); }))); Navigator.pop(context); }
    }catch(e){ await _notif.cancel(0); isUploadingGlobal.value=false; if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
    finally{ if(mounted) setState(()=>_isUploading=false); }
  }

  @override void dispose(){ _previewCtrl?.dispose(); _titleCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(_isLongVideo ? "Long 90m ${_song!="No Song"?"+ $_song":""}" : "Upload ${_song!="No Song"?"- $_song":""}"), backgroundColor: Colors.black),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children:[
        if(_song!="No Song") Container(width:double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.pink.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.pink)), child: Row(children:[const Icon(Icons.music_note, color: Colors.pink, size:16), const SizedBox(width:6), Expanded(child: Text("$_song ke sath bajega", style: const TextStyle(color: Colors.pink, fontWeight: FontWeight.bold)))])),
        const SizedBox(height:12),
        TextField(controller: _titleCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Title *", labelStyle: const TextStyle(color: Colors.white54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height:12),
        TextField(controller: _descCtrl, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Description + Song", labelStyle: const TextStyle(color: Colors.white54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height:12),
        Container(height: 220, width: double.infinity, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: _file==null ? const Icon(Icons.videocam, size:60, color: Colors.green) : _isVideo ? (_previewCtrl?.value.isInitialized==true ? Stack(alignment: Alignment.center, children:[
          ClipRRect(borderRadius: BorderRadius.circular(12), child: AspectRatio(aspectRatio: _previewCtrl!.value.aspectRatio, child: VideoPlayer(_previewCtrl!))),
          GestureDetector(onTap: (){ setState((){ _previewCtrl!.value.isPlaying ? _previewCtrl!.pause() : _previewCtrl!.play(); }); }, child: Icon(_previewCtrl!.value.isPlaying ? Icons.pause_circle : Icons.play_circle, size:50, color: Colors.white70)),
          Positioned(bottom:8, left:8, right:8, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
            Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)), child: Text("${_fmt(_previewCtrl!.value.position.inSeconds)} / ${_fmt(_previewCtrl!.value.duration.inSeconds)}", style: const TextStyle(color: Colors.white, fontSize:12))),
            Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: Colors.pink, borderRadius: BorderRadius.circular(6)), child: Text(_song, style: const TextStyle(color: Colors.white, fontSize:10))),
          ]))
        ]) : Center(child: Text(_file!.path.split('/').last, style: const TextStyle(color: Colors.white70)))) : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_file!, fit: BoxFit.cover, width: double.infinity))),
        const SizedBox(height:12),
        Row(children:[Expanded(child: OutlinedButton(onPressed: _isUploading?null:_pickImage, child: const Text("Photo"))), const SizedBox(width:6), Expanded(child: OutlinedButton(onPressed: _isUploading?null:_pickVideo, child: const Text("Reel 15m"))), const SizedBox(width:6), Expanded(child: OutlinedButton(onPressed: _isUploading?null:_pickLongVideo, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text("Long 90m")))]),
        const SizedBox(height:20),
        if(_isUploading) Column(children:[LinearProgressIndicator(value: _progress/100, minHeight: 8, color: _isLongVideo?Colors.red:Colors.green, backgroundColor: Colors.white24), const SizedBox(height:10), Text("${_progress.toStringAsFixed(0)}% Upload ho raha hai... $_song", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
        const SizedBox(height:10),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isUploading?null:_upload, style: ElevatedButton.styleFrom(backgroundColor: _isLongVideo?Colors.red:Colors.white, foregroundColor: _isLongVideo?Colors.white:Colors.black, padding: const EdgeInsets.symmetric(vertical:14)), child: Text(_isUploading ? "${_progress.toStringAsFixed(0)}% ..." : "Upload Karo - ${ _song!="No Song"?_song:""}"))),
      ])),
    );
  }
}