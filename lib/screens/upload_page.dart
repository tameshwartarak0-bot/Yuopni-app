import 'package:flutter/material.dart';

class UploadPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Post / Upload")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          TextField(decoration: InputDecoration(labelText: "Title / Tag likho", border: OutlineInputBorder())),
          SizedBox(height: 12),
          TextField(decoration: InputDecoration(labelText: "Description likho", border: OutlineInputBorder()), maxLines: 3),
          SizedBox(height: 12),
          Container(height: 150, width: double.infinity, color: Colors.white12, child: Icon(Icons.video_library, size: 50)),
          SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Successful!"))); }, child: Text("Upload Karo"))),
        ]),
      ),
    );
  }
}