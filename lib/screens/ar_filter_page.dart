import 'package:flutter/material.dart';
import 'package:flutter_deepar/flutter_deepar.dart';

class ARFilterPage extends StatefulWidget {
  const ARFilterPage({super.key});
  @override State<ARFilterPage> createState() => _ARFilterPageState();
}

class _ARFilterPageState extends State<ARFilterPage> {
  final String licenseKey = "d34371fc78c9d880ae286027c82450eb831d056033d75457f100d3dc8974d9d3f3ba6c77d912e58a";

  final DeepARController _deeparController = DeepARController();
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
      await _deeparController.initialize(licenseKey: licenseKey);
      await _deeparController.startCapture();
      setState(() => isInitialized = true);
      // pehla filter load karo
      await _deeparController.loadEffect("assets/effects/${effects[0]}.deepar");
    } catch (e) {
      debugPrint("DeepAR Error: $e");
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AR Init Error: $e")));
      }
    }
  }

  @override
  void dispose() {
    _deeparController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          isInitialized 
              ? const Center(child: Text("AR Camera Started - Effect Loading...", style: TextStyle(color: Colors.white)))
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
                    onPressed: () async {
                      await _deeparController.switchCamera();
                    },
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
                          await _deeparController.loadEffect("assets/effects/${effects[i]}.deepar");
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
              Container(
                width: 75, height: 75,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 4)
                ),
                child: const Icon(Icons.camera_alt, size: 35, color: Colors.black)
              ),
            ]),
          ),
        ],
      ),
    );
  }
}