import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
           .collection('posts')
           .orderBy('createdAt', descending: true)
           .limit(10) // 15 se 10 kar diya aur tez
           .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("Abhi koi Post nahi", style: TextStyle(color: Colors.white)));
          }

          return ListView.builder(
            cacheExtent: 500, // YE FAST KA JADU HAI
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (_, i) {
              var data = snapshot.data!.docs[i].data() as Map<String, dynamic>;
              String mediaUrl = (data['mediaUrl']?? data['imageUrl']?? '').toString();
              String thumbUrl = (data['thumbnail']?? mediaUrl).toString();
              bool isVideo = data['isVideo'] == true;

              return Container(
                margin: EdgeInsets.only(bottom: 12),
                color: Colors.grey[900],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (data['userPhoto']?? '').toString().isNotEmpty
                           ? NetworkImage(data['userPhoto'])
                            : null,
                      ),
                      title: Text(data['username']?? 'User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(data['title']?? '', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),

                    // FAST IMAGE - AB BILKUL BUFFING NAHI
                    if (!isVideo && mediaUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: thumbUrl,
                        memCacheWidth: 600, // 4K ki jagah 600px hi load hoga - 10x tez
                        maxWidthDiskCache: 600,
                        fadeInDuration: Duration(milliseconds: 200),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(height: 300, color: Colors.white10, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        errorWidget: (_, __, ___) => Container(height: 200, color: Colors.black12, child: Icon(Icons.broken_image, color: Colors.white)),
                      ),

                    if (isVideo)
                      VideoThumbCard(videoUrl: mediaUrl, thumbUrl: thumbUrl),

                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(data['description']?? '', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// REEL AB LIST ME LOAD HI NAHI HOGA - SIRF TAP PE
class VideoThumbCard extends StatefulWidget {
  final String videoUrl;
  final String thumbUrl;
  VideoThumbCard({required this.videoUrl, required this.thumbUrl});
  @override
  _VideoThumbCardState createState() => _VideoThumbCardState();
}

class _VideoThumbCardState extends State<VideoThumbCard> {
  VideoPlayerController? _ctrl;
  bool _playing = false;

  void _play() async {
    if (_playing) {
      _ctrl?.pause();
      setState(() => _playing = false);
      return;
    }
    _ctrl = VideoPlayerController.network(widget.videoUrl);
    await _ctrl!.initialize();
    _ctrl!.setLooping(true);
    _ctrl!.play();
    setState(() => _playing = true);
  }

  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_playing && _ctrl!= null && _ctrl!.value.isInitialized) {
      return GestureDetector(
        onTap: _play,
        child: AspectRatio(aspectRatio: _ctrl!.value.aspectRatio, child: VideoPlayer(_ctrl!)),
      );
    }
    return GestureDetector(
      onTap: _play,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: widget.thumbUrl,
            memCacheWidth: 600,
            height: 400,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(height: 400, color: Colors.black),
          ),
          Container(color: Colors.black38, height: 400),
          Icon(Icons.play_circle_fill, size: 70, color: Colors.white70),
        ],
      ),
    );
  }
}