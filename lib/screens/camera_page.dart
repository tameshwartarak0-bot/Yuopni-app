import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'upload_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cam;
  bool _init = false;
  bool _isRec = false;
  XFile? _file;
  String _mode = "Reel";
  Timer? _timer;
  int _sec = 0;
  String _song = "No Song";
  final _songs = ["Kalaastar - Honey Singh","Chaleya - Jawan","Heeriye - Arijit","Mahiye Jinna Sohna","Apna Bana Le - Bhediya","Tum Kya Mile"];
  VideoPlayerController? _vCtrl;

  @override
  void initState() {
    super.initState();
    _initCamOnce();
  }

  Future<void> _initCamOnce() async {
    var camStatus = await Permission.camera.status;
    var micStatus = await Permission.microphone.status;
    if (camStatus!= PermissionStatus.granted) {
      camStatus = await Permission.camera.request();
    }
    if (micStatus!= PermissionStatus.granted) {
      micStatus = await Permission.microphone.request();
    }
    if (camStatus.isGranted && micStatus.isGranted) {
      final cams = await availableCameras();
      _cam = CameraController(cams[0], ResolutionPreset.high, enableAudio: true);
      await _cam!.initialize();
      if (mounted) setState(() => _init = true);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _startTimer() {
    _sec = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _sec++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final sc = s % 60;
    return "$m:${sc.toString().padLeft(2,'0')}";
  }

  Future<void> _toggleRec() async {
    if (_isRec) {
      final f = await _cam!.stopVideoRecording();
      _stopTimer();
      setState(() {
        _isRec = false;
        _file = f;
      });
      _preview();
    } else {
      await _cam!.startVideoRecording();
      _startTimer();
      setState(() => _isRec = true);
    }
  }

  Future<void> _preview() async {
    if (_file == null) return;
    _vCtrl?.dispose();
    _vCtrl = VideoPlayerController.file(File(_file!.path))
     ..initialize().then((_) {
        setState(() {
          _vCtrl!.setLooping(true);
          _vCtrl!.play();
        });
      });
  }

  Future<void> _pickGallery() async {
    if (await Permission.photos.status!= PermissionStatus.granted) {
      var st = await Permission.photos.request();
      if (st!= PermissionStatus.granted) {
        if (await Permission.storage.status!= PermissionStatus.granted) {
          await Permission.storage.request();
        }
      }
    }
    final p = ImagePicker();
    XFile? f;
    if (_mode!= "Story") {
      f = await p.pickVideo(source: ImageSource.gallery, maxDuration: Duration(minutes: _mode == "Video"? 90 : 15));
    } else {
      f = await p.pickImage(source: ImageSource.gallery);
    }
    if (f!= null) {
      setState(() => _file = f);
      if (f.path.endsWith(".mp4")) _preview();
    }
  }

  void _pickSong() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (_) => Container(
        height: 400,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text("Song Add Karo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _songs.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.pink),
                  title: Text(_songs[i], style: const TextStyle(color: Colors.white)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      setState(() => _song = _songs[i]);
                      Navigator.pop(context);
                    },
                    child: const Text("Use"),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cam?.dispose();
    _vCtrl?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_file!= null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: Text("${_fmt(_vCtrl?.value.duration.inSeconds?? _sec)} - $_song")),
        body: Column(
          children: [
            Expanded(
              child: _file!.path.endsWith(".mp4")
                 ? (_vCtrl?.value.isInitialized == true
                     ? Stack(
                          children: [
                            VideoPlayer(_vCtrl!),
                            Positioned(
                              bottom: 10,
                              left: 10,
                              right: 10,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                                    child: Text("${_fmt(_vCtrl!.value.position.inSeconds)} / ${_fmt(_vCtrl!.value.duration.inSeconds)}", style: const TextStyle(color: Colors.white)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.pink, borderRadius: BorderRadius.circular(10)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.music_note, size: 14, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(_song, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()))
                  : Image.file(File(_file!.path), fit: BoxFit.contain),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1A1A1A),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.pink),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_song, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
                  ElevatedButton(onPressed: _pickSong, style: ElevatedButton.styleFrom(backgroundColor: Colors.pink), child: const Text("Song Add")),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      if (_vCtrl!.value.isPlaying) {
                        _vCtrl!.pause();
                      } else {
                        _vCtrl!.play();
                      }
                      setState(() {});
                    },
                    icon: Icon(_vCtrl?.value.isPlaying == true? Icons.pause : Icons.play_arrow, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () { _vCtrl?.dispose(); setState(() => _file = null); }, child: const Text("Retake", style: TextStyle(color: Colors.white)))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UploadPage(prefile: File(_file!.path), isVideo: true, isLong: _mode == "Video", songName: _song)));
                      },
                      child: const Text("Next - Naam Likho"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("Create $_mode"),
        actions: [
          Center(child: Text(_isRec? "🔴 ${_fmt(_sec)} / ${_mode == "Video"? "90:00" : "15:00"}" : _song, style: const TextStyle(color: Colors.pink))),
          IconButton(icon: const Icon(Icons.music_note), onPressed: _pickSong),
        ],
      ),
      body: Stack(
        children: [
          _init? CameraPreview(_cam!) : const Center(child: CircularProgressIndicator()),
          Positioned(
            top: 15,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ["Reel", "Video", "Story"].map((e) => GestureDetector(
                onTap: () => setState(() => _mode = e),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(color: _mode == e? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: Text(e, style: TextStyle(color: _mode == e? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                ),
              )).toList(),
            ),
          ),
          Positioned(
            bottom: 25,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(onTap: _pickGallery, child: const Column(children: [Icon(Icons.photo_library, color: Colors.white, size: 30), Text("Gallery", style: TextStyle(color: Colors.white))])),
                GestureDetector(
                  onLongPress: _mode!= "Story"? _toggleRec : null,
                  onTap: _mode == "Story"? () async { final f = await _cam!.takePicture(); setState(() => _file = f); } : _toggleRec,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _isRec? Colors.red : Colors.white, width: 4)),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(color: _isRec? Colors.red : Colors.white, shape: BoxShape.circle),
                      child: Icon(_mode == "Story"? Icons.camera_alt : Icons.videocam, size: 32),
                    ),
                  ),
                ),
                GestureDetector(onTap: _pickSong, child: const Column(children: [Icon(Icons.face_retouching_natural, size: 30, color: Colors.pinkAccent), Text("Song", style: TextStyle(color: Colors.white))])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}