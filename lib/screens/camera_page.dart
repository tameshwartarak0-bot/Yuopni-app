import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // Beauty Filters - Instagram se zyada
  final List<Map<String, dynamic>> _beautyFilters = [
    {"name": "Normal", "color": null},
    {"name": "Smooth", "color": [1.1, 0, 0, 0, 0, 0, 1.1, 0, 0, 0, 0, 0, 1.1, 0, 0, 0, 0, 0, 1, 0]},
    {"name": "Fair", "color": [1.2, 0, 0, 0, 10, 0, 1.2, 0, 0, 10, 0, 0, 1.2, 0, 10, 0, 0, 0, 1, 0]},
    {"name": "Bright", "color": [1.3, 0, 0, 0, 0, 0, 1.3, 0, 0, 0, 0, 0, 1.3, 0, 0, 0, 0, 0, 1, 0]},
    {"name": "Warm", "color": [1.1, 0, 0, 0, 15, 0, 1.0, 0, 0, 5, 0, 0, 0.9, 0, -5, 0, 0, 0, 1, 0]},
    {"name": "Cool", "color": [0.9, 0, 0, 0, -5, 0, 1.0, 0, 0, 5, 0, 0, 1.1, 0, 15, 0, 0, 0, 1, 0]},
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
    _askAllPermissions();
    _initCamera();
  }

  Future<void> _askAllPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.location,
      Permission.notification,
      Permission.contacts,
      Permission.calendar,
      Permission.phone,
    ].request();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras!= null && _cameras!.isNotEmpty) {
      _controller = CameraController(_cameras![0], ResolutionPreset.high, enableAudio: true);
      await _controller!.initialize();
      setState(() => _isCamInit = true);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file!= null) setState(() => _capturedFile = file);
  }

  Future<void> _takePhoto() async {
    if (_controller!= null && _controller!.value.isInitialized) {
      final file = await _controller!.takePicture();
      setState(() => _capturedFile = file);
    }
  }

  void _showSongSheet() {
    showModalBottomSheet(context: context, backgroundColor: Colors.black87, builder: (_) => Container(
      height: 400,
      padding: EdgeInsets.all(12),
      child: Column(children: [
        Text("Add Music - Pura Song", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        TextField(decoration: InputDecoration(hintText: "Song Search karo...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        SizedBox(height: 10),
        Expanded(child: ListView.builder(itemCount: _songs.length, itemBuilder: (_, i) => ListTile(
          leading: Icon(Icons.music_note, color: Colors.pink),
          title: Text(_songs[i]),
          trailing: ElevatedButton(onPressed: (){ setState(() => _selectedSong = _songs[i]); Navigator.pop(context); }, child: Text("Use")),
          onTap: (){ setState(() => _selectedSong = _songs[i]); Navigator.pop(context); },
        ))),
      ]),
    ));
  }

  void _showBeautySheet() {
    showModalBottomSheet(context: context, backgroundColor: Colors.black87, builder: (_) => StatefulBuilder(builder: (context, setM) => Container(
      height: 350,
      padding: EdgeInsets.all(16),
      child: Column(children: [
        Text("Beauty - Instagram se Best", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Slider(value: _beautyLevel, min: 0, max: 100, divisions: 10, label: _beautyLevel.round().toString(), onChanged: (v){ setM(() => _beautyLevel = v); setState(() => _beautyLevel = v); }),
        Text("Smoothness: ${_beautyLevel.toInt()}%"),
        SizedBox(height: 10),
        SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _beautyFilters.length, itemBuilder: (_, i) => GestureDetector(
          onTap: (){ setM(() => _selectedFilterIndex = i); setState(() => _selectedFilterIndex = i); },
          child: Container(margin: EdgeInsets.all(6), padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: _selectedFilterIndex==i? Colors.pink : Colors.white24, borderRadius: BorderRadius.circular(20)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.face), Text(_beautyFilters[i]['name'])])),
        ))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Chip(label: Text("Eye Big"), avatar: Icon(Icons.remove_red_eye)),
          Chip(label: Text("Face Slim"), avatar: Icon(Icons.face_retouching_natural)),
          Chip(label: Text("Whitening"), avatar: Icon(Icons.brightness_5)),
        ])
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("Create Camera"),
        actions: [
          IconButton(icon: Icon(Icons.music_note), onPressed: _showSongSheet),
          IconButton(icon: Icon(Icons.flash_on), onPressed: (){}),
        ],
      ),
      body: _capturedFile!= null? Stack(children: [
        Center(child: Image.file(File(_capturedFile!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
        if(_beautyFilters[_selectedFilterIndex]['color']!= null) Container(color: Colors.white.withOpacity(_beautyLevel/300)),
        Positioned(top: 10, left: 10, child: Container(padding: EdgeInsets.all(8), color: Colors.black54, child: Row(children: [Icon(Icons.music_note, size: 16), SizedBox(width: 5), Text(_selectedSong, style: TextStyle(fontSize: 12))]))),
        Positioned(bottom: 20, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          ElevatedButton(onPressed: () => setState(() => _capturedFile = null), child: Text("Retake")),
          ElevatedButton(onPressed: (){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$_selectedMode Uploaded with Song: $_selectedSong"))); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.pink), child: Text("Next > Post")),
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

          if(_selectedSong!= "No Song Selected") Positioned(top: 70, left: 20, right: 20, child: Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(Icons.music_note, color: Colors.pink, size: 16), SizedBox(width: 5), Expanded(child: Text(_selectedSong, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)))]))),

          Positioned(bottom: 25, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            GestureDetector(onTap: _pickFromGallery, child: Column(children: [Icon(Icons.photo_library, size: 30), SizedBox(height: 4), Text("Gallery"), Text("Storage", style: TextStyle(fontSize: 9, color: Colors.grey))])),
            GestureDetector(onTap: _takePhoto, child: Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: Container(padding: EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.camera_alt, color: Colors.black, size: 32)))),
            GestureDetector(onTap: _showBeautySheet, child: Column(children: [Icon(Icons.face_retouching_natural, size: 30, color: Colors.pinkAccent), SizedBox(height: 4), Text("Beauty"), Text("${_beautyLevel.toInt()}%", style: TextStyle(fontSize: 9, color: Colors.pinkAccent))])),
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