import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'main_screen.dart';
import 'login_page.dart';

class ReelPage extends StatefulWidget {
  final int initialIndex;
  final List<DocumentSnapshot>? myReels;
  const ReelPage({super.key, this.initialIndex = 0, this.myReels});
  @override State<ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<ReelPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  @override void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }
  @override void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<DocumentSnapshot> _onlyVideos(List<DocumentSnapshot> docs) {
    Map<String, DocumentSnapshot> uniqueByUrl = {};
    for (var doc in docs) {
      var d = doc.data() as Map<String, dynamic>?;
      if (d == null) continue;
      String url = (d['videoUrl']?? d['mediaUrl']?? d['videoURL']?? '').toString().trim();
      if (url.isEmpty) continue;
      if (!url.startsWith('http')) continue;
      if (url.startsWith('/data')) continue;
      if (!uniqueByUrl.containsKey(url)) uniqueByUrl[url] = doc;
    }
    return uniqueByUrl.values.toList();
  }

  @override Widget build(BuildContext context) {
    if (widget.myReels!= null && widget.myReels!.isNotEmpty) {
      var filtered = _onlyVideos(widget.myReels!);
      return Scaffold(backgroundColor: Colors.black, body: PageView.builder(scrollDirection: Axis.vertical, controller: _pageController, onPageChanged: (i) => setState(() => _currentIndex = i), itemCount: filtered.length, itemBuilder: (c, i) => ReelItem(key: ValueKey(filtered[i].id + "_$i"), docId: filtered[i].id, data: filtered[i].data() as Map<String, dynamic>, showBack: true, isActive: i == _currentIndex)));
    }
    return Scaffold(backgroundColor: Colors.black, body: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(), builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));
      var filtered = _onlyVideos(snap.data!.docs);
      if (filtered.isEmpty) return const Center(child: Text("No reels", style: TextStyle(color: Colors.white)));
      return PageView.builder(scrollDirection: Axis.vertical, controller: _pageController, onPageChanged: (i) => setState(() => _currentIndex = i), itemCount: filtered.length, itemBuilder: (c, i) => ReelItem(key: ValueKey(filtered[i].id + "_$i"), docId: filtered[i].id, data: filtered[i].data() as Map<String, dynamic>, showBack: false, isActive: i == _currentIndex));
    }));
  }
}

class ReelItem extends StatefulWidget {
  final String docId; final Map<String, dynamic> data; final bool showBack; final bool isActive;
  const ReelItem({super.key, required this.docId, required this.data, this.showBack = false, this.isActive = true});
  @override State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => false; // FIX: Chipakna khatam
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final AudioPlayer _songPlayer = AudioPlayer();
  bool _isInit = false; bool _isError = false; bool _liked = false; int _likeCount = 0;
  bool _pausedByPopup = false;

  @override void initState() {
    super.initState();
    String url = (widget.data['mediaUrl']?? widget.data['videoUrl']?? '').toString().trim();
    _likeCount = (widget.data['likes'] as List?)?.length?? 0;
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid!= null) _liked = (widget.data['likes'] as List?)?.contains(uid)?? false;

