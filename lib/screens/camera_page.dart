import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/login_dialog.dart';
import '../global.dart';

class CameraPage extends StatefulWidget {
  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCamInit = false;
  XFile? _capturedFile;
  String _selectedMode = "Reel";
  double _beautyLevel = 0;
  String _selectedSong = "No Song Selected";

  final List<Map<String, dynamic>> _beautyFilters = [
    {"name": "Normal", "color": null},
    {"name": "Smooth", "color": [1.1, 0, 0, 0, 0, 0, 1.1, 0, 0, 0, 0, 0, 1.1, 0, 0, 0, 0, 0, 1, 0]},
    {"name": "Fair", "color": [1.2, 0, 0, 0, 10, 0, 1.2, 0, 0, 10, 0, 0, 1.2, 0, 10, 0, 0, 0, 1, 0]},
    {"name": "Bright", "color": [1.3, 0, 0, 0, 0, 0, 1.3, 0, 0, 0, 0, 0, 1.3, 0, 0, 0, 0, 0, 1, 0]},
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
  void initState() {
    super.initState();
    _checkLoginAndInit();
  }

  // FIX 1: Login Check + Only 3 Permissions - Play Store Safe
  Future<void> _checkLoginAndInit() async {
    // Agar login nahi hai to login dialog
    if (FirebaseAuth.instance.currentUser == null &&!isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showDialog(context: context, builder: (_) => LoginDialog());
        if (FirebaseAuth.instance.currentUser == null) {
          if(mounted) Navigator.pop(context); // login nahi kiya to wapas
          return;
        } else {
          _askSafePermissions();
          _initCamera();
        }
      });
    } else {
      _askSafePermissions();
      _initCamera();
    }
  }

  Future<void> _askSafePermissions() async {
    // Sirf jaruri permission - Google reject nahi karega
    await [
      Permission.camera,
      Permission.microphone,
      Permission.photos, // Gallery ke liye bas yahi kafi hai
    ].request();
  }

  Future<void> _initCamera() async {
    try{
      _cameras = await availableCameras();
      if (_cameras!= null && _cameras!.isNotEmpty) {
        _controller = CameraController(_cameras![0], ResolutionPreset.high, enableAudio: true);
        await _controller!.initialize();
        if(mounted) setState(() => _isCamInit = true);
      }
    }catch(e){
      print("Camera error $e");
    }
  }

  Future<void> _pickFromGallery() async {
    if (FirebaseAuth.instance.currentUser == null &&!isLoggedIn) {
      await showDialog(context: context, builder: (_) => LoginDialog());
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file!= null) setState(() => _capturedFile = file);
  }

  Future<void> _takePhoto() async {
    if (FirebaseAuth.instance.currentUser == null &&!isLoggedIn) {
      await showDialog(context: context, builder: (_) => LoginDialog());
      return;
    }
    if (_controller!= null && _controller!.value.isInitialized) {
      final file = await _controller!.takePicture();
      setState(() => _capturedFile = file);
    }
  }

  void _showSongSheet() { /* tumhara wala same rakho - sahi hai */
    showModalBottomSheet(context: context, backgroundColor: Colors.black87, builder: (_) => Container(
      height: 400, padding: EdgeInsets.all(12),
      child: Column(children: [
        Text("Add Music - Pura Song", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        TextField(decoration: InputDecoration(hintText: "Song Search karo...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        SizedBox(height: 10),
        Expanded(child: ListView.builder(itemCount: _songs.length, itemBuilder: (_, i) => ListTile(
          leading: Icon(Icons.music_note, color: Colors.pink),
          title: Text(_songs[i], style: TextStyle(color: Colors.white)),
          trailing: ElevatedButton(onPressed: (){ setState(() => _selectedSong = _songs[i]); Navigator.pop(context); }, child: Text("Use")),
        ))),
      ]),
    ));
  }

  void _showBeautySheet() { /* tumhara wala same */
    showModalBottomSheet(context: context, backgroundColor: Colors.black87, builder: (_) => StatefulBuilder(builder: (context, setM) => Container(
      height: 350, padding: EdgeInsets.all(16),
      child: Column(children: [
        Text("Beauty Filter", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Slider(value: _beautyLevel, min: 0, max: 100, divisions: 10, onChanged: (v){ setM(() => _beautyLevel = v); setState(() => _beautyLevel = v); }),
        SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _beautyFilters.length, itemBuilder: (_, i) => GestureDetector(
          onTap: (){ setM(() => _selectedFilterIndex = i); setState(() => _selectedFilterIndex = i); },
          child: Container(margin: EdgeInsets.all(6), padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: _selectedFilterIndex==i? Colors.pink : Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text(_beautyFilters[i]['name'], style: TextStyle(color: Colors.white))),
        ))),
      ]),
    )));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // tumhara build same hai - bas Next button par upload_page par bhejna hai
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text("Create Camera"), actions: [
          IconButton(icon: Icon(Icons.music_note), onPressed: _showSongSheet),
        ]),
      body: _capturedFile!= null? Stack(children: [
        Center(child: Image.file(File(_capturedFile!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
        Positioned(bottom: 20, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          ElevatedButton(onPressed: () => setState(() => _capturedFile = null), child: Text("Retake")),
          ElevatedButton(
            onPressed: (){
              // FIX 2: Camera se seedha Upload Page par file ke sath
              Navigator.pop(context, {
                'file': File(_capturedFile!.path),
                'isVideo': _selectedMode=="Reel" || _selectedMode=="Video",
                'song': _selectedSong,
                'mode': _selectedMode
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: Text("Next > Post")
          ),
        ]))
      ]) : Stack(
        children: [
          _isCamInit? (_beautyFilters[_selectedFilterIndex]['color'] == null? CameraPreview(_controller!) : ColorFiltered(
            colorFilter: ColorFilter.matrix(List<double>.from(_beautyFilters[_selectedFilterIndex]['color'])),
            child: CameraPreview(_controller!),
          )) : Center(child: CircularProgressIndicator()),
          Positioned(top: 15, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _modeChip("Reel"), _modeChip("Video"), _modeChip("Story"),
          ])),
          Positioned(bottom: 25, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            GestureDetector(onTap: _pickFromGallery, child: Column(children: [Icon(Icons.photo_library, color: Colors.white, size: 30), Text("Gallery", style: TextStyle(color: Colors.white))])),
            GestureDetector(onTap: _takePhoto, child: Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: Container(padding: EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.camera_alt, color: Colors.black, size: 32)))),
            GestureDetector(onTap: _showBeautySheet, child: Column(children: [Icon(Icons.face_retouching_natural, size: 30, color: Colors.pinkAccent), Text("Beauty", style: TextStyle(color: Colors.white))])),
          ])),
        ],
      ),
    );
  }
  Widget _modeChip(String title) {
    bool sel = _selectedMode == title;
    return GestureDetector(onTap: () => setState(() => _selectedMode = title), child: Container(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8), decoration: BoxDecoration(color: sel? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(8)), child: Text(title, style: TextStyle(color: sel? Colors.black : Colors.white, fontWeight: FontWeight.bold))));
  }
}