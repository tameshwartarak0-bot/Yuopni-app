import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class LongVideoPage extends StatefulWidget {
  final String videoUrl;
  final String title;
  const LongVideoPage({required this.videoUrl, required this.title, super.key});
  @override
  State<LongVideoPage> createState() => _LongVideoPageState();
}

class _LongVideoPageState extends State<LongVideoPage> {
  late VideoPlayerController _vc;
  ChewieController? _cc;
  @override
  void initState(){
    super.initState();
    _vc = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _vc.initialize().then((_) {
      _cc = ChewieController(
        videoPlayerController: _vc,
        autoPlay: true,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        materialProgressColors: ChewieProgressColors(playedColor: Colors.red, handleColor: Colors.red),
      );
      setState((){});
    });
  }
  @override
  void dispose(){ _vc.dispose(); _cc?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context){
    return Scaffold(backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.title, style: TextStyle(color: Colors.white, fontSize: 14))),
      body: _cc==null ? Center(child: CircularProgressIndicator()) : Chewie(controller: _cc!),
    );
  }
}