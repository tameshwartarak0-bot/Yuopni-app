import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // FIX 1: limit(15) lagaya - ab sirf 15 post ayenge, fast
      stream: FirebaseFirestore.instance
         .collection('posts')
         .orderBy('createdAt', descending: true)
         .limit(15)
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
                Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                SizedBox(height: 10),
                Text("Abhi koi Post nahi hai",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Create se pehla post upload karo"),
              ]));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (_, i) {
            var data = snapshot.data!.docs[i].data() as Map<String, dynamic>;

            // FIX 2: Tumhare naye upload me field 'mediaUrl' aur 'isVideo' hai, purane me 'imageUrl' / 'videoUrl' tha - dono support
            String mediaUrl = (data['mediaUrl']?? data['imageUrl']?? data['videoUrl']?? '').toString();
            bool isReel = data['isVideo'] == true || data['type'] == 'reel' || (data['videoUrl']?? '').toString().isNotEmpty;

            return Card(
              margin: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (data['userPhoto']?? '').toString().isNotEmpty
                         ? NetworkImage(data['userPhoto'])
                          : null,
                      child: (data['userPhoto']?? '').toString().isEmpty? Icon(Icons.person) : null,
                    ),
                    title: Text(data['username']?? 'Yuopni User',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(data['title']?? ''),
                  ),

                  // FIX 3: CachedNetworkImage - ab dobara download nahi hoga, super fast
                  if (!isReel && mediaUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: mediaUrl,
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(height: 300, child: Center(child: CircularProgressIndicator())),
                      errorWidget: (_, __, ___) => Container(height: 200, color: Colors.black12, child: Icon(Icons.broken_image)),
                    ),

                  // FIX 4: Video ab auto-play nahi hoga list me, tap karne pe hi chalega - isse hang khatam
                  if (isReel && mediaUrl.isNotEmpty)
                    ReelPlayer(videoUrl: mediaUrl, songUrl: data['songUrl']?? ''),

                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(data['caption']?? data['description']?? data['desc']?? '',
                        style: TextStyle(fontSize: 14)),
                  ),
                  if ((data['songUrl']?? '').toString().isNotEmpty)
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Row(children: [
                          Icon(Icons.music_note, size: 16),
                          SizedBox(width: 4),
                          Expanded(
                              child: Text(data['songName']?? 'Original Audio',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)))
                        ])),
                  Divider(),
                  Row(children: [
                    IconButton(icon: Icon(Icons.favorite_border), onPressed: () {}),
                    IconButton(icon: Icon(Icons.chat_bubble_outline), onPressed: () {}),
                    IconButton(icon: Icon(Icons.send), onPressed: () {}),
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

// Reel player ab light-weight - sirf tap pe play
class ReelPlayer extends StatefulWidget {
  final String videoUrl;
  final String songUrl;
  ReelPlayer({required this.videoUrl, required this.songUrl});
  @override
  _ReelPlayerState createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;

  void _initAndPlay() async {
    if (_isPlaying) {
      _videoController?.pause();
      _audioPlayer?.pause();
      setState(() => _isPlaying = false);
      return;
    }
    _videoController = VideoPlayerController.network(widget.videoUrl);
    await _videoController!.initialize();
    _videoController!.setLooping(true);
    _videoController!.play();

    if (widget.songUrl.isNotEmpty) {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setUrl(widget.songUrl);
      _audioPlayer!.setLoopMode(LoopMode.one);
      _audioPlayer!.play();
    }
    setState(() => _isPlaying = true);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoController!= null && _videoController!.value.isInitialized && _isPlaying) {
      return Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!)),
          IconButton(
            icon: Icon(Icons.pause_circle, size: 50, color: Colors.white70),
            onPressed: _initAndPlay,
          )
        ],
      );
    }
    return GestureDetector(
      onTap: _initAndPlay,
      child: Container(
        height: 300,
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.play_circle_fill, size: 60, color: Colors.white),
            Positioned(bottom: 10, child: Text("Tap to play reel", style: TextStyle(color: Colors.white70))),
          ],
        ),
      ),
    );
  }
}