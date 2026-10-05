import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'upload_page.dart';
import '../data/songs_data.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});
  @override State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cam;
  List<CameraDescription> _cameras = [];
  int _selectedCam = 0;
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
  Map<String,String> _cacheUrls = {};

  // Bahut sare iPhone filters
  int _selectedFilter = 1; // Default iPhone filter
  final List<Map<String, dynamic>> _filters = [
    {"name": "Original", "filter": const ColorFilter.mode(Colors.transparent, BlendMode.multiply)},
    {"name": "iPhone", "filter": const ColorFilter.matrix([1.12, 0, 0, 0, 5, 0, 1.08, 0, 0, 8, 0, 0, 1.05, 0, 10, 0, 0, 0, 1, 0])},
    {"name": "Clear", "filter": const ColorFilter.matrix([1.25, 0, 0, 0, 10, 0, 1.25, 0, 0, 10, 0, 0, 1.25, 0, 10, 0, 0, 0, 1, 0])},
    {"name": "Fresh", "filter": const ColorFilter.matrix([1.1, 0, 0, 0, 15, 0, 1.15, 0, 0, 15, 0, 0, 1.1, 0, 20, 0, 0, 0, 1, 0])},
    {"name": "Rosy", "filter": const ColorFilter.matrix([1.15, 0, 0, 0, 12, 0, 1.05, 0, 0, 5, 0, 0, 1.1, 0, 12, 0, 0, 0, 1, 0])},
    {"name": "Bright", "filter": const ColorFilter.matrix([1.2, 0, 0, 0, 20, 0, 1.2, 0, 0, 20, 0, 0, 1.2, 0, 20, 0, 0, 0, 1, 0])},
    {"name": "Natural", "filter": const ColorFilter.matrix([1.05, 0, 0, 0, 3, 0, 1.05, 0, 0, 3, 0, 0, 1.05, 0, 3, 0, 0, 0, 1, 0])},
    {"name": "Cinematic", "filter": const ColorFilter.matrix([1.0, 0, 0, 0, -10, 0, 1.0, 0, 0, -5, 0, 0, 1.1, 0, 0, 0, 0, 0, 1, 0])},
  ];

  @override void initState(){ super.initState(); _initCamOnce(); }

  Future<void> _initCamOnce() async {
    var camStatus = await Permission.camera.status;
    var micStatus = await Permission.microphone.status;
    if(camStatus!=PermissionStatus.granted) camStatus = await Permission.camera.request();
    if(micStatus!=PermissionStatus.granted) micStatus = await Permission.microphone.request();
    if(camStatus.isGranted && micStatus.isGranted){
      _cameras = await availableCameras();
      if(_cameras.isEmpty) return;
      _selectedCam = 0;
      _cam = CameraController(_cameras[_selectedCam], ResolutionPreset.high, enableAudio: true);
      await _cam!.initialize();
      if(mounted) setState(()=>_init=true);
    }
  }

  Future<void> _switchCamera() async {
    if(_cameras.length < 2) return;
    try{
      setState(()=>_init=false);
      _selectedCam = _selectedCam == 0? 1 : 0;
      await _cam?.dispose();
      _cam = CameraController(_cameras[_selectedCam], ResolutionPreset.high, enableAudio: true);
      await _cam!.initialize();
      if(mounted) setState(()=>_init=true);
    }catch(e){ if(mounted) setState(()=>_init=true); }
  }

  void _showBeautyFilters(){
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        height: 140,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width:40,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(10)))),
          const SizedBox(height:12),
          const Text("Beauty Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height:12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (_, i){
                bool sel = _selectedFilter == i;
                return GestureDetector(
                  onTap: (){ setState(()=>_selectedFilter=i); Navigator.pop(context); },
                  child: Container(
                    margin: const EdgeInsets.only(right:10),
                    child: Column(children:[
                      Container(
                        width:60,height:60,
                        decoration: BoxDecoration(
                          color: sel? Colors.pink : Colors.white24,
                          shape: BoxShape.circle,
                          border: Border.all(color: sel? Colors.pinkAccent : Colors.transparent, width:2)
                        ),
                        child: Icon(Icons.face_retouching_natural, color: sel? Colors.white : Colors.white70),
                      ),
                      const SizedBox(height:5),
                      Text(_filters[i]['name'], style: TextStyle(color: sel? Colors.pink : Colors.white70, fontSize:12, fontWeight: sel? FontWeight.bold : FontWeight.normal))
                    ]),
                  ),
                );
              }
            ),
          )
        ]),
      ),
    );
  }

  void _startTimer(){ _sec=0; _timer=Timer.periodic(const Duration(seconds:1),(_){ if(mounted) setState(()=>_sec++); }); }
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
  Future<void> _takePhoto() async { final f=await _cam!.takePicture(); setState(()=>_file=f); }

  Future<String> _getRealUrl(String name) async {
    if(_cacheUrls.containsKey(name)) return _cacheUrls[name]!;
    try{
      final res = await http.get(Uri.parse("https://itunes.apple.com/search?term=${Uri.encodeComponent(name)}&media=music&limit=1&country=in"));
      if(res.statusCode==200){
        final data = jsonDecode(res.body);
        if(data['results']!=null && data['results'].length>0 && data['results'][0]['previewUrl']!=null){
          String url = data['results'][0]['previewUrl'];
          _cacheUrls[name]=url;
          return url;
        }
      }
    }catch(_){}
    return "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
  }

  Future<void> _preview() async {
    if(_file==null) return;
    _vCtrl?.dispose();
    _vCtrl=VideoPlayerController.file(File(_file!.path))..initialize().then((_)=>setState((){
      _vCtrl!.setLooping(true); _vCtrl!.play();
      if(_song!="No Song") _playSongWithVideo();
    }));
  }

  Future<void> _playSongWithVideo() async {
    String url = await _getRealUrl(_song);
    await _audio.stop();
    await _audio.play(UrlSource(url));
    await Future.delayed(const Duration(milliseconds:200));
    await _audio.seek(Duration(seconds: _songStart.toInt()));
    if(mounted) setState(()=>_songPlaying=true);
  }

  Future<void> _pickGallery() async {
    if(await Permission.photos.status!=PermissionStatus.granted){
      await Permission.photos.request();
      if(await Permission.storage.status!=PermissionStatus.granted) await Permission.storage.request();
    }
    final p=ImagePicker();
    XFile? f = _mode!="Story"? await p.pickVideo(source: ImageSource.gallery, maxDuration: Duration(minutes: _mode=="Video"?90:15)) : await p.pickImage(source: ImageSource.gallery);
    if(f!=null){ setState(()=>_file=f); if(f.path.endsWith(".mp4")) _preview(); }
  }

  void _pickSong(){
    List<String> filtered = _search.isEmpty? allSongs1000 : allSongs1000.where((s) => s.toLowerCase().contains(_search.toLowerCase())).toList();
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF111111), isScrollControlled: true,
      builder: (_)=> StatefulBuilder(
        builder: (context, setModal) => DraggableScrollableSheet(
        initialChildSize: 0.7, maxChildSize: 0.9, expand: false,
        builder: (context, scroll) => Container(
          padding: const EdgeInsets.all(12),
          child: Column(children:[
              Container(width:40,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(10))),
              const SizedBox(height:10),
              Text("1000 Real Songs - ${filtered.length} Found", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height:10),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(hintText: "Search...", hintStyle: const TextStyle(color: Colors.white54), prefixIcon: const Icon(Icons.search, color: Colors.white54), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                onChanged: (v){ setModal((){ _search=v; filtered = v.isEmpty? allSongs1000 : allSongs1000.where((s) => s.toLowerCase().contains(v.toLowerCase())).toList(); }); },
              ),
              const SizedBox(height:10),
              Expanded(child: ListView.builder(
                controller: scroll, itemCount: filtered.length,
                itemBuilder: (_,i){
                  bool selected = _song==filtered[i];
                  return ListTile(
                    leading: Icon(Icons.music_note, color: selected?Colors.pink:Colors.white54),
                    title: Text(filtered[i], style: TextStyle(color: selected?Colors.pink:Colors.white)),
                    trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: selected?Colors.green:Colors.pink), onPressed: (){ setState(()=>_song=filtered[i]); Navigator.pop(context); if(_file!=null) _playSongWithVideo(); }, child: Text(selected?"Using":"Use")),
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
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text("${_vCtrl!=null?_fmt(_vCtrl!.value.position.inSeconds):_fmt(_sec)} - $_song", style: const TextStyle(fontSize: 14))),
        body: Column(children:[
          Expanded(child: _file!.path.endsWith(".mp4")? (_vCtrl?.value.isInitialized==true? VideoPlayer(_vCtrl!) : const Center(child: CircularProgressIndicator())) : Image.file(File(_file!.path), fit: BoxFit.contain)),
          Padding(padding: const EdgeInsets.all(16), child: Row(children:[Expanded(child: OutlinedButton(onPressed: (){ _vCtrl?.dispose(); _audio.stop(); setState(()=>_file=null); }, child: const Text("Retake", style: TextStyle(color: Colors.white)))), const SizedBox(width:12), Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: (){ _audio.stop(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> UploadPage(prefile: File(_file!.path), isVideo: true, isLong: _mode=="Video", songName: "$_song @${_songStart.toInt()}s"))); }, child: const Text("Next")))]))
        ]),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, foregroundColor: Colors.white,
        title: Text("Create $_mode"),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: ()=> Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.cameraswitch, color: Colors.white), onPressed: _switchCamera),
          if(_song!="No Song") Center(child: Text(_song, style: const TextStyle(color: Colors.pink, fontSize: 12))),
          IconButton(icon: const Icon(Icons.music_note, color: Colors.white), onPressed: _pickSong)
        ]
      ),
      body: Stack(children:[
        Positioned.fill(
          child: _init? ColorFiltered(
            colorFilter: _filters[_selectedFilter]['filter'],
            child: CameraPreview(_cam!),
          ) : const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        Positioned(top:20,left:0,right:0,child: Row(mainAxisAlignment: MainAxisAlignment.center, children: ["Reel","Video","Story"].map((e)=> GestureDetector(onTap: ()=>setState(()=>_mode=e), child: Container(margin: const EdgeInsets.symmetric(horizontal:5), padding: const EdgeInsets.symmetric(horizontal:18,vertical:8), decoration: BoxDecoration(color: _mode==e?Colors.white:Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text(e, style: TextStyle(color: _mode==e?Colors.black:Colors.white, fontWeight: FontWeight.bold))))).toList())),
        Positioned(bottom:30,left:0,right:0,child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children:[
          GestureDetector(onTap: _pickGallery, child: const Column(children:[Icon(Icons.photo_library, color: Colors.white, size:32), SizedBox(height:4), Text("Gallery", style: TextStyle(color: Colors.white, fontSize:12))])),
          GestureDetector(onTap: _mode=="Story"? _takePhoto : _toggleRec, onLongPress: _mode!="Story"? _toggleRec : null, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _isRec?Colors.red:Colors.white, width:4)), child: Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: _isRec?Colors.red:Colors.white, shape: BoxShape.circle), child: Icon(_mode=="Story"?Icons.camera_alt:Icons.videocam, size:32, color: Colors.black)))),
          // SIRF BEAUTY BUTTON - CLICK PE FILTERS
          GestureDetector(
            onTap: _showBeautyFilters,
            child: Column(children:[
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle, border: Border.all(color: Colors.pink, width:1)), child: const Icon(Icons.face_retouching_natural, color: Colors.white, size:28)),
              const SizedBox(height:4),
              Text(_filters[_selectedFilter]['name'], style: const TextStyle(color: Colors.white, fontSize:12))
            ]),
          ),
        ]))
      ]),
    );
  }
}