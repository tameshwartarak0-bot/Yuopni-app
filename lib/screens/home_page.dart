import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../screens/upload_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: isUploadingGlobal,
            builder: (_, uploading, __) {
              if (!uploading) return const SizedBox.shrink();
              return ValueListenableBuilder<double>(
                valueListenable: globalUploadProgress,
                builder: (_, p, __) {
                  return Container(
                    color: Colors.green.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cloud_upload, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text("${p.toStringAsFixed(0)}% Upload ho raha hai...", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))),
                            Text("${p.toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: p / 100, minHeight: 4, color: Colors.green, backgroundColor: Colors.white24),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // FIX 1: posts ki jagah reels bhi check karega, dono me se jo milega
              stream: FirebaseFirestore.instance
                 .collection('posts')
                 .orderBy('createdAt', descending: true)
                 .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}\nFirestore Rule check karo", style: TextStyle(color: Colors.white), textAlign: TextAlign.center,));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  // FIX 2: Agar posts khali hai to reels collection se try karo
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('reels').orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snap2){
                      if(!snap2.hasData || snap2.data!.docs.isEmpty){
                        return const Center(child: Text("Abhi koi Post nahi", style: TextStyle(color: Colors.white)));
                      }
                      return _buildList(snap2.data!.docs);
                    },
                  );
                }
                return _buildList(snapshot.data!.docs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs){
    return ListView.builder(
      cacheExtent: 500,
      itemCount: docs.length,
      itemBuilder: (_, i) {
        var data = docs[i].data() as Map<String, dynamic>;
        String mediaUrl = (data['mediaUrl']?? data['imageUrl']?? data['videoUrl']?? '').toString();
        String thumbUrl = (data['thumbnail']?? mediaUrl).toString();
        bool isVideo = data['isVideo'] == true || mediaUrl.contains(".mp4");
        String songName = (data['songName']?? "No Song").toString();
        String duration = (data['durationText']?? "").toString();
        String title = (data['title']?? data['caption']?? '').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.grey[900],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(backgroundImage: (data['userPhoto']?? '').toString().isNotEmpty? NetworkImage(data['userPhoto']) : null),
                ),
                title: Text(data['username']?? 'User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    if (songName!= "No Song")
                      Row(children: [
                        const Icon(Icons.music_note, color: Colors.pink, size: 12),
                        const SizedBox(width: 4),
                        Expanded(child: Text(songName, style: const TextStyle(color: Colors.pink, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                      ]),
                  ],
                ),
              ),
              if (!isVideo && mediaUrl.isNotEmpty)
                CachedNetworkImage(imageUrl: thumbUrl, width: double.infinity, fit: BoxFit.cover),
              if (isVideo) VideoThumbCard(videoUrl: mediaUrl, thumbUrl: thumbUrl, songName: songName, duration: duration),
              Padding(padding: const EdgeInsets.all(10), child: Text(data['description']?? '', style: const TextStyle(color: Colors.white, fontSize: 13))),
            ],
          ),
        );
      },
    );
  }
}

class VideoThumbCard extends StatefulWidget {
  final String videoUrl, thumbUrl, songName, duration;
  const VideoThumbCard({super.key, required this.videoUrl, required this.thumbUrl, this.songName="No Song", this.duration=""});
  @override State<VideoThumbCard> createState() => _VideoThumbCardState();
}

class _VideoThumbCardState extends State<VideoThumbCard> {
  VideoPlayerController? _ctrl;
  AudioPlayer _audio = AudioPlayer();
  bool _playing=false;

  void _play() async {
    if(_playing){
      _ctrl?.pause();
      _audio.pause();
      setState(()=>_playing=false);
      return;
    }
    _ctrl = VideoPlayerController.network(widget.videoUrl);
    await _ctrl!.initialize();
    _ctrl!.setLooping(true);
    _ctrl!.play();
    // Agar song hai to alag se bajao (test ke liye)
    if(widget.songName!="No Song"){
      try{
        await _audio.play(UrlSource("https://commondatastorage.googleapis.com/codeskulptor-assets/week7-bounce.m4a"));
      }catch(e){}
    }
    setState(()=>_playing=true);
  }

  @override void dispose(){ _ctrl?.dispose(); _audio.dispose(); super.dispose(); }

  @override Widget build(BuildContext context){
    if(_playing && _ctrl!=null && _ctrl!.value.isInitialized){
      return GestureDetector(onTap: _play, child: Stack(children:[
        AspectRatio(aspectRatio: _ctrl!.value.aspectRatio, child: VideoPlayer(_ctrl!)),
        Positioned(bottom:8, left:8, right:8, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
          Container(padding: EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)), child: Text("${widget.duration} • ${widget.songName}", style: TextStyle(color: Colors.white, fontSize:10))),
          Icon(Icons.pause_circle, color: Colors.white70),
        ]))
      ]));
    }
    return GestureDetector(onTap: _play, child: Stack(alignment: Alignment.center, children:[
      CachedNetworkImage(imageUrl: widget.thumbUrl, height: 400, width: double.infinity, fit: BoxFit.cover),
      Container(color: Colors.black38, height: 400),
      Icon(Icons.play_circle_fill, size: 70, color: Colors.white70),
      Positioned(bottom:8, left:8, child: Container(padding: EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)), child: Row(children:[
        if(widget.duration.isNotEmpty) Text(widget.duration, style: TextStyle(color: Colors.white, fontSize:12)),
        if(widget.songName!="No Song")...[SizedBox(width:6), Icon(Icons.music_note, color: Colors.pink, size:12), Text(widget.songName, style: TextStyle(color: Colors.pink, fontSize:11))]
      ]))),
    ]));
  }
}