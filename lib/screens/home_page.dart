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
                        Expanded(child: Text("${p.toStringAsFixed(0)}% Upload...", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))),
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
              stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).limit(15).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Abhi koi Post nahi", style: TextStyle(color: Colors.white)));
                var docs = snapshot.data!.docs;
                return ListView.builder(
                  addAutomaticKeepAlives: false, // Important - RAM bachayega
                  addRepaintBoundaries: true,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    var data = docs[i].data() as Map<String, dynamic>;
                    String mediaUrl = (data['mediaUrl']?? data['videoUrl']?? '').toString();
                    String thumbUrl = (data['thumbnail']?? mediaUrl).toString();
                    bool isVideo = data['isVideo'] == true || mediaUrl.toLowerCase().contains(".mp4");
                    String title = (data['title']?? data['caption']?? '').toString();
                    // User ka extra Stream hata diya - direct post data se lo, N+1 query khatam
                    String displayName = (data['username']?? 'User').toString();
                    if(displayName.contains('@')) displayName = 'User';
                    String photoUrl = (data['userPhoto']?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.grey[900],
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.grey[800], backgroundImage: photoUrl.startsWith('http') ? NetworkImage(photoUrl) : null),
                          title: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2),
                        ),
                        if (isVideo)
                          AutoPlayVideoCard(videoUrl: mediaUrl, thumbUrl: thumbUrl, docs: docs, index: i, docId: docs[i].id)
                        else
                          CachedNetworkImage(imageUrl: mediaUrl, width: double.infinity, height: 420, fit: BoxFit.cover, memCacheHeight: 800), // cache height se chipakna band
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
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isError = false;
  bool _shouldInit = false;

  @override
  void initState() {
    super.initState();
    pauseReelsNotifier.addListener(_handleGlobalPause);
  }

  Future<void> _initVideo() async {
    if(_shouldInit) return;
    _shouldInit = true;
    try{
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0);
      if(mounted) setState(()=> _initialized = true);
    }catch(e){
      if(mounted) setState(()=> _isError = true);
    }
  }

  void _handleGlobalPause() {
    if (!_initialized || _controller == null) return;
    if (pauseReelsNotifier.value) _controller!.pause();
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
        // Instagram logic: dikha to init karo, nahi dikha to pause
        if (info.visibleFraction > 0.7) {
          if(!_initialized && !_isError) _initVideo().then((_) => _controller?.play());
          else _controller?.play();
        } else {
          _controller?.pause();
          // Screen se bahar gaya to dispose bhi kar do RAM ke liye
          if(info.visibleFraction == 0 && _initialized) {
             _controller?.dispose();
             _controller = null;
             _initialized = false;
             _shouldInit = false;
          }
        }
      },
      child: InkWell(
        onTap: () {
          _controller?.pause();
          pauseReelsNotifier.value = true;
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReelPage(myReels: widget.docs, initialIndex: widget.index))).then((_){
            pauseReelsNotifier.value = false;
          });
        },
        child: _isError
          ? Container(height: 420, color: Colors.black, child: const Icon(Icons.broken_image, color: Colors.white24))
          : _initialized
           ? AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!))
           : Stack(alignment: Alignment.center, children: [
                CachedNetworkImage(imageUrl: widget.thumbUrl, width: double.infinity, height: 420, fit: BoxFit.cover, memCacheHeight: 600, errorWidget: (_,__,___)=> Container(height: 420, color: Colors.grey[900])),
                const Positioned(bottom: 10, right: 10, child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 30))
              ]),
      ),
    );
  }
}