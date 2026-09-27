import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class UploadService {
  static const String cloudName = "b7qkm3lk";
  static const String uploadPreset = "yuopni_upload";

  static Future<void> uploadPost(File file, String caption) async {
    // 1. Cloudinary pe photo upload
    var url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
    var request = http.MultipartRequest("POST", url);
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    var resBody = await response.stream.bytesToString();
    var data = json.decode(resBody);
    String imageUrl = data['secure_url'];

    // 2. Firestore me save
    var user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('posts').add({
      'imageUrl': imageUrl,
      'caption': caption,
      'uid': user?.uid,
      'email': user?.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}