import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../screens/upload_page.dart'; // % ke liye

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // HOME PE UPLOAD % DIKHEGA - Yahi tumhe chahiye tha
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

          // POSTS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                 .collection('posts')
                 .orderBy('createdAt', descending: true)
                 .limit(10)
                 .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Abhi koi Post nahi", style: TextStyle(color: Colors.white)));
                }

                return ListView.builder(
                  cacheExtent: 500,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (_, i) {
                    var data = snapshot.data!.docs[i].data() as Map<String, dynamic>;
                    String mediaUrl = (data['mediaUrl']?? data['imageUrl']?? '').toString();
                    String thumbUrl = (data['thumbnail']?? mediaUrl).toString();
                    bool isVideo = data['isVideo'] == true;
                    String songName = (data['songName']?? "No Song").toString();
                    String duration = (data['durationText']?? "").toString();
                    String title = (data['title']?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.grey[900],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundImage: (data['userPhoto']?? '').toString().isNotEmpty? NetworkImage(data['userPhoto']) : null,
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
                                    Text(songName, style: const TextStyle(color: Colors.pink, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ]),
                              ],
                            ),
                            trailing: duration.isNotEmpty? Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), child: Text(duration, style: const TextStyle(color: Colors.white, fontSize: 10))) : null,
                          ),

                          if (!isVideo && mediaUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: thumbUrl,
                              memCacheWidth: 600,
                              maxWidthDiskCache: 600,
                              fadeInDuration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(height: 300, color: Colors.white10, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                              errorWidget: (_, __, ___) => Container(height: 200, color: Colors.black12, child: const Icon(Icons.broken_image, color: Colors.white)),
                            ),

                          if (isVideo) VideoThumbCard(videoUrl: mediaUrl, thumbUrl: thumbUrl, songName: songName, duration: duration),

                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(data['description']?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VideoThumbCard extends StatefulWidget {
  final String videoUrl;
  final String thumbUrl;
  final String songName;
  final String duration;
  const VideoThumbCard({super.key, required this.videoUrl, required this.thumbUrl, this.songName = "No Song", this.duration = ""});
  @override
  State<VideoThumbCard> createState() => _VideoThumbCardState();
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
        child: Stack(
          children: [
            AspectRatio(aspectRatio: _ctrl!.value.aspectRatio, child: VideoPlayer(_ctrl!)),
            // Timing + Song upar dikhega video chalte time
            Positioned(
              bottom: 8, left: 8, right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)), child: Text("${widget.duration} • ${widget.songName}", style: const TextStyle(color: Colors.white, fontSize: 10))),
                  const Icon(Icons.pause_circle, color: Colors.white70),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _play,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(imageUrl: widget.thumbUrl, memCacheWidth: 600, height: 400, width: double.infinity, fit: BoxFit.cover, placeholder: (_, __) => Container(height: 400, color: Colors.black)),
          Container(color: Colors.black38, height: 400),
          const Icon(Icons.play_circle_fill, size: 70, color: Colors.white70),
          // Thumbnail pe bhi Duration + Song
          Positioned(
            bottom: 8, left: 8,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)), child: Row(children: [
              if (widget.duration.isNotEmpty) Text(widget.duration, style: const TextStyle(color: Colors.white, fontSize: 12)),
              if (widget.songName!= "No Song")...[
                const SizedBox(width: 6),
                const Icon(Icons.music_note, color: Colors.pink, size: 12),
                Text(widget.songName, style: const TextStyle(color: Colors.pink, fontSize: 11)),
              ]
            ])),
          ),
        ],
      ),
    );
  }
}