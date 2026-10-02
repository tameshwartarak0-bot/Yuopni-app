import 'dart:io';
import 'package:flutter/material.dart';
import '../screens/camera_page.dart';
import '../screens/upload_page.dart';

class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});
  static void show(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => const CreateSheet());
  }
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(20), height: 300, decoration: const BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Column(children:[
      Container(width:40,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(10))), const SizedBox(height:20),
      ListTile(leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.videocam)), title: const Text("Create - Reel + Song", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: const Text("Timer + Song ke sath", style: TextStyle(color: Colors.white54)), onTap: () async {
        Navigator.pop(context);
        final result = await Navigator.push(context, MaterialPageRoute(builder: (_)=> const CameraPage()));
        if(result!=null && result['file']!=null){
          File file=result['file']; bool isVideo=result['isVideo']??false; bool isLong=result['isLong']??false; String song=result['song']??"No Song";
          if(context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_)=> UploadPage(prefile: file, isVideo: isVideo, isLong: isLong, songName: song)));
        }
      }),
      const Divider(color: Colors.white24),
      ListTile(leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.upload)), title: const Text("Post / Upload 90m", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onTap: (){ Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_)=> const UploadPage())); }),
    ]));
  }
}