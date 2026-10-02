import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../global.dart';

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
              stream: FirebaseFirestore.instance.collection('posts').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white), textAlign: TextAlign.center));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Abhi koi Post nahi", style: TextStyle(color: Colors.white)));
                }

                var docs = snapshot.data!.docs.toList();
                docs.sort((a,b){
                  var da = (a.data() as Map<String,dynamic>);
                  var db = (b.data() as Map<String,dynamic>);
                  Timestamp? ta = da['createdAt'] is Timestamp ? da['createdAt'] : da['timestamp'] is Timestamp ? da['timestamp'] : null;
                  Timestamp? tb = db['createdAt'] is Timestamp ? db['createdAt'] : db['timestamp'] is Timestamp ? db['timestamp'] : null;
                  if(ta==null && tb==null) return 0;
                  if(ta==null) return 1;
                  if(tb==null) return -1;
                  return tb.compareTo(ta);
                });

                return _buildList(docs);
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
        bool isVideo = data['isVideo'] == true || mediaUrl.toLowerCase().contains(".mp4");
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
                leading: CircleAvatar(
                  backgroundImage: (data['userPhoto']?? '').toString().isNotEmpty? NetworkImage(data['userPhoto']) : null,
                  child: (data['userPhoto']?? '').toString().isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(data['username']?? 'User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              if (!isVideo && mediaUrl.isNotEmpty)
                CachedNetworkImage(imageUrl: mediaUrl, width: double.infinity, fit: BoxFit.cover, placeholder: (_,__)=> Container(height:200,color: Colors.black12), errorWidget: (_,__,___)=> const Icon(Icons.broken_image, color: Colors.white)),
              if (isVideo) VideoThumbCard(videoUrl: mediaUrl, thumbUrl: thumbUrl, songName: songName, duration: duration),
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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAndPlay();
  }

  Future<void> _initializeAndPlay() async {
    try {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _ctrl!.initialize();
      await _ctrl!.setLooping(true);
      await _ctrl!.setVolume(1.0);
      await _ctrl!.play();
      if(mounted) setState(()=> _isInitialized = true);
    } catch (e) {
      debugPrint("Video Error: $e");
    }
  }

  @override
  void dispose(){ _ctrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context){
    if(_isInitialized && _ctrl!=null){
      return GestureDetector(
        onTap: (){
          if(_ctrl!.value.isPlaying){
            _ctrl!.pause();
          } else {
            _ctrl!.play();
          }
          setState((){});
        },
        child: Stack(alignment: Alignment.center, children:[
          AspectRatio(aspectRatio: _ctrl!.value.aspectRatio, child: VideoPlayer(_ctrl!)),
          if(!_ctrl!.value.isPlaying)
            const Icon(Icons.play_circle_fill, size: 70, color: Colors.white70),
          // Song info - only show if real song
          if(widget.songName != "No Song" && widget.songName.isNotEmpty)
            Positioned(bottom:8, left:8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), 
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)), 
              child: Row(children:[
                if(widget.duration.isNotEmpty) Text(widget.duration, style: const TextStyle(color: Colors.white, fontSize:12)),
                const SizedBox(width:6), 
                const Icon(Icons.music_note, color: Colors.pink, size:12), 
                Text(widget.songName, style: const TextStyle(color: Colors.white, fontSize:11))
              ])
            )),
        ]),
      );
    }
    // Loading state - clear thumb
    return Stack(alignment: Alignment.center, children:[
      CachedNetworkImage(imageUrl: widget.thumbUrl, height: 500, width: double.infinity, fit: BoxFit.cover, errorWidget: (_,__,___)=> Container(height:500,color: Colors.black, child: const Center(child: CircularProgressIndicator()))),
      const CircularProgressIndicator(color: Colors.white),
    ]);
  }
}