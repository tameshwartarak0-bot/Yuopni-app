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
  bool _hasError = false;
  String _errorMsg = "";

  @override
  void initState(){
    super.initState();
    print("Playing URL: ${widget.videoUrl}"); // Debug ke liye
    _vc = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    
    _vc.initialize().then((_) {
      _cc = ChewieController(
        videoPlayerController: _vc,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControlsOnInitialize: true,
        autoInitialize: true,
        // Instagram jaisa Red progress
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red, 
          handleColor: Colors.red,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.grey
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator(color: Colors.red)),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                Text("Video load nahi hua", style: TextStyle(color: Colors.white)),
                Text(errorMessage, style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          );
        },
      );
      if(mounted) setState((){});
    }).catchError((e){
      setState(() {
        _hasError = true;
        _errorMsg = e.toString();
      });
    });
  }

  @override
  void dispose(){ 
    _vc.dispose(); 
    _cc?.dispose(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, 
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          widget.title, 
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        )
      ),
      body: _hasError 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off, color: Colors.white54, size: 60),
                const SizedBox(height: 12),
                const Text("Video play nahi ho raha", style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_errorMsg, style: const TextStyle(color: Colors.white30, fontSize: 10), textAlign: TextAlign.center),
                ),
              ],
            ),
          )
        : _cc == null 
          ? const Center(child: CircularProgressIndicator(color: Colors.red)) 
          : Column(
              children: [
                AspectRatio(
                  aspectRatio: _vc.value.aspectRatio == 0 ? 16/9 : _vc.value.aspectRatio,
                  child: Chewie(controller: _cc!),
                ),
                // Neeche Title Instagram style
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text("Yuopni • Long Video", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}