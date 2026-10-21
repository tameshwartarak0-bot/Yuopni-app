import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_video_player/cached_video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../global.dart';
import 'reel_page.dart';
import 'main_screen.dart';

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
              stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).limit(20).snapshots(),
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
                    String userId = (data['userId'] ?? data['uid'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.grey[900],
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        StreamBuilder<DocumentSnapshot>(
                          stream: userId.isNotEmpty ? FirebaseFirestore.instance.collection('users').doc(userId).snapshots() : null,
                          builder: (context, userSnap) {
                            String displayName = 'User';
                            String photoUrl = (data['userPhoto']?? '').toString();
                            if (userSnap != null && userSnap.hasData && userSnap.data!.exists) {
                              var uData = userSnap.data!.data() as Map<String, dynamic>?;
                              displayName = (uData?['username'] ?? 'User').toString();
                              photoUrl = (uData?['photoUrl'] ?? photoUrl).toString();
                            } else {
                              String raw = (data['username'] ?? 'User').toString();
                              displayName = raw.contains('@') ? 'User' : raw;
                            }
                            return ListTile(
                              leading: CircleAvatar(backgroundColor: Colors.grey[800], backgroundImage: photoUrl.startsWith('http') ? NetworkImage(photoUrl) : null),
                              title: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2),
                            );
                          }
                        ),
                        if (isVideo)
                          AutoPlayVideoCard(videoUrl: mediaUrl, thumbUrl: thumbUrl, docs: docs, index: i, docId: docs[i].id)
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

class AutoPlayVideoCard extends StatefulWidget {
  final String videoUrl, thumbUrl, docId;
  final List<QueryDocumentSnapshot> docs;
  final int index;
  const AutoPlayVideoCard({super.key, required this.videoUrl, required this.thumbUrl, required this.docs, required this.index, required this.docId});
  @override State<AutoPlayVideoCard> createState() => _AutoPlayVideoCardState();
}

class _AutoPlayVideoCardState extends State<AutoPlayVideoCard> {
  CachedVideoPlayerController? _controller;
  bool _initialized = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    // FIX: Login ke baad pause ko false kar do
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(pauseReelsNotifier.value){
        pauseReelsNotifier.value = false;
      }
    });
    pauseReelsNotifier.addListener(_handleGlobalPause);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try{
      // FIX: Cached controller - 259KB/s ki jagah 25KB/s
      _controller = CachedVideoPlayerController.network(
        widget.videoUrl,
        cacheKey: widget.docId,
      );
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0); // Home pe mute rakho - data + UX sahi
      if(mounted){
        setState(()=> _initialized = true);
      }
    }catch(e){
      if(mounted) setState(()=> _isError = true);
      debugPrint("Video init error ${widget.videoUrl} $e");
    }
  }

  void _handleGlobalPause() {
    if (!_initialized || _controller == null) return;
    if (pauseReelsNotifier.value) {
      _controller!.pause();
    }
  }

  @override
  void dispose() {
    pauseReelsNotifier.removeListener(_handleGlobalPause);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.docId),
      onVisibilityChanged: (info) {
        if (!_initialized || _controller == null) return;
        if (pauseReelsNotifier.value) {
          _controller!.pause();
          return;
        }
        // 60% dikhe tabhi play - pehle 70% tha isliye kabhi play hi nahi hota tha
        if (info.visibleFraction > 0.6) {
          _controller!.play();
        } else {
          _controller!.pause();
        }
      },
      child: InkWell(
        onTap: () {
          // Tap pe pause karo aur reel pe jao
          _controller?.pause();
          pauseReelsNotifier.value = true;
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReelPage(myReels: widget.docs, initialIndex: widget.index))).then((_){
            pauseReelsNotifier.value = false;
          });
        },
        child: _isError
          ? Container(height: 420, color: Colors.black, child: Icon(Icons.broken_image, color: Colors.white24))
          : _initialized
           ? AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: CachedVideoPlayer(_controller!))
           : Stack(alignment: Alignment.center, children: [
                CachedNetworkImage(imageUrl: widget.thumbUrl, width: double.infinity, height: 420, fit: BoxFit.cover, errorWidget: (_,__,___)=> Container(height: 420, color: Colors.grey[900])),
                const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                const Positioned(bottom: 10, right: 10, child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30))
              ]),
      ),
    );
  }
}