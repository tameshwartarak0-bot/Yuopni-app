import 'package:flutter/material.dart';

class SearchPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: TextField(autofocus: true, decoration: InputDecoration(hintText: "Reel, Video, Song, ID search karo..."))),
      body: Column(children: [
        Padding(padding: EdgeInsets.all(10), child: Text("Search me sab aayega - Reel, Video, Song, User ID")),
        Expanded(child: ListView.builder(itemCount: 15, itemBuilder: (_, i) => ListTile(leading: CircleAvatar(child: Icon(Icons.search)), title: Text("Result ${i+1} - Yuopni Post"), subtitle: Text("Reel / Video / Song")))),
      ]),
    );
  }
}