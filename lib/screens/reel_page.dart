import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'main_screen.dart';
import 'login_page.dart';

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
    Map<String, DocumentSnapshot> uniqueByUrl = {};
    for (var doc in docs) {
      var d = doc.data() as Map<String, dynamic>?;
      if (d == null) continue;
      String url = (d['videoUrl']?? d['mediaUrl']?? '').toString().trim();
      if (url.isEmpty) continue;
      if (!uniqueByUrl.containsKey(url)) uniqueByUrl[url] = doc;
    }
    return uniqueByUrl.values.toList();
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
          itemBuilder: (c, i) => ReelItem(
            key: ValueKey(filtered[i].id + "_$i"),
            docId: filtered[i].id,
            data: filtered[i].data() as Map<String, dynamic>,
            showBack: true,
            isActive: i == _currentIndex,
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));
          var filtered = _onlyVideos(snap.data!.docs);
          return PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: filtered.length,
            itemBuilder: (c, i) => ReelItem(
              key: ValueKey(filtered[i].id + "_$i"),
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
  final String docId; final Map<String, dynamic> data; final bool showBack; final bool isActive;
  const ReelItem({super.key, required this.docId, required this.data, this.showBack = false, this.isActive = true});
  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  VideoPlayerController? _videoController; ChewieController? _chewieController;
  bool _isInit = false; bool _isError = false; bool _liked = false; int _likeCount = 0;

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
        _chewieController = ChewieController(videoPlayerController: _videoController!, autoPlay: widget.isActive, looping: true, showControls: false, aspectRatio: _videoController!.value.aspectRatio);
        setState(() => _isInit = true);
        if (widget.isActive &&!pauseReelsNotifier.value) _videoController!.play();
      }).catchError((e) { if (mounted) setState(() => _isError = true); });
    } else _isError = true;
    pauseReelsNotifier.addListener(_handleGlobalPause);
  }
  void _handleGlobalPause() {
    if (!mounted || _videoController == null ||!_isInit) return;
    if (pauseReelsNotifier.value) _videoController!.pause(); else if (widget.isActive) _videoController!.play();
  }
  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive!= widget.isActive) {
      if (widget.isActive &&!pauseReelsNotifier.value) _videoController?.play(); else _videoController?.pause();
    }
  }
  @override
  void dispose() {
    pauseReelsNotifier.removeListener(_handleGlobalPause);
    _videoController?.dispose(); _chewieController?.dispose(); super.dispose();
  }
  bool _requireLogin() {
    if (FirebaseAuth.instance.currentUser == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage())); return false;
    } return true;
  }
  void _toggleLike() async {
    if (!_requireLogin()) return;
    var uid = FirebaseAuth.instance.currentUser!.uid;
    setState(() { _liked =!_liked; _likeCount = _liked? _likeCount + 1 : _likeCount - 1; });
    var ref = FirebaseFirestore.instance.collection('posts').doc(widget.docId);
    if (_liked) ref.update({'likes': FieldValue.arrayUnion([uid])}); else ref.update({'likes': FieldValue.arrayRemove([uid])});
  }
  void _onShare() {
    if (!_requireLogin()) return;
    final String videoLink = "https://yuopni-1c5e9.web.app/video?id=${widget.docId}";
    Share.share("Yuopni pe ye Reel dekho 🔥 $videoLink");
  }
  void _openComment() {
    if (!_requireLogin()) return;
    showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (_) => CommentSheet(reelId: widget.docId));
  }
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        _isError? const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 50))
        : _isInit && _videoController!= null && _chewieController!= null
       ? GestureDetector(onTap: () { if (_videoController!.value.isPlaying) _videoController!.pause(); else _videoController!.play(); }, child: Center(child: AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: Chewie(controller: _chewieController!))))
        : const Center(child: CircularProgressIndicator(color: Colors.white)),
        Positioned(bottom: 35, left: 15, right: 80, child: Text(widget.data['title']?? widget.data['caption']?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        Positioned(right: 5, bottom: 90, child: Column(children: [IconButton(icon: Icon(_liked? Icons.favorite : Icons.favorite_border, color: _liked? Colors.red : Colors.white, size: 32), onPressed: _toggleLike), Text("$_likeCount", style: const TextStyle(color: Colors.white)), IconButton(icon: const Icon(Icons.comment_outlined, color: Colors.white), onPressed: _openComment), IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: _onShare)])),
        if (widget.showBack) Positioned(top: 40, left: 10, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      ]),
    );
  }
}

class CommentSheet extends StatelessWidget {
  final String reelId; CommentSheet({super.key, required this.reelId});
  @override
  Widget build(BuildContext context) {
    TextEditingController c = TextEditingController();
    return Container(height: 350, padding: const EdgeInsets.all(10), child: Column(children: [const Text("Comments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('posts').doc(reelId).collection('comments').orderBy('createdAt', descending: true).snapshots(), builder: (_, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); return ListView(children: snap.data!.docs.map((d) { var m = d.data() as Map<String, dynamic>; return ListTile(title: Text(m['text']?? '', style: const TextStyle(color: Colors.white))); }).toList()); })), Row(children: [Expanded(child: TextField(controller: c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Comment...", hintStyle: TextStyle(color: Colors.grey)))), IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () async { if (c.text.trim().isEmpty) return; var u = FirebaseAuth.instance.currentUser; await FirebaseFirestore.instance.collection('posts').doc(reelId).collection('comments').add({'text': c.text.trim(), 'username': u?.displayName?? 'User', 'createdAt': FieldValue.serverTimestamp()}); c.clear(); })])]));
  }
}