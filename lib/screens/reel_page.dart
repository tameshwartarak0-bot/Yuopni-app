import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

class ReelPage extends StatefulWidget {
  final int initialIndex;
  final List<DocumentSnapshot>? myReels;
  const ReelPage({super.key, this.initialIndex = 0, this.myReels});

  @override
  State<ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<ReelPage> {
  @override
  Widget build(BuildContext context) {
    if (widget.myReels!= null && widget.myReels!.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          scrollDirection: Axis.vertical,
          controller: PageController(initialPage: widget.initialIndex),
          itemCount: widget.myReels!.length,
          itemBuilder: (c, i) {
            var doc = widget.myReels![i];
            var data = (doc.data() as Map<String, dynamic>?)?? {};
            return ReelItem(
              docId: doc.id,
              data: data,
              showBack: true,
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

          var docs = snap.data!.docs;
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: docs.length,
            itemBuilder: (c, i) => ReelItem(
              docId: docs[i].id,
              data: docs[i].data() as Map<String, dynamic>,
              showBack: false,
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
  const ReelItem({super.key, required this.docId, required this.data, this.showBack = false});
  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  VideoPlayerController? _ctrl;
  final AudioPlayer _songPlayer = AudioPlayer();
  bool _isInit = false;
  bool _isError = false;
  bool _liked = false;
  int _likeCount = 0;
  bool _songStarted = false;

  @override
  void initState() {
    super.initState();
    String url = (widget.data['mediaUrl']?? widget.data['videoUrl']?? widget.data['imageUrl']?? '').toString().trim();
    _likeCount = (widget.data['likes'] as List?)?.length?? 0;
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid!= null) _liked = (widget.data['likes'] as List?)?.contains(uid)?? false;

    if (url.isNotEmpty && url.contains('http')) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(url))
    ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInit = true);
            _ctrl!.setLooping(true);
            _ctrl!.setVolume(1.0);
            _ctrl!.play();
            _playSongIfAny();
          }
        }).catchError((e) {
          if (mounted) setState(() => _isError = true);
        });
    } else {
      _isError = true;
    }
  }

  Future<void> _playSongIfAny() async {
    String songFull = (widget.data['songName']?? '').toString();
    if (songFull.isEmpty || songFull == 'No Song' || _songStarted) return;
    _songStarted = true;
    try {
      String songName = songFull.split(' @')[0];
      int startSec = 0;
      if (songFull.contains('@')) {
        String t = songFull.split('@')[1].replaceAll('s','').trim();
        startSec = int.tryParse(t)?? 0;
      }
      final res = await http.get(Uri.parse("https://itunes.apple.com/search?term=${Uri.encodeComponent(songName)}&media=music&limit=1&country=in"));
      if (res.statusCode == 200) {
        var j = jsonDecode(res.body);
        if (j['results']!= null && j['results'].length > 0) {
          String preview = j['results'][0]['previewUrl'];
          await _songPlayer.play(UrlSource(preview));
          await _songPlayer.seek(Duration(seconds: startSec));
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() { _ctrl?.dispose(); _songPlayer.dispose(); super.dispose(); }

  void _toggleLike() async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() { _liked =!_liked; _likeCount = _liked? _likeCount + 1 : _likeCount - 1; });
    var ref = FirebaseFirestore.instance.collection('posts').doc(widget.docId);
    if (_liked) ref.update({'likes': FieldValue.arrayUnion([uid])}); else ref.update({'likes': FieldValue.arrayRemove([uid])});
  }

  void _onShare() {
    final String videoLink = "https://yuopni-1c5e9.web.app/video?id=${widget.docId}";
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
      const SizedBox(height: 15),
      ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.message, color: Colors.white)),
        title: const Text("Yuopni Message me bhejo", style: TextStyle(color: Colors.white)),
        subtitle: const Text("App ke andar share", style: TextStyle(color: Colors.white54)),
        onTap: (){
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Message page: $videoLink")));
        }),
      ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.share, color: Colors.white)),
        title: const Text("WhatsApp pe bhejo", style: TextStyle(color: Colors.white)),
        subtitle: Text(videoLink, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        onTap: (){
          Navigator.pop(context);
          Share.share("Yuopni pe ye Reel dekho 🔥 $videoLink");
        }),
      const SizedBox(height: 10),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        _isError? const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 50))
        : _isInit && _ctrl!= null
      ? GestureDetector(onTap: (){
              setState((){
                if(_ctrl!.value.isPlaying){ _ctrl!.pause(); _songPlayer.pause(); }
                else { _ctrl!.play(); _songPlayer.resume(); }
              });
            }, child: Center(child: AspectRatio(aspectRatio: _ctrl!.value.aspectRatio, child: VideoPlayer(_ctrl!))))
          : const Center(child: CircularProgressIndicator(color: Colors.white)),

        if (_isInit && _ctrl!= null &&!_ctrl!.value.isPlaying)
          const Center(child: Icon(Icons.play_arrow, size: 80, color: Colors.white54)),

        Positioned(bottom: 30, left: 15, right: 80, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((widget.data['title']?? widget.data['caption']?? '').toString().isNotEmpty)
            Text(widget.data['title']?? widget.data['caption']?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Row(children: [
            CircleAvatar(radius: 14, backgroundColor: Colors.orange, child: Text((widget.data['username']?? 'Y')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
            const SizedBox(width: 6),
            Text(widget.data['username']?? 'Yuopni User', style: const TextStyle(color: Colors.white, fontSize: 13)),
          ]),
          if ((widget.data['songName']?? '').toString().isNotEmpty && widget.data['songName']!= 'No Song')
            Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const Icon(Icons.music_note, color: Colors.pink, size: 14), const SizedBox(width: 4), Expanded(child: Text(widget.data['songName'], style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis))]))
        ])),

        Positioned(right: 5, bottom: 90, child: Column(children: [
          IconButton(icon: Icon(_liked? Icons.favorite : Icons.favorite_border, color: _liked? Colors.red : Colors.white, size: 32), onPressed: _toggleLike),
          Text("$_likeCount", style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 15),
          IconButton(icon: const Icon(Icons.comment_outlined, color: Colors.white, size: 28), onPressed: () => showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (_) => CommentSheet(reelId: widget.docId))),
          const Text("Comment", style: TextStyle(color: Colors.white, fontSize: 10)),
          const SizedBox(height: 15),
          IconButton(icon: const Icon(Icons.share, color: Colors.white, size: 28), onPressed: _onShare),
          const Text("Share", style: TextStyle(color: Colors.white, fontSize: 10)),
        ])),

        if (widget.showBack) Positioned(top: 40, left: 10, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      ]),
    );
  }
}

class CommentSheet extends StatelessWidget {
  final String reelId;
  CommentSheet({super.key, required this.reelId});
  @override
  Widget build(BuildContext context) {
    TextEditingController c = TextEditingController();
    return Container(height: 350, padding: const EdgeInsets.all(10), child: Column(children: [
      const Text("Comments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('posts').doc(reelId).collection('comments').orderBy('createdAt', descending: true).snapshots(), builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(children: snap.data!.docs.map((d) { var m = d.data() as Map<String, dynamic>; return ListTile(title: Text(m['text']?? '', style: const TextStyle(color: Colors.white)), subtitle: Text(m['username']?? '', style: const TextStyle(color: Colors.grey))); }).toList());
      })),
      Row(children: [Expanded(child: TextField(controller: c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Comment...", hintStyle: TextStyle(color: Colors.grey)))), IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () async {
        if (c.text.trim().isEmpty) return;
        var u = FirebaseAuth.instance.currentUser;
        await FirebaseFirestore.instance.collection('posts').doc(reelId).collection('comments').add({'text': c.text.trim(), 'username': u?.displayName?? 'User', 'createdAt': FieldValue.serverTimestamp()});
        c.clear();
      })])
    ]));
  }
}