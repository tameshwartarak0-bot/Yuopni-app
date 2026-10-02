import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'upload_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});
  @override State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cam;
  bool _init = false, _isRec = false;
  XFile? _file;
  String _mode = "Reel";
  Timer? _timer;
  int _sec = 0;
  String _song = "No Song";
  final _songs = ["Kalaastar - Honey Singh","Chaleya - Jawan","Heeriye - Arijit","Mahiye Jinna Sohna","Apna Bana Le"];

  VideoPlayerController? _vCtrl;
  AudioPlayer _aPlayer = AudioPlayer();

  @override
  void initState(){ super.initState(); _initCam(); }

  Future<void> _initCam() async {
    await [Permission.camera, Permission.microphone, Permission.photos].request();
    final cams = await availableCameras();
    _cam = CameraController(cams[0], ResolutionPreset.high, enableAudio: true);
    await _cam!.initialize();
    setState(() => _init = true);
  }

  void _startTimer(){ _sec=0; _timer=Timer.periodic(const Duration(seconds:1),(_){ setState(()=>_sec++); }); }
  void _stopTimer(){ _timer?.cancel(); }

  Future<void> _record() async {
    if(_isRec){
      final f = await _cam!.stopVideoRecording();
      _stopTimer(); setState((){_isRec=false; _file=f; _previewVideo();});
    }else{
      await _cam!.startVideoRecording();
      _startTimer(); setState(()=>_isRec=true);
    }
  }

  Future<void> _previewVideo() async {
    if(_file==null) return;
    _vCtrl?.dispose();
    _vCtrl = VideoPlayerController.file(File(_file!.path))..initialize().then((_)=>setState((){}));
  }

  Future<void> _pickGallery() async {
    final p = ImagePicker();
    XFile? f;
    if(_mode!="Story") f = await p.pickVideo(source: ImageSource.gallery, maxDuration: Duration(minutes: _mode=="Video"?90:15));
    else f = await p.pickImage(source: ImageSource.gallery);
    if(f!=null){ setState(()=>_file=f); _previewVideo(); }
  }

  void _pickSong(){
    showModalBottomSheet(context: context, backgroundColor: Colors.black87, builder: (_)=> Container(height:400, padding: const EdgeInsets.all(12),
      child: Column(children:[
        const Text("Song Add Karo - Video ke sath bajega", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Expanded(child: ListView.builder(itemCount: _songs.length, itemBuilder: (_,i)=> ListTile(
          leading: const Icon(Icons.music_note, color: Colors.pink),
          title: Text(_songs[i], style: const TextStyle(color: Colors.white)),
          trailing: ElevatedButton(onPressed: (){ setState(()=>_song=_songs[i]); Navigator.pop(context); _playWithSong(); }, child: const Text("Use")),
        )))
      ]),
    ));
  }

  Future<void> _playWithSong() async {
    // Demo ke liye song play - asal me ffmpeg se merge upload_page me hoga
    if(_vCtrl!=null){ _vCtrl!.play(); _vCtrl!.setLooping(true); }
  }

  String _fmt(int s){ final m=s~/60; final sc=s%60; return "$m:${sc.toString().padLeft(2,'0')}"; }

  @override
  void dispose(){ _cam?.dispose(); _vCtrl?.dispose(); _aPlayer.dispose(); _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context){
    if(_file!=null){
      // PREVIEW SCREEN - Yahi chahiye tha tumhe
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: Text(_mode=="Story"?"Preview":"Preview ${_fmt(_vCtrl?.value.duration.inSeconds??_sec)} - $_song")),
        body: Column(children:[
          Expanded(child: _file!.path.endsWith(".mp4")? (_vCtrl?.value.isInitialized==true? Stack(alignment: Alignment.bottomCenter, children:[VideoPlayer(_vCtrl!), Positioned(bottom:10, child: Text(_fmt(_vCtrl!.value.position.inSeconds)+" / "+_fmt(_vCtrl!.value.duration.inSeconds), style: const TextStyle(color: Colors.white, backgroundColor: Colors.black54)))]) : const Center(child: CircularProgressIndicator())) : Image.file(File(_file!.path)) ),
          Container(color: const Color(0xFF1A1A1A), padding: const EdgeInsets.all(12), child: Row(children:[
            const Icon(Icons.music_note, color: Colors.pink), const SizedBox(width:8),
            Expanded(child: Text(_song, style: const TextStyle(color: Colors.white))),
            ElevatedButton(onPressed: _pickSong, style: ElevatedButton.styleFrom(backgroundColor: Colors.pink), child: const Text("Song Add / Change")),
            IconButton(onPressed: _playWithSong, icon: const Icon(Icons.play_arrow, color: Colors.white))
          ])),
          Padding(padding: const EdgeInsets.all(16), child: Row(children:[
            Expanded(child: OutlinedButton(onPressed: (){ _vCtrl?.dispose(); setState(()=>_file=null); }, child: const Text("Retake", style: TextStyle(color: Colors.white)))),
            const SizedBox(width:12),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: (){
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> UploadPage(prefile: File(_file!.path), isVideo: _mode!="Story", isLong: _mode=="Video", songName: _song, videoDuration: _vCtrl?.value.duration.inSeconds??_sec)));
              },
              child: const Text("Next - Title Likho"),
            )),
          ]))
        ]),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("Create"), actions: [Center(child: Text(_isRec? "🔴 ${_fmt(_sec)} / ${_mode=="Video"?"90:00":"15:00"}" : _song, style: const TextStyle(color: Colors.pink))), IconButton(icon: const Icon(Icons.music_note), onPressed: _pickSong)]),
      body: Stack(children:[
        _init? CameraPreview(_cam!) : const Center(child: CircularProgressIndicator()),
        if(_isRec) Positioned(top:20, left:0, right:0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: Text("REC ${_fmt(_sec)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
        Positioned(top:15, left:0, right:0, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ["Reel","Video","Story"].map((e)=> GestureDetector(onTap: ()=>setState(()=>_mode=e), child: Container(padding: const EdgeInsets.symmetric(horizontal:18, vertical:8), decoration: BoxDecoration(color: _mode==e?Colors.white:Colors.white24, borderRadius: BorderRadius.circular(8)), child: Text(e, style: TextStyle(color: _mode==e?Colors.black:Colors.white, fontWeight: FontWeight.bold))))).toList())),
        Positioned(bottom:25, left:0, right:0, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children:[
          GestureDetector(onTap: _pickGallery, child: const Column(children:[Icon(Icons.photo_library, color: Colors.white, size:30), Text("Gallery", style: TextStyle(color: Colors.white))])),
          GestureDetector(onLongPress: _mode!="Story"?_record:null, onTap: _mode=="Story"? () async { final f=await _cam!.takePicture(); setState(()=>_file=f); } : _record, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _isRec?Colors.red:Colors.white, width:4)), child: Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: _isRec?Colors.red:Colors.white, shape: BoxShape.circle), child: Icon(_mode=="Story"?Icons.camera_alt:Icons.videocam, size:32)))),
          GestureDetector(onTap: _pickSong, child: const Column(children:[Icon(Icons.music_note, color: Colors.pink, size:30), Text("Song", style: TextStyle(color: Colors.white))])),
        ]))
      ]),
    );
  }
}