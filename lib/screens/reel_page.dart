import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

class ReelPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reels').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.video_library_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text("Abhi koi Reel nahi hai", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text("Upload karke reel banao", style: TextStyle(color: Colors.grey)),
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

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController _videoController;
  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(widget.data['videoUrl']?? '');
    _audioPlayer = AudioPlayer();

    _videoController.initialize().then((_) {
      setState(()=> _isInitialized = true);
      _videoController.play();
      _videoController.setLooping(true);
    });

    // Song bajane ka fix - Preview wala
    if((widget.data['songUrl']?? '').toString().isNotEmpty){
      _audioPlayer.setUrl(widget.data['songUrl']).then((_) {
        _audioPlayer.setLoopMode(LoopMode.one);
        _audioPlayer.play();
      });
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Video
          Center(
            child: _isInitialized
               ? AspectRatio(aspectRatio: _videoController.value.aspectRatio, child: VideoPlayer(_videoController))
                : CircularProgressIndicator(),
          ),
          // Bottom info - Instagram jaisa
          Positioned(
            bottom: 30, left: 10, right: 60,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("@${widget.data['username']?? 'Yuopni User'}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 6),
              Text(widget.data['caption']?? widget.data['title']?? '', style: TextStyle(color: Colors.white)),
              SizedBox(height: 10),
              Row(children: [
                Icon(Icons.music_note, color: Colors.white, size: 16),
                SizedBox(width: 5),
                Expanded(child: Text(widget.data['songName']?? 'Original Audio - Yuopni', style: TextStyle(color: Colors.white, fontSize: 12))),
              ]),
            ]),
          ),
          // Right side buttons
          Positioned(
            bottom: 30, right: 10,
            child: Column(children: [
              IconButton(icon: Icon(Icons.favorite_border, color: Colors.white, size: 32), onPressed: (){}),
              Text("${(widget.data['likes']?? []).length}", style: TextStyle(color: Colors.white)),
              SizedBox(height: 15),
              IconButton(icon: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28), onPressed: (){}),
              SizedBox(height: 15),
              IconButton(icon: Icon(Icons.send, color: Colors.white, size: 28), onPressed: (){}),
            ]),
          ),
        ],
      ),
    );
  }
}