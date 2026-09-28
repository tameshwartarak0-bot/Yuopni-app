import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

class ReelPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // FIX 1: limit(10) - ab sirf 10 reels ayengi, fast
      stream: FirebaseFirestore.instance
         .collection('reels')
         .orderBy('createdAt', descending: true)
         .limit(10)
         .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.video_library_outlined, size: 60, color: Colors.grey),
                SizedBox(height: 10),
                Text("Abhi koi Reel nahi hai",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("Upload karke reel banao",
                    style: TextStyle(color: Colors.grey)),
              ]));
        }

        return PageView.builder(
          itemCount: snapshot.data!.docs.length,
          scrollDirection: Axis.vertical,
          itemBuilder: (_, i) {
            var data = snapshot.data!.docs[i].data() as Map<String, dynamic>;
            return ReelItem(data: data);
          },
        );
      },
    );
  }
}

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> data;
  ReelItem({required this.data});
  @override
  _ReelItemState createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> with AutomaticKeepAlivesClientMixin {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => false; // Page change pe dispose hoga - memory bachega

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() async {
    try {
      // FIX 2: mediaUrl bhi support - tumhara naya upload structure
      String videoUrl = (widget.data['mediaUrl']??
              widget.data['videoUrl']??
              '')
         .toString();

      if (videoUrl.isEmpty) {
        setState(() => _hasError = true);
        return;
      }

      _videoController = VideoPlayerController.network(videoUrl);
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.play();

      setState(() => _isInitialized = true);

      // Song optional hai - agar hai to hi play
      if ((widget.data['songUrl']?? '').toString().isNotEmpty) {
        _audioPlayer = AudioPlayer();
        try {
          await _audioPlayer!.setUrl(widget.data['songUrl']);
          await _audioPlayer!.setLoopMode(LoopMode.one);
          _audioPlayer!.play();
        } catch (e) {
          print("Song error: $e");
        }
      }
    } catch (e) {
      print("Video init error: $e");
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(child: Text("Video load nahi hua", style: TextStyle(color: Colors.white))),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: _isInitialized && _videoController!= null
               ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!))
                : CircularProgressIndicator(color: Colors.white),
          ),
          // Bottom info
          Positioned(
            bottom: 30,
            left: 10,
            right: 60,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("@${widget.data['username']?? 'Yuopni User'}",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  SizedBox(height: 6),
                  Text(
                      widget.data['caption']??
                          widget.data['title']??
                          widget.data['description']??
                          '',
                      style: TextStyle(color: Colors.white)),
                  SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.music_note, color: Colors.white, size: 16),
                    SizedBox(width: 5),
                    Expanded(
                        child: Text(
                            widget.data['songName']?? 'Original Audio - Yuopni',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12))),
                  ]),
                ]),
          ),
          // Right buttons
          Positioned(
            bottom: 30,
            right: 10,
            child: Column(children: [
              IconButton(
                  icon: Icon(Icons.favorite_border,
                      color: Colors.white, size: 32),
                  onPressed: () {}),
              Text("${(widget.data['likes'] is List? widget.data['likes'].length : widget.data['likes']?? 0)}",
                  style: TextStyle(color: Colors.white)),
              SizedBox(height: 15),
              IconButton(
                  icon: Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 28),
                  onPressed: () {}),
              SizedBox(height: 15),
              IconButton(
                  icon: Icon(Icons.send, color: Colors.white, size: 28),
                  onPressed: () {}),
            ]),
          ),
          // Pause / Play tap
          if (_isInitialized)
            GestureDetector(
              onTap: () {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                  _audioPlayer?.pause();
                } else {
                  _videoController!.play();
                  _audioPlayer?.play();
                }
                setState(() {});
              },
              child: Container(color: Colors.transparent),
            ),
        ],
      ),
    );
  }
}