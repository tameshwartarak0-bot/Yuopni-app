import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});
  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String _verificationId = "";
  bool _otpSent = false;
  bool _loading = false;

  Future<void> _sendOtp() async {
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: "+91${_phoneController.text.trim()}",
      verificationCompleted: (cred) async {
        await FirebaseAuth.instance.signInWithCredential(cred);
      },
      verificationFailed: (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message?? "Failed")));
        setState(() => _loading = false);
      },
      codeSent: (vid, _) {
        setState(() { _verificationId = vid; _otpSent = true; _loading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP bhej diya")));
      },
      codeAutoRetrievalTimeout: (vid) { _verificationId = vid; },
    );
  }

  Future<void> _verifyOtp() async {
    setState(() => _loading = true);
    try {
      final cred = PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: _otpController.text.trim());
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final user = userCred.user;
      if(user!= null){
        // Firestore me save
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'phone': user.phoneNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('seenDemo', true);
        await prefs.setString('userPhone', user.phoneNumber?? "");
        // main.dart khud MainScreen pe le jayega
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Galat OTP: $e")));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.phone_android, size: 80, color: Colors.pink),
          const SizedBox(height: 20),
          const Text("Mobile se Login", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixText: "+91 ", prefixStyle: const TextStyle(color: Colors.white),
              hintText: "Mobile Number", hintStyle: const TextStyle(color: Colors.grey),
              filled: true, fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 15),
          if(_otpSent)
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, letterSpacing: 8),
              decoration: InputDecoration(hintText: "6-digit OTP", hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
          const SizedBox(height: 20),
          _loading? const CircularProgressIndicator(color: Colors.pink) :
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              onPressed: _otpSent? _verifyOtp : _sendOtp,
              child: Text(_otpSent? "Verify OTP" : "Send OTP", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          if(_otpSent)
            TextButton(onPressed: (){ setState((){ _otpSent = false; }); }, child: const Text("Number badlo?")),
        ]),
      ),
    );
  }
}