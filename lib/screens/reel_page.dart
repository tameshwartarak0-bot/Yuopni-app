import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

class ReelPage extends StatefulWidget {
  final int initialIndex;
  ReelPage({this.initialIndex = 0});
  @override
  _ReelPageState createState() => _ReelPageState();
}

class _ReelPageState extends State<ReelPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reels').orderBy('createdAt', descending: true).limit(20).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Text("Koi Reel nahi hai", style: TextStyle(color: Colors.white)));

          return PageView.builder(
            scrollDirection: Axis.vertical,
            controller: PageController(initialPage: widget.initialIndex),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return ReelItem(docId: docs[index].id, data: data);
            },
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
  VideoPlayerController? _controller;
  bool _isInit = false;
  bool _liked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    String videoUrl = (widget.data['mediaUrl']?? widget.data['videoUrl']?? '').toString();
    _likeCount = (widget.data['likes'] as List?)?.length?? 0;
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid!= null) {
      _liked = (widget.data['likes'] as List?)?.contains(uid)?? false;
    }
    if (videoUrl.isNotEmpty) {
      _controller = VideoPlayerController.network(videoUrl)
       ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInit = true);
            _controller!.setLooping(true);
            _controller!.play();
          }
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleLike() async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    var ref = FirebaseFirestore.instance.collection('reels').doc(widget.docId);
    setState(() {
      _liked =!_liked;
      _likeCount = _liked? _likeCount + 1 : _likeCount - 1;
    });
    if (_liked) {
      ref.update({'likes': FieldValue.arrayUnion([uid])});
    } else {
      ref.update({'likes': FieldValue.arrayRemove([uid])});
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (_) => CommentSheet(reelId: widget.docId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_controller!.value.isPlaying) _controller!.pause();
        else _controller!.play();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _isInit && _controller!= null
             ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                )
              : Container(color: Colors.black, child: Center(child: CircularProgressIndicator())),

          // Bottom user info
          Positioned(
            bottom: 25,
            left: 15,
            right: 80,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.data['title']?? 'ganpati bappa morya', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Row(children: [
                CircleAvatar(radius: 15, backgroundColor: Colors.deepOrange, child: Text((widget.data['username']?? 'T')[0].toUpperCase(), style: TextStyle(color: Colors.white))),
                SizedBox(width: 8),
                Text(widget.data['username']?? 'Tameshwar Tarak', style: TextStyle(color: Colors.white)),
              ]),
            ]),
          ),

          // Right buttons like Instagram
          Positioned(
            right: 5,
            bottom: 80,
            child: Column(children: [
              IconButton(
                icon: Icon(_liked? Icons.favorite : Icons.favorite_border, color: _liked? Colors.red : Colors.white, size: 32),
                onPressed: _toggleLike,
              ),
              Text("$_likeCount", style: TextStyle(color: Colors.white, fontSize: 12)),
              SizedBox(height: 18),
              IconButton(icon: Icon(Icons.mode_comment_outlined, color: Colors.white, size: 30), onPressed: _openComments),
              Text("Comment", style: TextStyle(color: Colors.white, fontSize: 10)),
              SizedBox(height: 18),
              IconButton(
                icon: Icon(Icons.share, color: Colors.white, size: 30),
                onPressed: () {
                  Share.share("Yuopni pe dekho: ${widget.data['mediaUrl']?? ''}");
                },
              ),
              Text("Share", style: TextStyle(color: Colors.white, fontSize: 10)),
            ]),
          ),
        ],
      ),
    );
  }
}

class CommentSheet extends StatefulWidget {
  final String reelId;
  CommentSheet({required this.reelId});
  @override
  _CommentSheetState createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  TextEditingController _c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: 400,
        padding: EdgeInsets.all(12),
        child: Column(children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
          SizedBox(height: 10),
          Text("Comments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('reels').doc(widget.reelId).collection('comments').orderBy('createdAt', descending: true).limit(50).snapshots(),
              builder: (c, snap) {
                if (!snap.hasData) return Center(child: CircularProgressIndicator());
                if (snap.data!.docs.isEmpty) return Center(child: Text("Pehla comment karo", style: TextStyle(color: Colors.grey)));
                return ListView.builder(
                  itemCount: snap.data!.docs.length,
                  itemBuilder: (_, i) {
                    var d = snap.data!.docs[i].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(radius: 15, child: Text((d['username']?? 'U')[0])),
                      title: Text(d['text']?? '', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(d['username']?? '', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    );
                  },
                );
              },
            ),
          ),
          Row(children: [
            Expanded(child: TextField(controller: _c, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Comment likho...", hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none))),
            IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: () async {
                if (_c.text.trim().isEmpty) return;
                var user = FirebaseAuth.instance.currentUser;
                await FirebaseFirestore.instance.collection('reels').doc(widget.reelId).collection('comments').add({
                  'text': _c.text.trim(),
                  'uid': user?.uid,
                  'username': user?.displayName?? 'User',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                _c.clear();
              },
            ),
          ])
        ]),
      ),
    );
  }
}