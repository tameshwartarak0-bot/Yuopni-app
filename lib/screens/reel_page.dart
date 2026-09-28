import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReelPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reels').orderBy('createdAt', descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text("Koi Reel nahi hai"));

        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return ReelItem(data: data);
          },
        );
      },
    );
  }
}

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> data;
  ReelItem({required this.data});
  @override
  _ReelItemState createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  VideoPlayerController? _controller;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    String videoUrl = (widget.data['mediaUrl']?? widget.data['videoUrl']?? '').toString();
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _isInit && _controller!= null
           ? VideoPlayer(_controller!)
            : Container(color: Colors.black, child: Center(child: CircularProgressIndicator())),
        Positioned(
          bottom: 20, left: 15, right: 15,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.data['title']?? '', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Row(children: [
              CircleAvatar(radius: 15, backgroundImage: widget.data['userPhoto']!= null? NetworkImage(widget.data['userPhoto']) : null),
              SizedBox(width: 8),
              Text(widget.data['username']?? 'User', style: TextStyle(color: Colors.white)),
            ]),
          ]),
        ),
      ],
    );
  }
}