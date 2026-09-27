import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../global.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('posts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.image_not_supported, size: 60),
            SizedBox(height: 10),
            Text("Abhi koi Post nahi hai"),
            Text("Create se pehla post upload karo"),
          ]));
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (_, i) {
            var data = snapshot.data!.docs[i].data();
            return Card(child: ListTile(title: Text(data['title']?? "Post"), subtitle: Text(data['desc']?? "")));
          },
        );
      },
    );
  }
}