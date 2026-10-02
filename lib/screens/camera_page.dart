import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'upload_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});
  @override State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cam;
  bool _init=false,_isRec=false;
  XFile? _file;
  String _mode="Reel";
  Timer? _timer; int _sec=0;
  String _song="No Song";
  double _songStart=0; // song ka kaunsa second se start
  AudioPlayer _audio = AudioPlayer();
  bool _songPlaying=false;
  VideoPlayerController? _vCtrl;

  final _songs = [
    "Kalaastar - Honey Singh","Chaleya - Jawan","Heeriye - Arijit",
    "Mahiye Jinna Sohna","Apna Bana Le - Bhediya","Tum Kya Mile - Rocky",
    "Kesariya - Brahmastra","Besharam Rang - Pathaan","Chaiyya Chaiyya",
    "Senorita - ZNMD","Satranga - Animal","Pehle Bhi Main - Animal",
    "Arjan Vailly - Animal","Lutt Putt Gaya - Dunki","O Maahi - Dunki",
    "Saudebazi - Aakrosh","Tum Se Hi - Jab We Met","Gerua - Dilwale",
    "Malang - Dhoom3","Brown Rang - Honey Singh"
  ];

  // Demo ke liye same mp3 link - baad me tum apna server lagana
  final String demoAudioUrl = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";

  @override void initState(){ super.initState(); _initCamOnce(); }

  Future<void> _initCamOnce() async {
    var camStatus = await Permission.camera.status;
    var micStatus = await Permission.microphone.status;
    if(camStatus!=PermissionStatus.granted) camStatus = await Permission.camera.request();
    if(micStatus!=PermissionStatus.granted) micStatus = await Permission.microphone.request();
    if(camStatus.isGranted && micStatus.isGranted){
      final cams=await availableCameras();
      _cam=CameraController(cams[0], ResolutionPreset.high, enableAudio: true);
      await _cam!.initialize();
      if(mounted) setState(()=>_init=true);
    }
  }

  void _startTimer(){ _sec=0; _timer=Timer.periodic(Duration(seconds:1),(_)=>setState(()=>_sec++)); }
  void _stopTimer()=>_timer?.cancel();
  String _fmt(int s)=> "${s~/60}:${(s%60).toString().padLeft(2,'0')}";

  Future<void> _toggleRec() async {
    if(_isRec){
      final f=await _cam!.stopVideoRecording();
      _stopTimer(); setState((){_isRec=false; _file=f;}); _preview();
    }else{
      await _cam!.startVideoRecording();
      _startTimer(); setState(()=>_isRec=true);
    }
  }

  Future<void> _preview() async {
    if(_file==null) return;
    _vCtrl?.dispose();
    _vCtrl=VideoPlayerController.file(File(_file!.path))..initialize().then((_)=>setState((){
      _vCtrl!.setLooping(true); _vCtrl!.play();
      // Agar song selected hai to video ke saath song bhi bajao
      if(_song!="No Song") _playSongWithVideo();
    }));
  }

  Future<void> _playSongWithVideo() async {
    await _audio.stop();
    await _audio.play(UrlSource(demoAudioUrl));
    await _audio.seek(Duration(seconds: _songStart.toInt()));
    setState(()=>_songPlaying=true);
  }

  Future<void> _pickGallery() async {
    if(await Permission.photos.status!=PermissionStatus.granted){
      await Permission.photos.request();
      if(await Permission.storage.status!=PermissionStatus.granted) await Permission.storage.request();
    }
    final p=ImagePicker();
    XFile? f = _mode!="Story"
     ? await p.pickVideo(source: ImageSource.gallery, maxDuration: Duration(minutes: _mode=="Video"?90:15))
      : await p.pickImage(source: ImageSource.gallery);
    if(f!=null){ setState(()=>_file=f); if(f.path.endsWith(".mp4")) _preview(); }
  }

  void _pickSong(){
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF111111),
      isScrollControlled: true,
      builder: (_)=> DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scroll) => Container(
          padding: EdgeInsets.all(12),
          child: Column(
            children:[
              Container(width:40,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(10))),
              SizedBox(height:10),
              Text("Song Add Karo - Tap karke suno", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height:10),
              // Trim slider
              if(_song!="No Song") Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children:[
                    Row(children:[Icon(Icons.music_note,color:Colors.pink), SizedBox(width:8), Expanded(child:Text(_song,style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold))), Text("${_songStart.toInt()}s se", style:TextStyle(color:Colors.pink))]),
                    Slider(value: _songStart, min:0, max:60, divisions:60, activeColor: Colors.pink, onChanged: (v){ setState(()=>_songStart=v); _audio.seek(Duration(seconds: v.toInt())); }),
                    Text("Video ke hisab se song ka part select karo (0-60 sec)", style: TextStyle(color: Colors.white54, fontSize: 12))
                  ],
                ),
              ),
              SizedBox(height:10),
              Expanded(child: ListView.builder(
                controller: scroll,
                itemCount: _songs.length,
                itemBuilder: (_,i){
                  bool selected = _song==_songs[i];
                  return ListTile(
                    leading: Icon(Icons.music_note, color: selected?Colors.pink:Colors.white54),
                    title: Text(_songs[i], style: TextStyle(color: selected?Colors.pink:Colors.white)),
                    subtitle: Text("Tap to preview", style: TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children:[
                      IconButton(icon: Icon(_songPlaying && selected? Icons.pause:Icons.play_arrow, color: Colors.white), onPressed: () async {
                        if(_songPlaying && selected){
                          await _audio.pause(); setState(()=>_songPlaying=false);
                        }else{
                          setState(()=>_song=_songs[i]);
                          await _audio.play(UrlSource(demoAudioUrl));
                          setState(()=>_songPlaying=true);
                        }
                      }),
                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: selected?Colors.green:Colors.pink), onPressed: (){ setState(()=>_song=_songs[i]); Navigator.pop(context); if(_file!=null) _playSongWithVideo(); }, child: Text(selected?"Using":"Use")),
                    ]),
                  );
                }
              )),
            ]
          ),
        ),
      ),
    );
  }

  @override void dispose(){ _cam?.dispose(); _vCtrl?.dispose(); _timer?.cancel(); _audio.dispose(); super.dispose(); }

  @override Widget build(BuildContext context){
    if(_file!=null){
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: Text("${_vCtrl!=null?_fmt(_vCtrl!.value.position.inSeconds):_fmt(_sec)} - $_song")),
        body: Column(children:[
          Expanded(child: _file!.path.endsWith(".mp4")? (_vCtrl?.value.isInitialized==true? Stack(children:[
            VideoPlayer(_vCtrl!),
            Positioned(bottom:10,left:10,right:10,child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              Container(padding: EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color: Colors.black54,borderRadius:BorderRadius.circular(10)), child: Text("${_fmt(_vCtrl!.value.position.inSeconds)} / ${_fmt(_vCtrl!.value.duration.inSeconds)}", style: TextStyle(color: Colors.white))),
              Container(padding: EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color: Colors.pink,borderRadius:BorderRadius.circular(10)), child: Row(children:[Icon(Icons.music_note,size:14,color:Colors.white), SizedBox(width:4), Text(_song, style: TextStyle(color: Colors.white,fontSize:11))])),
            ]))
          ]) : Center(child: CircularProgressIndicator())) : Image.file(File(_file!.path), fit: BoxFit.contain)),
          Container(padding: EdgeInsets.all(12), color: Color(0xFF1A1A1A), child: Row(children:[
            Icon(Icons.music_note,color:Colors.pink), SizedBox(width:8),
            Expanded(child: Text("$_song (${_songStart.toInt()}s se)", style: TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
            ElevatedButton(onPressed: _pickSong, style: ElevatedButton.styleFrom(backgroundColor: Colors.pink), child: Text("Change Song")),
            IconButton(onPressed: (){ if(_vCtrl!.value.isPlaying){ _vCtrl!.pause(); _audio.pause(); } else { _vCtrl!.play(); if(_song!="No Song") _audio.resume(); } setState((){}); }, icon: Icon(_vCtrl?.value.isPlaying==true?Icons.pause:Icons.play_arrow, color: Colors.white))
          ])),
          Padding(padding: EdgeInsets.all(16), child: Row(children:[
            Expanded(child: OutlinedButton(onPressed: (){ _vCtrl?.dispose(); _audio.stop(); setState(()=>_file=null); }, child: Text("Retake", style: TextStyle(color: Colors.white)))),
            SizedBox(width:12),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: (){
              _audio.stop();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> UploadPage(prefile: File(_file!.path), isVideo: true, isLong: _mode=="Video", songName: "$_song @${_songStart.toInt()}s")));
            }, child: Text("Next - Test OK"))),
          ]))
        ]),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text("Create $_mode"), actions: [Center(child: Text(_isRec?"🔴 ${_fmt(_sec)} / ${_mode=="Video"?"90:00":"15:00"}":_song, style: TextStyle(color: Colors.pink))), IconButton(icon: Icon(Icons.music_note), onPressed: _pickSong)]),
      body: Stack(children:[
        _init? CameraPreview(_cam!) : Center(child: CircularProgressIndicator()),
        Positioned(top:15,left:0,right:0,child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ["Reel","Video","Story"].map((e)=> GestureDetector(onTap: ()=>setState(()=>_mode=e), child: Container(padding: EdgeInsets.symmetric(horizontal:18,vertical:8), decoration: BoxDecoration(color: _mode==e?Colors.white:Colors.white24, borderRadius: BorderRadius.circular(8)), child: Text(e, style: TextStyle(color: _mode==e?Colors.black:Colors.white, fontWeight: FontWeight.bold))))).toList())),
        Positioned(bottom:25,left:0,right:0,child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children:[
          GestureDetector(onTap: _pickGallery, child: Column(children:[Icon(Icons.photo_library, color: Colors.white, size:30), Text("Gallery", style: TextStyle(color: Colors.white))])),
          GestureDetector(onLongPress: _mode!="Story"?_toggleRec:null, onTap: _mode=="Story"? () async { final f=await _cam!.takePicture(); setState(()=>_file=f); } : _toggleRec, child: Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _isRec?Colors.red:Colors.white, width:4)), child: Container(padding: EdgeInsets.all(28), decoration: BoxDecoration(color: _isRec?Colors.red:Colors.white, shape: BoxShape.circle), child: Icon(_mode=="Story"?Icons.camera_alt:Icons.videocam, size:32)))),
          GestureDetector(onTap: _pickSong, child: Column(children:[Icon(Icons.face_retouching_natural, size:30, color: Colors.pinkAccent), Text("Song", style: TextStyle(color: Colors.white))])),
        ]))
      ]),
    );
  }
}