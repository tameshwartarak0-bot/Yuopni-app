import 'package:flutter/material.dart';

class ARFilterPage extends StatefulWidget {
  const ARFilterPage({super.key});
  @override State<ARFilterPage> createState() => _ARFilterPageState();
}

class _ARFilterPageState extends State<ARFilterPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Filters", style: TextStyle(color: Colors.white)),
      ),
      body: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.face_retouching_natural, size: 80, color: Colors.white24),
          SizedBox(height: 20),
          Text("AR Filters Coming Soon", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text("We are upgrading AR engine", style: TextStyle(color: Colors.white54)),
        ]),
      ),
    );
  }
}