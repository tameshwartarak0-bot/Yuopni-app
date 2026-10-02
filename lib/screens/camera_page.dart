import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'upload_page.dart';
import '../data/songs_data.dart';

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
  double _songStart=0;
  final AudioPlayer _audio = AudioPlayer();
  bool _songPlaying=false;
  VideoPlayerController? _vCtrl;
  String _search = "";

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

  void _startTimer(){ _sec=0; _timer=Timer.periodic(const Duration(seconds:1),(_)=>setState(()=>_sec++)); }
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

  Future<void> _takePhoto() async {
    final f=await _cam!.takePicture();
    setState(()=>_file=f);
  }

  Future<void> _preview() async {
    if(_file==null) return;
    _vCtrl?.dispose();
    _vCtrl=VideoPlayerController.file(File(_file!.path))..initialize().then((_)=>setState((){
      _vCtrl!.setLooping(true); _vCtrl!.play();
      if(_song!="No Song") _playSongWithVideo();
    }));
  }

  // YAHAN FIX KIYA - AB HAR GAANE KI ALAG TUNE BAJEGI
  Future<void> _playSongWithVideo() async {
    int idx = allSongs1000.indexOf(_song);
    String url = getSongUrl(idx < 0? 0 : idx);
    await _audio.stop();
    await _audio.play(UrlSource(url));
    await Future.delayed(const Duration(milliseconds: 300));
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
    List<String> filtered = _search.isEmpty? allSongs1000 : allSongs1000.where((s) => s.toLowerCase().contains(_search.toLowerCase())).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      builder: (_)=> StatefulBuilder(
        builder: (context, setModal) => DraggableScrollableSheet(
        initialChildSize: 0.7, maxChildSize: 0.9, expand: false,
        builder: (context, scroll) => Container(
          padding: const EdgeInsets.all(12),
          child: Column(children:[
              Container(width:40,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(10))),
              const SizedBox(height:10),
              Text("1000 Songs - ${filtered.length} Found", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height:10),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: "Search Hindi / Punjabi...", hintStyle: const TextStyle(color: Colors.white54), prefixIcon: const Icon(Icons.search, color: Colors.white54), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                onChanged: (v){ setModal((){ _search=v; filtered = v.isEmpty? allSongs1000 : allSongs1000.where((s) => s.toLowerCase().contains(v.toLowerCase())).toList(); }); },
              ),
              const SizedBox(height:10),
              if(_song!="No Song") Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                child: Column(children:[
                    Row(children:[const Icon(Icons.music_note,color:Colors.pink), const SizedBox(width:8), Expanded(child:Text(_song,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))), Text("${_songStart.toInt()}s se", style:const TextStyle(color:Colors.pink))]),
                    Slider(value: _songStart, min:0, max:60, divisions:60, activeColor: Colors.pink, onChanged: (v){ setState(()=>_songStart=v); setModal(()=>_songStart=v); _audio.seek(Duration(seconds: v.toInt())); }),
                    const Text("Trimmer - Gaane ka hissa chuno", style: TextStyle(color: Colors.white54, fontSize: 12))
                  ]),
              ),
              const SizedBox(height:10),
              Expanded(child: ListView.builder(
                controller: scroll,
                itemCount: filtered.length,
                itemBuilder: (_,i){
                  bool selected = _song==filtered[i];
                  return ListTile(
                    leading: Icon(Icons.music_note, color: selected?Colors.pink:Colors.white54),
                    title: Text(filtered[i], style: TextStyle(color: selected?Colors.pink:Colors.white)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children:[
                      IconButton(icon: Icon(_songPlaying && selected? Icons.pause:Icons.play_arrow, color: Colors.white), onPressed: () async {
                        if(_songPlaying && selected){
                          await _audio.pause(); setState(()=>_songPlaying=false); setModal(()=>_songPlaying=false);
                        } else {
                          setState(()=>_song=filtered[i]); setModal(()=>_song=filtered[i]);
                          int idx = allSongs1000.indexOf(filtered[i]);
                          String url = getSongUrl(idx);
                          await _audio.stop();
                          await _audio.play(UrlSource(url));
                          await _audio.seek(Duration(seconds: _songStart.toInt()));
                          setState(()=>_songPlaying=true); setModal(()=>_songPlaying=true);
                        }
                      }),
                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: selected?Colors.green:Colors.pink), onPressed: (){ setState(()=>_song=filtered[i]); Navigator.pop(context); if(_file!=null) _playSongWithVideo(); }, child: Text(selected?"Using":"Use")),
                    ]),
                  );
                }
              )),
            ]),
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
        appBar: AppBar(backgroundColor: Colors.black, title: Text("${_vCtrl!=null?_fmt(_vCtrl!.value.position.inSeconds):_fmt(_sec)} - $_song", style: const TextStyle(fontSize: 14))),
        body: Column(children:[
          Expanded(child: _file!.path.endsWith(".mp4")? (_vCtrl?.value.isInitialized==true? Stack(children:[
            VideoPlayer(_vCtrl!),
            Positioned(bottom:10,left:10,right:10,child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
              Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color: Colors.black54,borderRadius:BorderRadius.circular(10)), child: Text("${_fmt(_vCtrl!.value.position.inSeconds)} / ${_fmt(_vCtrl!.value.duration.inSeconds)}", style: const TextStyle(color: Colors.white))),
              Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color: Colors.pink,borderRadius:BorderRadius.circular(10)), child: Row(children:[const Icon(Icons.music_note,size:14,color:Colors.white), const SizedBox(width:4), Flexible(child: Text(_song, style: const TextStyle(color: Colors.white,fontSize:11), overflow: TextOverflow.ellipsis))])),
            ]))
          ]) : const Center(child: CircularProgressIndicator())) : Image.file(File(_file!.path), fit: BoxFit.contain)),
          Padding(padding: const EdgeInsets.all(16), child: Row(children:[
            Expanded(child: OutlinedButton(onPressed: (){ _vCtrl?.dispose(); _audio.stop(); setState(()=>_file=null); }, child: const Text("Retake", style: TextStyle(color: Colors.white)))),
            const SizedBox(width:12),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: (){
              _audio.stop();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> UploadPage(prefile: File(_file!.path), isVideo: true, isLong: _mode=="Video", songName: "$_song @${_songStart.toInt()}s")));
            }, child: const Text("Next"))),
          ]))
        ]),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text("Create $_mode"), actions: [Center(child: Padding(padding: const EdgeInsets.only(right: 8), child: Text(_isRec?"🔴 ${_fmt(_sec)}":_song, style: const TextStyle(color: Colors.pink, fontSize: 12), overflow: TextOverflow.ellipsis))), IconButton(icon: const Icon(Icons.music_note), onPressed: _pickSong)]),
      body: Stack(children:[
        _init? CameraPreview(_cam!) : const Center(child: CircularProgressIndicator()),
        Positioned(top:15,left:0,right:0,child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ["Reel","Video","Story"].map((e)=> GestureDetector(onTap: ()=>setState(()=>_mode=e), child: Container(padding: const EdgeInsets.symmetric(horizontal:18,vertical:8), decoration: BoxDecoration(color: _mode==e?Colors.white:Colors.white24, borderRadius: BorderRadius.circular(8)), child: Text(e, style: TextStyle(color: _mode==e?Colors.black:Colors.white, fontWeight: FontWeight.bold))))).toList())),
        Positioned(bottom:25,left:0,right:0,child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children:[
          GestureDetector(onTap: _pickGallery, child: const Column(children:[Icon(Icons.photo_library, color: Colors.white, size:30), Text("Gallery", style: TextStyle(color: Colors.white))])),
          GestureDetector(
            onLongPress: _mode!="Story"? _toggleRec : null,
            onTap: _mode=="Story"? _takePhoto : _toggleRec,
            child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _isRec?Colors.red:Colors.white, width:4)), child: Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: _isRec?Colors.red:Colors.white, shape: BoxShape.circle), child: Icon(_mode=="Story"?Icons.camera_alt:Icons.videocam, size:32)))),
          GestureDetector(onTap: _pickSong, child: const Column(children:[Icon(Icons.face_retouching_natural, size:30, color: Colors.pinkAccent), Text("Song (1000)", style: TextStyle(color: Colors.white))])),
        ]))
      ]),
    );
  }
}