import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text("Abhi koi Post nahi hai", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Create se pehla post upload karo"),
          ]));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (_, i) {
            var data = snapshot.data!.docs[i].data() as Map<String, dynamic>;
            bool isReel = data['type'] == 'reel' || (data['videoUrl']?? '').toString().isNotEmpty;

            return Card(
              margin: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (data['userPhoto']?? '').toString().isNotEmpty? NetworkImage(data['userPhoto']) : null,
                      child: (data['userPhoto']?? '').toString().isEmpty? Icon(Icons.person) : null,
                    ),
                    title: Text(data['username']?? 'Yuopni User', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(data['title']?? ''),
                  ),
                  // Photo ya Video dikhao
                  if (!isReel && (data['imageUrl']?? '').toString().isNotEmpty)
                    Image.network(data['imageUrl'], width: double.infinity, height: 300, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(height: 200, color: Colors.black12, child: Icon(Icons.broken_image))),

                  if (isReel && (data['videoUrl']?? '').toString().isNotEmpty)
                    ReelPlayer(videoUrl: data['videoUrl'], songUrl: data['songUrl']?? ''),

                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(data['caption']?? data['desc']?? '', style: TextStyle(fontSize: 14)),
                  ),
                  if((data['songUrl']?? '').toString().isNotEmpty)
                    Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Row(children: [Icon(Icons.music_note, size: 16), SizedBox(width: 4), Expanded(child: Text(data['songName']?? 'Original Audio', style: TextStyle(fontSize: 12, color: Colors.grey)))])),

                  Divider(),
                  Row(children: [
                    IconButton(icon: Icon(Icons.favorite_border), onPressed: (){}),
                    IconButton(icon: Icon(Icons.chat_bubble_outline), onPressed: (){}),
                    IconButton(icon: Icon(Icons.send), onPressed: (){}),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Reel me video + song ek sath bajane ke liye
class ReelPlayer extends StatefulWidget {
  final String videoUrl;
  final String songUrl;
  ReelPlayer({required this.videoUrl, required this.songUrl});
  @override
  _ReelPlayerState createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  late VideoPlayerController _videoController;
  late AudioPlayer _audioPlayer;

  @override
  void initState(){
    super.initState();
    _videoController = VideoPlayerController.network(widget.videoUrl)..initialize().then((_)=> setState(()=> _videoController.play()));
    _videoController.setLooping(true);
    _audioPlayer = AudioPlayer();
    if(widget.songUrl.isNotEmpty){
      _audioPlayer.setUrl(widget.songUrl).then((_)=> _audioPlayer.play());
      _audioPlayer.setLoopMode(LoopMode.one);
    }
  }
  @override
  void dispose(){
    _videoController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context){
    return _videoController.value.isInitialized? AspectRatio(aspectRatio: _videoController.value.aspectRatio, child: VideoPlayer(_videoController)) : Container(height: 300, child: Center(child: CircularProgressIndicator()));
  }
}