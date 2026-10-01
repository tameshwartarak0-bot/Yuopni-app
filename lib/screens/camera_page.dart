import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/login_dialog.dart';
import '../global.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCamInit = false;
  bool _isRecording = false;
  XFile? _capturedFile;
  String _selectedMode = "Reel"; // Reel, Video, Story
  double _beautyLevel = 0;
  String _selectedSong = "No Song Selected";

  final List<Map<String, dynamic>> _beautyFilters = [
    {"name": "Normal", "color": null},
    {"name": "Smooth", "color": [1.1, 0, 0, 0, 0, 0, 1.1, 0, 0, 0, 0, 0, 1.1, 0, 0, 0, 0, 0, 1, 0]},
    {"name": "Fair", "color": [1.2, 0, 0, 0, 10, 0, 1.2, 0, 0, 10, 0, 0, 1.2, 0, 10, 0, 0, 0, 1, 0]},
  ];
  int _selectedFilterIndex = 0;

  final List<String> _songs = [
    "Kalaastar - Yo Yo Honey Singh",
    "Chaleya - Jawan",
    "Heeriye - Arijit Singh",
    "Mahiye Jinna Sohna - Darshan Raval",
    "Apna Bana Le - Bhediya",
    "Tum Kya Mile - Rocky Rani",
  ];

  @override
  void initState() { super.initState(); _checkLoginAndInit(); }

  Future<void> _checkLoginAndInit() async {
    if (FirebaseAuth.instance.currentUser == null &&!isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showDialog(context: context, builder: (_) => LoginDialog());
        if (FirebaseAuth.instance.currentUser == null) { if(mounted) Navigator.pop(context); return; }
        else { _askSafePermissions(); _initCamera(); }
      });
    } else { _askSafePermissions(); _initCamera(); }
  }

  Future<void> _askSafePermissions() async {
    await [Permission.camera, Permission.microphone, Permission.photos].request();
  }

  Future<void> _initCamera() async {
    try{
      _cameras = await availableCameras();
      if (_cameras!= null && _cameras!.isNotEmpty) {
        _controller = CameraController(_cameras![0], ResolutionPreset.high, enableAudio: true);
        await _controller!.initialize();
        if(mounted) setState(() => _isCamInit = true);
      }
    }catch(e){ debugPrint("Camera error $e"); }
  }

  // FIX: Gallery se Reel/Video bhi pick hoga
  Future<void> _pickFromGallery() async {
    if (FirebaseAuth.instance.currentUser == null &&!isLoggedIn) {
      await showDialog(context: context, builder: (_) => LoginDialog()); return;
    }
    final picker = ImagePicker();
    XFile? file;
    if(_selectedMode == "Reel" || _selectedMode == "Video"){
      file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: _selectedMode == "Video"? const Duration(minutes: 90) : const Duration(minutes: 15));
    } else {
      file = await picker.pickImage(source: ImageSource.gallery);
    }
    if (file!= null) setState(() => _capturedFile = file);
  }

  Future<void> _takePhoto() async {
    if (_controller!= null && _controller!.value.isInitialized &&!_isRecording) {
      final file = await _controller!.takePicture();
      setState(() => _capturedFile = file);
    }
  }

  Future<void> _toggleRecord() async {
    if(_controller == null) return;
    if(_isRecording){
      final file = await _controller!.stopVideoRecording();
      setState(() { _isRecording = false; _capturedFile = file; });
    } else {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    }
  }

  void _showSongSheet() {
    showModalBottomSheet(context: context, backgroundColor: Colors.black87, builder: (_) => Container(
      height: 400, padding: const EdgeInsets.all(12),
      child: Column(children: [
        const Text("Add Music - Pura Song", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Expanded(child: ListView.builder(itemCount: _songs.length, itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.music_note, color: Colors.pink),
          title: Text(_songs[i], style: const TextStyle(color: Colors.white)),
          trailing: ElevatedButton(onPressed: (){ setState(() => _selectedSong = _songs[i]); Navigator.pop(context); }, child: const Text("Use")),
        ))),
      ]),
    ));
  }

  void _showBeautySheet() {
    showModalBottomSheet(context: context, backgroundColor: Colors.black87, builder: (_) => StatefulBuilder(builder: (context, setM) => Container(
      height: 350, padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Text("Beauty Filter", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Slider(value: _beautyLevel, min: 0, max: 100, divisions: 10, onChanged: (v){ setM(() => _beautyLevel = v); setState(() => _beautyLevel = v); }),
        SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _beautyFilters.length, itemBuilder: (_, i) => GestureDetector(
          onTap: (){ setM(() => _selectedFilterIndex = i); setState(() => _selectedFilterIndex = i); },
          child: Container(margin: const EdgeInsets.all(6), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: _selectedFilterIndex==i? Colors.pink : Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text(_beautyFilters[i]['name'], style: const TextStyle(color: Colors.white))),
        ))),
      ]),
    )));
  }

  @override
  void dispose() { _controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("Create Camera"), actions: [
          Center(child: Text(_selectedSong, style: const TextStyle(color: Colors.pink, fontSize: 12), overflow: TextOverflow.ellipsis)),
          IconButton(icon: const Icon(Icons.music_note), onPressed: _showSongSheet),
        ]),
      body: _capturedFile!= null? Stack(children: [
        Center(child: _capturedFile!.path.endsWith(".mp4")? const Icon(Icons.videocam, size: 100, color: Colors.white) : Image.file(File(_capturedFile!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
        Positioned(bottom: 20, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          ElevatedButton(onPressed: () => setState(() => _capturedFile = null), child: const Text("Retake")),
          ElevatedButton(
            onPressed: (){
              Navigator.pop(context, {
                'file': File(_capturedFile!.path),
                'isVideo': _selectedMode=="Reel" || _selectedMode=="Video",
                'isLong': _selectedMode=="Video",
                'song': _selectedSong,
                'mode': _selectedMode
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text("Next > Post")
          ),
        ]))
      ]) : Stack(
        children: [
          _isCamInit? (_beautyFilters[_selectedFilterIndex]['color'] == null? CameraPreview(_controller!) : ColorFiltered(
            colorFilter: ColorFilter.matrix(List<double>.from(_beautyFilters[_selectedFilterIndex]['color'])),
            child: CameraPreview(_controller!),
          )) : const Center(child: CircularProgressIndicator()),
          if(_isRecording) const Positioned(top: 50, left: 0, right: 0, child: Center(child: Text("🔴 Recording...", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
          Positioned(top: 15, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _modeChip("Reel"), _modeChip("Video"), _modeChip("Story"),
          ])),
          Positioned(bottom: 25, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            GestureDetector(onTap: _pickFromGallery, child: const Column(children: [Icon(Icons.photo_library, color: Colors.white, size: 30), Text("Gallery", style: TextStyle(color: Colors.white))])),
            GestureDetector(
              onLongPress: _selectedMode!= "Story"? _toggleRecord : null,
              onTap: _selectedMode == "Story"? _takePhoto : _toggleRecord,
              child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _isRecording? Colors.red : Colors.white, width: 4)), child: Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: _isRecording? Colors.red : Colors.white, shape: BoxShape.circle), child: Icon(_selectedMode == "Story"? Icons.camera_alt : Icons.videocam, color: Colors.black, size: 32)))),
            GestureDetector(onTap: _showBeautySheet, child: const Column(children: [Icon(Icons.face_retouching_natural, size: 30, color: Colors.pinkAccent), Text("Beauty", style: TextStyle(color: Colors.white))])),
          ])),
        ],
      ),
    );
  }
  Widget _modeChip(String title) {
    bool sel = _selectedMode == title;
    return GestureDetector(onTap: () => setState(() => _selectedMode = title), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), decoration: BoxDecoration(color: sel? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(8)), child: Text(title, style: TextStyle(color: sel? Colors.black : Colors.white, fontWeight: FontWeight.bold))));
  }
}