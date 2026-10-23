import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});
  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;
  final supabase = Supabase.instance.client;

  Future<void> _sendOtp() async {
    String phone = _phoneCtrl.text.trim();
    if (!phone.startsWith('+')) {
      // India ke liye +91 lagana zaroori hai
      phone = '+91$phone';
    }
    if (phone.length < 13) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sahi number dalo")));
      return;
    }
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithOtp(phone: phone);
      setState(() {
        _otpSent = true;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP bheja $phone pe")));
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _verifyOtp() async {
    String phone = _phoneCtrl.text.trim();
    if (!phone.startsWith('+')) phone = '+91$phone';
    String otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("6 digit OTP dalo")));
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await supabase.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );
      if (res.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('seenDemo', true);
        if (mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MainScreen()), (r) => false);
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP galat: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.phone_android, size: 80, color: Colors.pink),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Mobile Number - 9876543210",
                hintStyle: const TextStyle(color: Colors.white38),
                prefixText: "+91 ",
                prefixStyle: const TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),
            if (_otpSent)
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: "OTP - 6 digit",
                  hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 1),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  counterText: "",
                ),
              ),
            const SizedBox(height: 30),
            _loading
                ? const CircularProgressIndicator(color: Colors.pink)
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: _otpSent ? _verifyOtp : _sendOtp,
                      child: Text(_otpSent ? "Verify OTP" : "Send OTP", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}