    if (url.isNotEmpty && url.startsWith('http')) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoController!.initialize().then((_) {
        if (!mounted) return;
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false, // FIX
          looping: true,
          showControls: false,
          aspectRatio: _videoController!.value.aspectRatio
        );
        setState(() => _isInit = true);
        if (widget.isActive && !pauseReelsNotifier.value && !_pausedByPopup) {
          String songUrl = (widget.data['songUrl']?? '').toString().trim();
          _playReel(songUrl);
        }
      }).catchError((e) { if (mounted) setState(() => _isError = true); });
    } else {
      _isError = true;
    }
    pauseReelsNotifier.addListener(_handleGlobalPause);
  }

  Future<void> _playReel(String songUrl) async {
    if (_videoController == null || !mounted) return;
    if (pauseReelsNotifier.value || !widget.isActive || _pausedByPopup) return;

    if (!_videoController!.value.isPlaying) {
      _videoController!.play();
    }

    if (songUrl.isNotEmpty) {
      _videoController!.setVolume(0);
      try {
        await _songPlayer.setUrl(songUrl);
        _songPlayer.setLoopMode(LoopMode.one);
        _songPlayer.setVolume(1.0);
        if (widget.isActive && mounted && !pauseReelsNotifier.value && !_pausedByPopup) {
          _songPlayer.play();
        }
      } catch(e) {}
    } else {
      _videoController!.setVolume(1.0);
      _songPlayer.stop();
    }
  }

  void _handleGlobalPause() {
    if (!mounted || _videoController == null || !_isInit) return;
    if (pauseReelsNotifier.value || !widget.isActive) {
      _videoController!.pause();
      _songPlayer.pause();
    } else if (!_pausedByPopup) {
      String songUrl = (widget.data['songUrl']?? '').toString().trim();
      _playReel(songUrl);
    }
  }

  @override void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive!= widget.isActive) {
      String songUrl = (widget.data['songUrl']?? '').toString().trim();
      if (widget.isActive && !pauseReelsNotifier.value && !_pausedByPopup) {
        _playReel(songUrl);
      } else {
        _videoController?.pause();
        _songPlayer.pause();
      }
    }
  }

  @override void dispose() {
    pauseReelsNotifier.removeListener(_handleGlobalPause);
    _videoController?.pause();
    _videoController?.dispose();
    _chewieController?.dispose();
    _songPlayer.stop();
    _songPlayer.dispose();
    super.dispose();
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
  
  // FIX: Background touch bug khatam - global ko touch nahi karenge
  void _pauseForPopup() { 
    _pausedByPopup = true;
    _videoController?.pause();
    _songPlayer.pause();
  }
  void _resumeAfterPopup() { 
    _pausedByPopup = false;
    if (widget.isActive && !pauseReelsNotifier.value && mounted) {
      String songUrl = (widget.data['songUrl']?? '').toString().trim();
      _playReel(songUrl);
    }
  }

  Future<void> _sendReelToChat(String chatId, String otherName) async {
    if (!_requireLogin()) return;
    String? myUid = FirebaseAuth.instance.currentUser?.uid;
    String videoUrl = (widget.data['mediaUrl']?? widget.data['videoUrl']?? '').toString();
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({'sender': myUid, 'type': 'reel', 'videoUrl': videoUrl, 'postId': widget.docId, 'caption': widget.data['caption']?? widget.data['title']?? '', 'thumbnail': widget.data['thumbnail']?? '', 'time': FieldValue.serverTimestamp()});
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({'lastMsg': "🎬 Reel bheji", 'lastTime': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$otherName ko reel bhej di ✅"), backgroundColor: Colors.green));
  }
  void _showYuopniShareSheet() {
    if (!_requireLogin()) return;
    _pauseForPopup();
    String? myUid = FirebaseAuth.instance.currentUser?.uid;
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E1E1E), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Container(height: 450, padding: const EdgeInsets.all(12), child: Column(children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))), const SizedBox(height: 12), const Text("Yuopni pe Share karo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 12), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: myUid).snapshots(), builder: (c,snap){ if(snap.connectionState==ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.pink)); if(!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text("Koi chat nahi hai", style: TextStyle(color: Colors.white54))); var docs = snap.data!.docs; return ListView.builder(itemCount: docs.length, itemBuilder: (_,i){ var d = docs[i].data() as Map<String,dynamic>; List parts = d['participants']??[]; if(parts.length<2) return const SizedBox(); String otherUid = parts[0]==myUid? parts[1]: parts[0]; String otherName = (d['userNames']?[otherUid]?? "User").toString(); String otherPhoto = (d['userPhotos']?[otherUid]?? "").toString(); return ListTile(leading: CircleAvatar(radius: 22, backgroundImage: otherPhoto.isNotEmpty? NetworkImage(otherPhoto): null), title: Text(otherName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: () async { Navigator.pop(context); await _sendReelToChat(docs[i].id, otherName); }, child: const Text("Send"))); }); }))]))).whenComplete(() => _resumeAfterPopup());
  }
  void _onShare() {
    if (!_requireLogin()) return;
    _pauseForPopup();
    final String videoLink = "https://yuopni-1c5e9.web.app/video?id=${widget.docId}";
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))), const SizedBox(height: 15), ListTile(leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.message, color: Colors.white)), title: const Text("Yuopni Message me bhejo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onTap: (){ Navigator.pop(context); _showYuopniShareSheet(); }), ListTile(leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.share, color: Colors.white)), title: const Text("WhatsApp pe bhejo", style: TextStyle(color: Colors.white)), subtitle: Text(videoLink, style: const TextStyle(color: Colors.white54, fontSize: 12)), onTap: (){ Navigator.pop(context); Share.share("Yuopni pe ye Reel dekho 🔥 $videoLink"); }), const SizedBox(height: 10)]))).whenComplete(() => _resumeAfterPopup());
  }
  void _openComment() {
    if (!_requireLogin()) return;
    _pauseForPopup();
    showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (_) => CommentSheet(reelId: widget.docId)).whenComplete(() => _resumeAfterPopup());
  }

  @override Widget build(BuildContext context) {
    super.build(context);
    String userId = (widget.data['userId'] ?? widget.data['uid'] ?? '').toString();
    String caption = (widget.data['caption']?? widget.data['title']?? '').toString();
    String songName = (widget.data['songName']?? '').toString();
    String userPhoto = (widget.data['userPhoto']?? '').toString();

    return Container(color: Colors.black, child: Stack(fit: StackFit.expand, children: [
      _isError? const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 40)) : _isInit && _videoController!= null && _chewieController!= null? GestureDetector(onTap: (){ if(_videoController!.value.isPlaying) { _videoController!.pause(); _songPlayer.pause(); } else { if(!pauseReelsNotifier.value && !_pausedByPopup) { _videoController!.play(); if((_songPlayer.playerState.playing==false) && (widget.data['songUrl']?? '').toString().isNotEmpty) _songPlayer.play(); } } }, child: Center(child: AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: Chewie(controller: _chewieController!)))) : const Center(child: CircularProgressIndicator(color: Colors.white)),
      
      // FIX: Username ab users collection se - gmail naam nahi
      Positioned(bottom: 35, left: 15, right: 80, child: StreamBuilder<DocumentSnapshot>(
        stream: userId.isNotEmpty ? FirebaseFirestore.instance.collection('users').doc(userId).snapshots() : null,
        builder: (context, userSnap) {
          String displayName = (widget.data['username']?? widget.data['userName']?? 'Yuopni User').toString();
          String photo = userPhoto;
          if (userSnap != null && userSnap.hasData && userSnap.data!.exists) {
            var u = userSnap.data!.data() as Map<String, dynamic>?;
            displayName = (u?['username'] ?? u?['name'] ?? displayName).toString();
            photo = (u?['photoUrl'] ?? u?['photo'] ?? photo).toString();
          }
          // Gmail filter
          if (displayName.contains('@') || displayName.toLowerCase().contains('tameshwar')) {
            displayName = 'demo_me';
          }
          String finalSong = songName.isNotEmpty ? songName : 'Original audio - $displayName';
          
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 16, backgroundImage: photo.isNotEmpty && photo.startsWith('http') ? NetworkImage(photo) : null, child: photo.isEmpty || !photo.startsWith('http') ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U') : null),
              const SizedBox(width: 8),
              Text("@$displayName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 8),
            if(caption.isNotEmpty) Text(caption, maxLines: 2, style: const TextStyle(color: Colors.white)),
            Row(children: [const Icon(Icons.music_note, color: Colors.white, size: 14), const SizedBox(width: 5), Expanded(child: Text(finalSong, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 12)))]),
          ]);
        }
      )),
      Positioned(right: 5, bottom: 90, child: Column(children: [IconButton(icon: Icon(_liked? Icons.favorite : Icons.favorite_border, color: _liked? Colors.red : Colors.white, size: 32), onPressed: _toggleLike), Text("$_likeCount", style: const TextStyle(color: Colors.white, fontSize: 12)), const SizedBox(height: 15), IconButton(icon: const Icon(Icons.comment_outlined, color: Colors.white, size: 28), onPressed: _openComment), const Text("Comment", style: TextStyle(color: Colors.white, fontSize: 10)), const SizedBox(height: 15), IconButton(icon: const Icon(Icons.share, color: Colors.white, size: 28), onPressed: _onShare), const Text("Share", style: TextStyle(color: Colors.white, fontSize: 10))])),
      if (widget.showBack) Positioned(top: 40, left: 10, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
    ]));
  }
}

class CommentSheet extends StatelessWidget {
  final String reelId; CommentSheet({super.key, required this.reelId});
  @override Widget build(BuildContext context) {
    TextEditingController c = TextEditingController();
    return Container(height: 350, padding: const EdgeInsets.all(10), child: Column(children: [const Text("Comments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('posts').doc(reelId).collection('comments').orderBy('createdAt', descending: true).snapshots(), builder: (_, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); return ListView(children: snap.data!.docs.map((d) { var m = d.data() as Map<String, dynamic>; return ListTile(title: Text(m['text']?? '', style: const TextStyle(color: Colors.white)), subtitle: Text(m['username']?? '', style: const TextStyle(color: Colors.grey))); }).toList()); })), Row(children: [Expanded(child: TextField(controller: c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Comment...", hintStyle: TextStyle(color: Colors.grey)))), IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () async { if (c.text.trim().isEmpty) return; var u = FirebaseAuth.instance.currentUser; String uid = u?.uid ?? ''; var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get(); String name = userDoc.data()?['username'] ?? 'User'; await FirebaseFirestore.instance.collection('posts').doc(reelId).collection('comments').add({'text': c.text.trim(), 'username': name, 'createdAt': FieldValue.serverTimestamp()}); c.clear(); })])]));
  }
}