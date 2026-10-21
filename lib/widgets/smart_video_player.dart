import 'package:flutter/material.dart';
import 'package:cached_video_player/cached_video_player.dart';

class SmartVideoPlayer extends StatefulWidget {
  final String url;
  final String cacheKey;
  const SmartVideoPlayer({super.key, required this.url, required this.cacheKey});

  @override
  State<SmartVideoPlayer> createState() => _SmartVideoPlayerState();
}

class _SmartVideoPlayerState extends State<SmartVideoPlayer> {
  CachedVideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = CachedVideoPlayerController.network(
      widget.url,
      cacheKey: widget.cacheKey, // ek baar download, baar baar data nahi
    )..initialize().then((_) {
        if(mounted){
          _controller!.setLooping(true);
          _controller!.play();
          setState((){});
        }
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if(_controller == null || !_controller!.value.isInitialized){
      return Container(color: Colors.black, child: Center(child: CircularProgressIndicator(color: Colors.white24)));
    }
    return GestureDetector(
      onTap: () => _controller!.value.isPlaying ? _controller!.pause() : _controller!.play(),
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: CachedVideoPlayer(_controller!),
      ),
    );
  }
}