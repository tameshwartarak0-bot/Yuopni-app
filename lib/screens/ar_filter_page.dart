import 'dart:io';
import 'package:flutter/material.dart';
import 'package:deepar_flutter/deepar_flutter.dart';

class ARFilterPage extends StatefulWidget {
  const ARFilterPage({super.key});
  @override State<ARFilterPage> createState() => _ARFilterPageState();
}

class _ARFilterPageState extends State<ARFilterPage> {
  // TERI KEY
  final String licenseKey = "d34371fc78c9d880ae286027c82450eb831d056033d75457f100d3dc8974d9d3f3ba6c77d912e58a";

  DeepArController controller = DeepArController();
  bool isInitialized = false;
  int currentFilter = 0;

  // DeepAR ke free filters - ye naam se kaam karenge
  List<String> effects = [
    "aviators",
    "bigmouth",
    "dalmatian",
    "flowers",
    "koala",
    "lion",
    "smallface",
    "teddycigar",
  ];

  @override
  void initState() {
    super.initState();
    initDeepAR();
  }

  Future<void> initDeepAR() async {
    try {
      await controller.initialize(
        licenseKey: licenseKey,
        resolution: Resolution.high,
      );
      setState(() => isInitialized = true);
      // pehla filter laga do
      controller.switchEffect(effects[0]);
    } catch (e) {
      print("DeepAR Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AR Init Error: $e")));
    }
  }

  @override
  void dispose() {
    controller.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          isInitialized ? DeepArPreview(controller) : const Center(child: CircularProgressIndicator(color: Colors.white)),
          
          // Top bar
          SafeArea(child: Padding(padding: const EdgeInsets.all(15), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(onPressed: ()=> Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white, size: 30)),
            const Text("Yuopni Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            IconButton(onPressed: ()=> controller.flipCamera(), icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 30)),
          ]))),

          // Bottom controls
          Positioned(bottom: 20, left: 0, right: 0, child: Column(children: [
            // Filter list
            SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: effects.length, itemBuilder: (_, i){
              return GestureDetector(onTap: (){
                setState(()=> currentFilter = i);
                controller.switchEffect(effects[i]);
              }, child: Container(margin: const EdgeInsets.symmetric(horizontal: 6), padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: currentFilter == i ? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(15)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.face_retouching_natural, size: 30),
                const SizedBox(height: 4),
                Text(effects[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ])));
            })),
            const SizedBox(height: 15),
            // Capture button
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(onTap: () async {
                File? file = await controller.takeScreenshot();
                if(file != null && mounted){
                  Navigator.pop(context, file); // File ko upload page pe bhej dega
                }
              }, child: Container(width: 75, height: 75, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 4)), child: const Icon(Icons.camera_alt, size: 35))),
            ]),
          ])),
        ],
      ),
    );
  }
}