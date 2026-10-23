import 'dart:io';
import 'package:flutter/material.dart';
import 'package:deepar_flutter/deepar_flutter.dart';

class ARFilterPage extends StatefulWidget {
  const ARFilterPage({super.key});
  @override
  State<ARFilterPage> createState() => _ARFilterPageState();
}

class _ARFilterPageState extends State<ARFilterPage> {
  final String licenseKey = "d34371fc78c9d880ae286027c82450eb831d056033d75457f100d3dc8974d9d3f3ba6c77d912e58a";

  DeepArController controller = DeepArController();
  bool isInitialized = false;
  int currentFilter = 0;

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
      // FIX: deepar_flutter ka sahi initialize method
      await controller.initialize(
        androidLicenseKey: licenseKey,
        iosLicenseKey: licenseKey,
        resolution: Resolution.high,
      );
      if(mounted) setState(() => isInitialized = true);
      await controller.switchEffect(effects[0]);
    } catch (e) {
      debugPrint("DeepAR Error: $e");
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AR Init Error: $e")));
      }
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
          isInitialized 
              ? DeepArPreview(controller) 
              : const Center(child: CircularProgressIndicator(color: Colors.white)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: ()=> Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 30)
                  ),
                  const Text("Yuopni Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: ()=> controller.flipCamera(),
                    icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 30)
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 20, left: 0, right: 0,
            child: Column(children: [
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: effects.length,
                  itemBuilder: (_, i){
                    bool isSelected = currentFilter == i;
                    return GestureDetector(
                      onTap: () async {
                        setState(()=> currentFilter = i);
                        try{
                          await controller.switchEffect(effects[i]);
                        }catch(e){
                          debugPrint("Switch error $e");
                        }
                      },
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.white24,
                          borderRadius: BorderRadius.circular(15),
                          border: isSelected ? Border.all(color: Colors.cyan, width: 2) : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face_retouching_natural, size: 28, color: isSelected ? Colors.black : Colors.white),
                            const SizedBox(height: 4),
                            Text(effects[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: () async {
                  try{
                    File? file = await controller.takeScreenshot();
                    if(file != null && mounted){
                      Navigator.pop(context, file);
                    }
                  }catch(e){
                    debugPrint("Screenshot error $e");
                  }
                },
                child: Container(
                  width: 75, height: 75,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 4)
                  ),
                  child: const Icon(Icons.camera_alt, size: 35, color: Colors.black)
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}