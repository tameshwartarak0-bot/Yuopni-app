import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class UploadService {
  static Future<void> uploadPost(File file, String caption) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('posts/$uid/$id.jpg');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    final data = {
      'postId': id,
      'uid': uid,
      'username': FirebaseAuth.instance.currentUser!.displayName?? 'Yuopni User',
      'userPhoto': FirebaseAuth.instance.currentUser!.photoURL?? '',
      'imageUrl': url,
      'caption': caption,
      'likes': [],
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'post',
      'isDemo': true, // Ye line se Demo page me bhi aayega
    };

    await FirebaseFirestore.instance.collection('posts').doc(id).set(data);
    await FirebaseFirestore.instance.collection('demo_posts').doc(id).set(data); // Demo ke liye
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('my_posts').doc(id).set(data);
  }

  static Future<void> uploadReel(File file, String songUrl, String songName) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('reels/$uid/$id.mp4');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    final data = {
      'postId': id,
      'uid': uid,
      'username': FirebaseAuth.instance.currentUser!.displayName?? 'Yuopni User',
      'userPhoto': FirebaseAuth.instance.currentUser!.photoURL?? '',
      'videoUrl': url,
      'songUrl': songUrl,
      'songName': songName,
      'likes': [],
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'reel',
      'isDemo': true,
    };

    await FirebaseFirestore.instance.collection('reels').doc(id).set(data);
    await FirebaseFirestore.instance.collection('posts').doc(id).set(data);
    await FirebaseFirestore.instance.collection('demo_posts').doc(id).set(data);
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('my_posts').doc(id).set(data);
  }
}