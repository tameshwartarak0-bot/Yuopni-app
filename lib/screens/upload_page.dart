import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../global.dart';
import '../widgets/login_dialog.dart';

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
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              // 1. Check karo login hai ya nahi
              if (FirebaseAuth.instance.currentUser == null && !isLoggedIn) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Post karne ke liye pehle Login karo")));
                await showDialog(context: context, builder: (_) => LoginDialog());
                return;
              }
              // 2. Agar login hai to hi upload
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Successful!")));
            },
            child: Text("Upload Karo")
          )),
        ]),
      ),
    );
  }
}