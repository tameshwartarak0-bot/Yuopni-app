import 'package:flutter/material.dart';
import '../screens/camera_page.dart';
import '../screens/upload_page.dart';

class CreateSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(padding: EdgeInsets.all(20), height: 300, child: Column(children: [
      ListTile(leading: Icon(Icons.videocam), title: Text("Create - Reel / Story"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CameraPage()))),
      Divider(),
      ListTile(leading: Icon(Icons.upload), title: Text("Post / Upload - Long Video"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UploadPage()))),
    ]));
  }
}