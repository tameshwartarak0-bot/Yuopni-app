import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'main_screen.dart';

class ReelPage extends StatefulWidget {
  final int initialIndex;
  final List<DocumentSnapshot>? myReels;
  const ReelPage({super.key, this.initialIndex = 0, this.myReels});

  @override
  State<ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<ReelPage> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<DocumentSnapshot> _onlyVideos(List<DocumentSnapshot> docs) {
    return docs.where((doc) {
      var d = doc.data() as Map<String, dynamic>?;
      if (d == null) return false;
      String media = (d['mediaUrl']?? '').toString().toLowerCase();
      String vUrl = (d['videoUrl']?? '').toString();
      bool isVideo = d['isVideo'] == true;
      return isVideo || vUrl.isNotEmpty || media.contains('.mp4') || media.contains('video');
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.myReels!= null && widget.myReels!.isNotEmpty) {
      var filtered = _onlyVideos(widget.myReels!);
      return Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          scrollDirection: Axis.vertical,
          controller: _pageController,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemCount: filtered.length,
          itemBuilder: (c, i) {
            var doc = filtered[i];
            var data = (doc.data() as Map<String, dynamic>?)?? {};
            return ReelItem(
              key: ValueKey(doc.id), // FIX 1: Har reel ka alag key
              docId: doc.id,
              data: data,
              showBack: true,
              isActive: i == _currentIndex,
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Error: ${snap.error}", style: const TextStyle(color: Colors.white)));
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
          if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text("Koi Reel nahi", style: TextStyle(color: Colors.white)));

          var filtered = _onlyVideos(snap.data!.docs);
          if (filtered.isEmpty) return const Center(child: Text("Koi video reel nahi hai", style: TextStyle(color: Colors.white)));

          return PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: filtered.length,
            itemBuilder: (c, i) => ReelItem(
              key: ValueKey(filtered[i].id), // FIX 1: Har reel ka alag key
              docId: filtered[i].id,
              data: filtered[i].data() as Map<String, dynamic>,
              showBack: false,
              isActive: i == _currentIndex,
            ),
          );
        },
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool showBack;
  final bool isActive;
  const ReelItem({super.key, required this.docId, required this.data, this.showBack = false, this.isActive = true});
  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => false; // FIX 2: false kiya

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInit = false;
  bool _isError = false;
  bool _liked = false;
  int _likeCount = 0;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    String url = (widget.data['mediaUrl']?? widget.data['videoUrl']?? '').toString().trim();
    _likeCount = (widget.data['likes'] as List?)?.length?? 0;
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid!= null) _liked = (widget.data['likes'] as List?)?.contains(uid)?? false;

    if (url.isNotEmpty && url.contains('http')) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoController!.initialize().then((_) {
        if (!mounted) return;
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: widget.isActive,
          looping: true,
          showControls: false,
          allowFullScreen: true,
          aspectRatio: _videoController!.value.aspectRatio,
        );
        setState(() => _isInit = true);
        if (widget.isActive &&!pauseReelsNotifier.value) _videoController!.play();
      }).catchError((e) {
        if (mounted) setState(() => _isError = true);
      });
    } else {
      _isError = true;
    }
    pauseReelsNotifier.addListener(_handleGlobalPause);
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive!= widget.isActive) {
      if (widget.isActive &&!pauseReelsNotifier.value) _videoController?.play(); else _videoController?.pause();
    }
  }

  void _handleGlobalPause() {
    if (!mounted || _videoController == null ||!_isInit) return;
    if (pauseReelsNotifier.value) _videoController!.pause(); else if (widget.isActive) _videoController!.play();
  }

  @override
  void dispose() {
    pauseReelsNotifier.removeListener(_handleGlobalPause);
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _toggleLike() async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() { _liked =!_liked; _likeCount = _liked? _likeCount + 1 : _likeCount - 1; });
    var ref = FirebaseFirestore.instance.collection('posts').doc(widget.docId);
    if (_liked) ref.update({'likes': FieldValue.arrayUnion([uid])}); else ref.update({'likes': FieldValue.arrayRemove([uid])});
  }

  Future<void> _sendReelToChat(String chatId, String otherName) async {
    String? myUid = FirebaseAuth.instance.currentUser?.uid;
    String videoUrl = (widget.data['mediaUrl']?? widget.data['videoUrl']?? '').toString();
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'sender': myUid, 'type': 'reel', 'videoUrl': videoUrl, 'postId': widget.docId,
      'caption': widget.data['caption']?? widget.data['title']?? '', 'thumbnail': widget.data['thumbnail']?? '',
      'time': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({'lastMsg': "🎬 Reel bheji", 'lastTime': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$otherName ko reel bhej di ✅"), backgroundColor: Colors.green));
  }

  void _showYuopniShareSheet() {
    String? myUid = FirebaseAuth.instance.currentUser?.uid;
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E1E1E), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Container(height: 450, padding: const EdgeInsets.all(12), child: Column(children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))), const SizedBox(height: 12), const Text("Yuopni pe Share karo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 12), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: myUid).snapshots(), builder: (c,snap){ if(snap.connectionState==ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.pink)); if(!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.message, color: Colors.white24, size: 50), SizedBox(height: 10), Text("Koi chat nahi hai", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))])); var docs = snap.data!.docs; return ListView.builder(itemCount: docs.length, itemBuilder: (_,i){ var d = docs[i].data() as Map<String,dynamic>; List parts = d['participants']??[]; if(parts.length<2) return const SizedBox(); String otherUid = parts[0]==myUid? parts[1]: parts[0]; String otherName = (d['userNames']?[otherUid]?? "User").toString(); String otherPhoto = (d['userPhotos']?[otherUid]?? "").toString(); return ListTile(leading: CircleAvatar(radius: 22, backgroundImage: otherPhoto.isNotEmpty? NetworkImage(otherPhoto): null), title: Text(otherName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: () async { Navigator.pop(context); await _sendReelToChat(docs[i].id, otherName); }, child: const Text("Send"))); }); }))]))); }

  void _onShare() {
    final String videoLink = "https://yuopni-1c5e9.web.app/video?id=${widget.docId}";
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))), const SizedBox(height: 15), ListTile(leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.message, color: Colors.white)), title: const Text("Yuopni Message me bhejo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onTap: (){ Navigator.pop(context); _showYuopniShareSheet(); }), ListTile(leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.share, color: Colors.white)), title: const Text("WhatsApp pe bhejo", style: TextStyle(color: Colors.white)), subtitle: Text(videoLink, style: const TextStyle(color: Colors.white54, fontSize: 12)), onTap: (){ Navigator.pop(context); Share.share("Yuopni pe ye Reel dekho 🔥 $videoLink"); }), const SizedBox(height: 10)])));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(color: Colors.black, child: Stack(fit: StackFit.expand, children: [
      _isError? const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 50))
      : _isInit && _videoController!= null && _chewieController!= null
    ? GestureDetector(onTap: (){ setState(() => _showControls =!_showControls); if(_videoController!.value.isPlaying) _videoController!.pause(); else _videoController!.play(); }, child: Center(child: AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: Chewie(controller: _chewieController!))))
      : const Center(child: CircularProgressIndicator(color: Colors.white)),
      if (_isInit && _videoController!= null &&!_videoController!.value.isPlaying) const Center(child: Icon(Icons.play_arrow, size: 80, color: Colors.white70)),
      if (_isInit && _videoController!= null) Positioned(bottom: 0, left: 0, right: 0, child: VideoProgressIndicator(_videoController!, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Colors.pink, bufferedColor: Colors.white24, backgroundColor: Colors.white10))),
      Positioned(bottom: 35, left: 15, right: 80, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if ((widget.data['title']?? widget.data['caption']?? '').toString().isNotEmpty) Text(widget.data['title']?? widget.data['caption']?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 6), Row(children: [CircleAvatar(radius: 14, backgroundColor: Colors.orange, child: Text((widget.data['username']?? 'Y')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))), const SizedBox(width: 6), Text(widget.data['username']?? 'Yuopni User', style: const TextStyle(color: Colors.white, fontSize: 13))])])),
      Positioned(right: 5, bottom: 90, child: Column(children: [IconButton(icon: Icon(_liked? Icons.favorite : Icons.favorite_border, color: _liked? Colors.red : Colors.white, size: 32), onPressed: _toggleLike), Text("$_likeCount", style: const TextStyle(color: Colors.white, fontSize: 12)), const SizedBox(height: 15), IconButton(icon: const Icon(Icons.comment_outlined, color: Colors.white, size: 28), onPressed: () => showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (_) => CommentSheet(reelId: widget.docId))), const Text("Comment", style: TextStyle(color: Colors.white, fontSize: 10)), const SizedBox(height: 15), IconButton(icon: const Icon(Icons.share, color: Colors.white, size: 28), onPressed: _onShare), const Text("Share", style: TextStyle(color: Colors.white, fontSize: 10))])),
      if (widget.showBack) Positioned(top: 40, left: 10, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
    ]));
  }
}

class CommentSheet extends StatelessWidget {
  final String reelId;
  CommentSheet({super.key, required this.reelId});
  @override
  Widget build(BuildContext context) {
    TextEditingController c = TextEditingController();
    return Container(height: 350, padding: const EdgeInsets.all(10), child: Column(children: [const Text("Comments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('posts').doc(reelId).collection('comments').orderBy('createdAt', descending: true).snapshots(), builder: (_, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); return ListView(children: snap.data!.docs.map((d) { var m = d.data() as Map<String, dynamic>; return ListTile(title: Text(m['text']?? '', style: const TextStyle(color: Colors.white)), subtitle: Text(m['username']?? '', style: const TextStyle(color: Colors.grey))); }).toList()); })), Row(children: [Expanded(child: TextField(controller: c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Comment...", hintStyle: TextStyle(color: Colors.grey)))), IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () async { if (c.text.trim().isEmpty) return; var u = FirebaseAuth.instance.currentUser; await FirebaseFirestore.instance.collection('posts').doc(reelId).collection('comments').add({'text': c.text.trim(), 'username': u?.displayName?? 'User', 'createdAt': FieldValue.serverTimestamp()}); c.clear(); })])]));
  }
}