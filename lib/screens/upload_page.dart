import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../global.dart';
import '../data/songs_data.dart';
import 'ar_filter_page.dart';

class UploadPage extends StatefulWidget {
  final File? prefile;
  final bool? isVideo;
  final bool? isLong;
  final String? songName;
  final String? songUrl;
  const UploadPage({super.key, this.prefile, this.isVideo, this.isLong, this.songName, this.songUrl});
  @override State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _file;
  bool _isVideo = false;
  bool _isLongVideo = false;
  bool _isUploading = false;
  bool _isCompressing = false;
  double _progress = 0;
  VideoPlayerController? _previewCtrl;
  String _song = "No Song";
  String _songUrl = "";
  double _startValue = 0.0;
  double _endValue = 0.0;
  bool _showTrimmer = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  static const String cloudName = "b7qkm3lk";
  static const String uploadPreset = "yuopni_upload";
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  static const String bucketName = "videos";

  @override
  void initState() {
    super.initState();
    _initNotif();
    if(widget.prefile!= null){
      _file = widget.prefile;
      _isVideo = widget.isVideo?? false;
      _isLongVideo = widget.isLong?? false;
      _song = widget.songName?? "No Song";
      _songUrl = widget.songUrl?? "";
      if(_isVideo && _file!=null) _loadVideo(_file!);
      _descCtrl.text = _song!= "No Song"? "Song: $_song" : "";
    }
  }

