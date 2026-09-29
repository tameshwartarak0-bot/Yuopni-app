import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoWatchScreen extends StatefulWidget {
  final String videoUrl, title, description;
  const VideoWatchScreen({required this.videoUrl, required this.title, required this.description, super.key});
  @override
  State<VideoWatchScreen> createState() => _VideoWatchScreenState();
}

class _VideoWatchScreenState extends State<VideoWatchScreen> {
  late VideoPlayerController _vpc;
  ChewieController? _chewie;

  @override
  void initState(){
    super.initState();
    _vpc = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _vpc.initialize().then((_){
      _chewie = ChewieController(
        videoPlayerController: _vpc,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: false,
        allowPlaybackSpeedChanging: true,
        materialProgressColors: ChewieProgressColors(playedColor: Colors.red, handleColor: Colors.red, backgroundColor: Colors.white24, bufferedColor: Colors.white38),
      );
      setState((){});
    });
  }
  @override
  void dispose(){ _vpc.dispose(); _chewie?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context){
    return Scaffold(backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text("Yuopni Player")),
      body: Column(children: [
        AspectRatio(aspectRatio: 16/9, child: _chewie==null ? Center(child: CircularProgressIndicator(color: Colors.red)) : Chewie(controller: _chewie!)),
        Expanded(child: ListView(padding: EdgeInsets.all(12), children: [
          Text(widget.title, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(widget.description, style: TextStyle(color: Colors.white70)),
        ])),
      ]),
    );
  }
}