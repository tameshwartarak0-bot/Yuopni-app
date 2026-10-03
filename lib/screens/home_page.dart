import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../global.dart';
import 'reel_page.dart';

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
                    child: Column(children: [
                      Row(children: [
                        const Icon(Icons.cloud_upload, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text("${p.toStringAsFixed(0)}% Upload ho raha hai...", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))),
                        Text("${p.toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: p / 100, minHeight: 4, color: Colors.green, backgroundColor: Colors.white24),
                    ]),
                  );
                },
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Abhi koi Post nahi", style: TextStyle(color: Colors.white)));
                var docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    var data = docs[i].data() as Map<String, dynamic>;
                    String mediaUrl = (data['mediaUrl']?? data['videoUrl']?? '').toString();
                    String thumbUrl = (data['thumbnail']?? mediaUrl).toString();
                    bool isVideo = data['isVideo'] == true || mediaUrl.toLowerCase().contains(".mp4");
                    String title = (data['title']?? data['caption']?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.grey[900],
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ListTile(
                          leading: CircleAvatar(backgroundImage: (data['userPhoto']?? '').toString().isNotEmpty? NetworkImage(data['userPhoto']) : null),
                          title: Text(data['username']?? 'User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2),
                        ),
                        if (isVideo)
                          AutoPlayVideoCard(videoUrl: mediaUrl, thumbUrl: thumbUrl, docs: docs, index: i)
                        else
                          CachedNetworkImage(imageUrl: mediaUrl, width: double.infinity, height: 420, fit: BoxFit.cover),
                      ]),
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

// --- YE MAIN AUTO-PLAY LOGIC HAI ---
class AutoPlayVideoCard extends StatefulWidget {
  final String videoUrl, thumbUrl;
  final List<QueryDocumentSnapshot> docs;
  final int index;
  const AutoPlayVideoCard({super.key, required this.videoUrl, required this.thumbUrl, required this.docs, required this.index});
  @override
  State<AutoPlayVideoCard> createState() => _AutoPlayVideoCardState();
}

class _AutoPlayVideoCardState extends State<AutoPlayVideoCard> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
     ..initialize().then((_) {
        _controller!.setLooping(true);
        _controller!.setVolume(1);
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) {
        if (!_initialized) return;
        // 70% dikhega tabhi play hoga - Instagram jaisa
        if (info.visibleFraction > 0.7) {
          _controller!.play();
        } else {
          _controller!.pause();
        }
      },
      child: InkWell(
        onTap: () {
          // Tap pe full ReelPage
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReelPage(myReels: widget.docs, initialIndex: widget.index)));
        },
        child: _initialized
           ? AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!))
            : Stack(alignment: Alignment.center, children: [
                CachedNetworkImage(imageUrl: widget.thumbUrl, width: double.infinity, height: 420, fit: BoxFit.cover),
                const CircularProgressIndicator(color: Colors.white),
              ]),
      ),
    );
  }
}