  Future<void> _initNotif() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notif.initialize(const InitializationSettings(android: android));
  }

  Future<void> _updateNotif(double p, String msg) async {
    if (p < 0) p = 0; if (p > 100) p = 100;
    try { globalUploadProgress.value = p; isUploadingGlobal.value = p < 100; } catch(e){}
    await _notif.show(0, 'Yuopni - ${p.toStringAsFixed(0)}% $msg', msg, NotificationDetails(android: AndroidNotificationDetails('yuopni_upload','Yuopni Uploads', importance: Importance.low, ongoing: p < 100, autoCancel: p >= 100, showProgress: true, maxProgress: 100, progress: p.toInt(), onlyAlertOnce: true)));
  }

  Future<File> _compressVideo(File file) async {
    setState(()=> _isCompressing = true);
    await _updateNotif(5, "Compressing video...");
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      if(info!=null && info.path!=null){
        File compressed = File(info.path!);
        debugPrint("Original: ${file.lengthSync()/1024/1024}MB -> Compressed: ${compressed.lengthSync()/1024/1024}MB");
        setState(()=> _isCompressing = false);
        return compressed;
      }
    } catch(e){ debugPrint("Compress error $e"); }
    setState(()=> _isCompressing = false);
    return file;
  }

  // NEW TRIM FUNCTION - ffmpeg_kit_new se
  Future<File> _trimWithFFmpeg(File input, double start, double end) async {
    final dir = await getTemporaryDirectory();
    final outputPath = "${dir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4";
    final duration = end - start;
    // -ss start -t duration
    final command = "-y -i ${input.path} -ss $start -t $duration -c:v mpeg4 -c:a aac $outputPath";
    debugPrint("FFmpeg command: $command");
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      return File(outputPath);
    } else {
      debugPrint("FFmpeg trim failed");
      return input;
    }
  }

  String _fmt(int sec){ final m = sec ~/ 60; final s = sec % 60; return "$m:${s.toString().padLeft(2,'0')}"; }

  Future<void> _loadVideo(File file) async {
    _previewCtrl?.dispose();
    _previewCtrl = VideoPlayerController.file(file);
    await _previewCtrl!.initialize();
    if(mounted){
      if(!_isLongVideo){
        setState((){ 
          _showTrimmer = true; 
          _endValue = _previewCtrl!.value.duration.inSeconds > 30? 30 : _previewCtrl!.value.duration.inSeconds.toDouble(); 
          _startValue = 0;
        });
      }
      _previewCtrl!.setLooping(true);
      _previewCtrl!.play();
      setState((){});
    }
  }

  Future<void> _pickImage() async { final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70); if(x!=null){ _previewCtrl?.dispose(); _previewCtrl=null; setState((){ _file=File(x.path); _isVideo=false; _isLongVideo=false; _showTrimmer=false; }); } }
  Future<void> _pickVideo() async { final x = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 15)); if(x!=null){ File f=File(x.path); setState((){ _file=f; _isVideo=true; _isLongVideo=false; }); await _loadVideo(f); } }
  Future<void> _pickLongVideo() async { final x = await ImagePicker().pickVideo(source: ImageSource.gallery); if(x!=null){ File f=File(x.path); setState((){ _file=f; _isVideo=true; _isLongVideo=true; _showTrimmer=false; }); await _loadVideo(f); } }

  Future<void> _selectSong() async {
    String search = "";
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.black, builder: (_){
      return StatefulBuilder(builder: (c, setM){
        var filtered = allSongs1000.where((s)=> s.toLowerCase().contains(search.toLowerCase())).take(150).toList();
        return Container(height: MediaQuery.of(context).size.height * 0.85, padding: const EdgeInsets.all(12), child: Column(children: [
          Container(width:40,height:5,decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 12),
          TextField(style: const TextStyle(color: Colors.white), decoration: InputDecoration(prefixIcon: const Icon(Icons.search, color: Colors.white54), hintText: "1000 songs me search...", hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), onChanged: (v){ setM(()=> search=v); }),
          const SizedBox(height: 10),
          Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (ctx,i){ var name = filtered[i]; return ListTile(title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)), leading: Icon(name==_song? Icons.radio_button_checked : Icons.radio_button_off, color: Colors.pink), onTap: (){ setState(()=> _song = name); Navigator.pop(context); _audioPlayer.stop(); }); })),
        ]));
      });
    });
  }

  Future<String> _uploadToCloudinary(File file, bool isVideo, Function(double) onProgress) async {
    dio.Dio dioClient = dio.Dio();
    dio.FormData formData = dio.FormData.fromMap({
      'upload_preset': uploadPreset, 
      'file': await dio.MultipartFile.fromFile(file.path),
      'eager': 'q_auto:good,f_auto,w_720',
      'eager_async': 'true',
    });
    var res = await dioClient.post("https://api.cloudinary.com/v1_1/$cloudName/${isVideo? "video" : "image"}/upload", data: formData, onSendProgress: (s,t){ if(t!=0){ double p=s/t*100; onProgress(p); _updateNotif(p, "Uploading..."); } });
    return res.data['secure_url'];
  }

  Future<String> _uploadLongToSupabase(File file, Function(double) onProgress) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = "${uid}_${DateTime.now().millisecondsSinceEpoch}.mp4";
    final supa = Supabase.instance.client;
    onProgress(10); await _updateNotif(10, "Uploading long...");
    await supa.storage.from(bucketName).upload(name, file, fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
    onProgress(90); await _updateNotif(90, "Finalizing...");
    final url = supa.storage.from(bucketName).getPublicUrl(name);
    onProgress(100); await _updateNotif(100, "Done");
    return url;
  }

  Future<void> _upload() async {
    if (_file == null || _titleCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title aur file dono chahiye"))); return; }
    setState((){ _isUploading=true; _progress=0; });
    try{ isUploadingGlobal.value=true; }catch(e){}
    await _updateNotif(0, "Starting...");
    try{
      File fileToUpload = _file!;
      if(_showTrimmer && _isVideo &&!_isLongVideo && _endValue > _startValue){
        await _updateNotif(10, "Trimming...");
        fileToUpload = await _trimWithFFmpeg(fileToUpload, _startValue, _endValue);
      }
      if(_isVideo){
        fileToUpload = await _compressVideo(fileToUpload);
      }

      String url;
      if(_isLongVideo){ url=await _uploadLongToSupabase(fileToUpload, (p){ if(mounted) setState(()=>_progress=p); }); }
      else { url=await _uploadToCloudinary(fileToUpload, _isVideo, (p){ if(mounted) setState(()=>_progress=p); }); }

      String thumbnailUrl = url;
      DocumentReference docRef=FirebaseFirestore.instance.collection('posts').doc();
      String docId=docRef.id;
      await docRef.set({
        'uid': FirebaseAuth.instance.currentUser!.uid, 'title': _titleCtrl.text.trim(), 'title_search': _titleCtrl.text.trim().toLowerCase(), 'title_lower': _titleCtrl.text.trim().toLowerCase(),
        'description': _descCtrl.text.trim(), 'songName': _song, 'songUrl': _songUrl,
        'mediaUrl': url, 'videoUrl': url, 'imageUrl': url, 'thumbnail': thumbnailUrl,
        'isVideo': _isVideo, 'isLongVideo': _isLongVideo,
        'duration': _endValue>0? (_endValue - _startValue).toInt() : _previewCtrl?.value.duration.inSeconds?? 0,
        'username': FirebaseAuth.instance.currentUser!.displayName?? "User", 'userPhoto': FirebaseAuth.instance.currentUser!.photoURL?? "",
        'createdAt': FieldValue.serverTimestamp(), 'timestamp': FieldValue.serverTimestamp(),
        'likes': [], 'views': 0, 'views_count': 0, 'viewsCount': 0, 'likes_count': 0, 'comments_count': 0,
        'docId': docId, 'shareLink': "https://yuopni.com/video?id=$docId", 'type': _isVideo ? 'reel' : 'post',
        'compressed': true, 'quality': '720p',
      });

      await _notif.cancel(0);
      try{ isUploadingGlobal.value=false; globalUploadProgress.value=0; }catch(e){}
      _audioPlayer.stop();
      if(mounted){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload ho gaya! ✅ 70% data bacha"))); Navigator.pop(context); }
    }catch(e){ await _notif.cancel(0); try{ isUploadingGlobal.value=false; }catch(_){} if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
    finally{ if(mounted) setState(()=>_isUploading=false); }
  }

  @override void dispose(){ _previewCtrl?.dispose(); _audioPlayer.dispose(); _titleCtrl.dispose(); _descCtrl.dispose(); VideoCompress.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(_isLongVideo? "Long 90m" : "Upload"), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children:[
        TextField(controller: _titleCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Title *", labelStyle: const TextStyle(color: Colors.white54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height:12),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.music_note, color: Colors.pink), label: Text(_song=="No Song"? "1000 Songs Me Se Add Karo" : "Song: $_song", style: const TextStyle(color: Colors.pink)), onPressed: _selectSong)),
        const SizedBox(height:12),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.face_retouching_natural, color: Colors.cyan), label: const Text("AR Filter Camera 📸", style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.cyan)), onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_) => const ARFilterPage())); })),
        const SizedBox(height:12),
        Container(height: 220, width: double.infinity, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: _file==null? const Icon(Icons.videocam, size:60, color: Colors.green) : _isVideo? (_previewCtrl?.value.isInitialized==true? Stack(alignment: Alignment.center, children:[ClipRRect(borderRadius: BorderRadius.circular(12), child: AspectRatio(aspectRatio: _previewCtrl!.value.aspectRatio, child: VideoPlayer(_previewCtrl!))), GestureDetector(onTap: (){ setState((){ _previewCtrl!.value.isPlaying? _previewCtrl!.pause() : _previewCtrl!.play(); }); }, child: Icon(_previewCtrl!.value.isPlaying? Icons.pause_circle : Icons.play_circle, size:50, color: Colors.white70))]) : Center(child: Text(_file!.path.split('/').last, style: const TextStyle(color: Colors.white70)))) : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_file!, fit: BoxFit.cover, width: double.infinity))),
        const SizedBox(height:12),
        if(_showTrimmer && _previewCtrl!=null) Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Start: ${_fmt(_startValue.toInt())}", style: const TextStyle(color: Colors.white70)),
            Text("End: ${_fmt(_endValue.toInt())} (${_fmt((_endValue-_startValue).toInt())})", style: const TextStyle(color: Colors.white70)),
          ]),
          RangeSlider(
            min: 0,
            max: _previewCtrl!.value.duration.inSeconds.toDouble(),
            divisions: _previewCtrl!.value.duration.inSeconds,
            values: RangeValues(_startValue, _endValue),
            activeColor: Colors.pink,
            onChanged: (v){ setState((){ _startValue=v.start; _endValue=v.end; }); },
          ),
        ]),
        if(_isCompressing) const Column(children:[LinearProgressIndicator(color: Colors.cyan), SizedBox(height:8), Text("Video ko compress kar rahe hai... 70% data bachega", style: TextStyle(color: Colors.cyan))]),
        Row(children:[
          Expanded(child: OutlinedButton(onPressed: _isUploading?null:_pickImage, child: const Text("Photo"))),
          const SizedBox(width:6),
          Expanded(child: OutlinedButton(onPressed: _isUploading?null:_pickVideo, child: const Text("Reel 15m"))),
          const SizedBox(width:6),
          Expanded(child: OutlinedButton(onPressed: _isUploading?null:_pickLongVideo, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text("Long 90m"))),
        ]),
        const SizedBox(height:20),
        if(_isUploading) Column(children:[LinearProgressIndicator(value: _progress/100, minHeight: 8, color: _isLongVideo?Colors.red:Colors.green, backgroundColor: Colors.white24), const SizedBox(height:10), Text("${_progress.toStringAsFixed(0)}% Upload ho raha hai...", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
        const SizedBox(height:10),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isUploading?null:_upload, style: ElevatedButton.styleFrom(backgroundColor: _isLongVideo?Colors.red:Colors.white, foregroundColor: _isLongVideo?Colors.white:Colors.black, padding: const EdgeInsets.symmetric(vertical:14)), child: Text(_isUploading? "${_progress.toStringAsFixed(0)}%..." : "Upload Karo"))),
      ])),
    );
  }
}