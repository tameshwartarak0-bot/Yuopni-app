import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReelPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('reels').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.video_library_outlined, size: 60),
            SizedBox(height: 10),
            Text("Abhi koi Reel nahi hai"),
            Text("Upload karke reel banao"),
          ]));
        }
        return PageView.builder(
          itemCount: snapshot.data!.docs.length,
          scrollDirection: Axis.vertical,
          itemBuilder: (_, i) {
            var data = snapshot.data!.docs[i].data();
            return Container(color: Colors.black, child: Center(child: Text(data['title']?? "Reel", style: TextStyle(color: Colors.white))));
          },
        );
      },
    );
  }
}