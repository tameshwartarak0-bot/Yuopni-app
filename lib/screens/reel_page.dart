import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

class ReelPage extends StatefulWidget {
  final int initialIndex;
  final List<QueryDocumentSnapshot>? myReels; // profile se aayega to ye use hoga

  ReelPage({this.initialIndex = 0, this.myReels});

  @override
  _ReelPageState createState() => _ReelPageState();
}

class _ReelPageState extends State<ReelPage> {
  @override
  Widget build(BuildContext context) {
    // Agar profile se list aayi hai to wahi dikhao, warna saare reels
    if (widget.myReels!= null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          scrollDirection: Axis.vertical,
          controller: PageController(initialPage: widget.initialIndex),
          itemCount: widget.myReels!.length,
          itemBuilder: (c, i) => ReelItem(docId: widget.myReels![i].id, data: widget.myReels![i].data() as Map<String, dynamic>),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reels').orderBy('createdAt', descending: true).limit(20).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: CircularProgressIndicator(color: Colors.white));
          if (snap.data!.docs.isEmpty) return Center(child: Text("Koi Reel nahi", style: TextStyle(color: Colors.white)));
          return PageView.builder(
            scrollDirection: Axis.vertical,
            controller: PageController(initialPage: widget.initialIndex),
            itemCount: snap.data!.docs.length,
            itemBuilder: (c, i) => ReelItem(docId: snap.data!.docs[i].id, data: snap.data!.docs[i].data() as Map<String, dynamic>),
          );
        },
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  ReelItem({required this.docId, required this.data});
  @override
  _ReelItemState createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  VideoPlayerController? _ctrl;
  bool _isInit = false;
  bool _isError = false;
  bool _liked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    String url = (widget.data['mediaUrl']?? widget.data['videoUrl']?? '').toString().trim();
    _likeCount = (widget.data['likes'] as List?)?.length?? 0;
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid!= null) _liked = (widget.data['likes'] as List?)?.contains(uid)?? false;

    if (url.isNotEmpty) {
      _ctrl = VideoPlayerController.network(url)
       ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInit = true);
            _ctrl!.setLooping(true);
            _ctrl!.play();
          }
        }).catchError((e) {
          if (mounted) setState(() => _isError = true);
        });
    } else {
      _isError = true;
    }
  }

  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }

  void _toggleLike() async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _liked =!_liked;
      _likeCount = _liked? _likeCount + 1 : _likeCount - 1;
    });
    var ref = FirebaseFirestore.instance.collection('reels').doc(widget.docId);
    if (_liked) ref.update({'likes': FieldValue.arrayUnion([uid])});
    else ref.update({'likes': FieldValue.arrayRemove([uid])});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // VIDEO PART
        _isError
         ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.broken_image, color: Colors.white, size: 50), SizedBox(height: 10), Text("Video load nahi hua", style: TextStyle(color: Colors.white))]))
          : _isInit && _ctrl!= null
           ? GestureDetector(
                onTap: () => _ctrl!.value.isPlaying? _ctrl!.pause() : _ctrl!.play(),
                child: Center(child: AspectRatio(aspectRatio: _ctrl!.value.aspectRatio, child: VideoPlayer(_ctrl!))),
              )
            : Center(child: CircularProgressIndicator(color: Colors.white)),

        // BOTTOM INFO
        Positioned(bottom: 30, left: 15, right: 80, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.data['title']?? '', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Row(children: [
            CircleAvatar(radius: 14, backgroundColor: Colors.orange, child: Text((widget.data['username']?? 'Y')[0].toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 12))),
            SizedBox(width: 6),
            Text(widget.data['username']?? 'Yuopni User', style: TextStyle(color: Colors.white, fontSize: 13)),
          ])
        ])),

        // RIGHT BUTTONS
        Positioned(right: 5, bottom: 90, child: Column(children: [
          IconButton(icon: Icon(_liked? Icons.favorite : Icons.favorite_border, color: _liked? Colors.red : Colors.white, size: 32), onPressed: _toggleLike),
          Text("$_likeCount", style: TextStyle(color: Colors.white, fontSize: 12)),
          SizedBox(height: 15),
          IconButton(icon: Icon(Icons.comment_outlined, color: Colors.white, size: 28), onPressed: () => showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (_) => CommentSheet(reelId: widget.docId))),
          Text("Comment", style: TextStyle(color: Colors.white, fontSize: 10)),
          SizedBox(height: 15),
          IconButton(icon: Icon(Icons.share, color: Colors.white, size: 28), onPressed: () => Share.share(widget.data['mediaUrl']?? '')),
          Text("Share", style: TextStyle(color: Colors.white, fontSize: 10)),
        ])),

        Positioned(top: 40, left: 10, child: IconButton(icon: Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      ]),
    );
  }
}

class CommentSheet extends StatelessWidget {
  final String reelId;
  CommentSheet({required this.reelId});
  @override
  Widget build(BuildContext context) {
    TextEditingController c = TextEditingController();
    return Container(height: 350, padding: EdgeInsets.all(10), child: Column(children: [
      Text("Comments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('reels').doc(reelId).collection('comments').orderBy('createdAt', descending: true).snapshots(), builder: (_, snap) {
        if (!snap.hasData) return Center(child: CircularProgressIndicator());
        return ListView(children: snap.data!.docs.map((d) {
          var m = d.data() as Map<String, dynamic>;
          return ListTile(title: Text(m['text']?? '', style: TextStyle(color: Colors.white)), subtitle: Text(m['username']?? '', style: TextStyle(color: Colors.grey)));
        }).toList());
      })),
      Row(children: [
        Expanded(child: TextField(controller: c, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Comment...", hintStyle: TextStyle(color: Colors.grey)))),
        IconButton(icon: Icon(Icons.send, color: Colors.white), onPressed: () async {
          if (c.text.trim().isEmpty) return;
          var u = FirebaseAuth.instance.currentUser;
          await FirebaseFirestore.instance.collection('reels').doc(reelId).collection('comments').add({'text': c.text.trim(), 'username': u?.displayName?? 'User', 'createdAt': FieldValue.serverTimestamp()});
          c.clear();
        })
      ])
    ]));
  }
}