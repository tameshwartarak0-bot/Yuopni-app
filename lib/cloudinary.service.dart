import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String cloudName = "b7qkm3lk";
  static const String uploadPreset = "yuopni_upload";

  static Future<String?> pickAndUpload() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    var url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
    var request = http.MultipartRequest("POST", url);
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', image.path));

    var response = await request.send();
    var resBody = await response.stream.bytesToString();
    var data = json.decode(resBody);

    return data['secure_url'];
  }
}