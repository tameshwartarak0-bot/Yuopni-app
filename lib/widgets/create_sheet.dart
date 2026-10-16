import 'dart:io';
import 'package:flutter/material.dart';
import '../screens/camera_page.dart' as cam;
import '../screens/upload_page.dart';

class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const CreateSheet()
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 300,
      child: Column(children:[
        Container(width:40,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(10))),
        const SizedBox(height:20),
        ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.videocam, color: Colors.white)),
          title: const Text("Create", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onTap: () async {
            Navigator.pop(context);
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_)=> cam.CameraPage()));
            if(result!=null && result['file']!=null){
              File file=result['file'];
              if(context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_)=> UploadPage(prefile: file, isVideo: result['isVideo'], isLong: result['isLong'], songName: result['song'])));
              }
            }
          }
        ),
        ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.upload, color: Colors.white)),
          title: const Text("Upload", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onTap: (){
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_)=> const UploadPage()));
          }
        ),
      ])
    );
  }
}