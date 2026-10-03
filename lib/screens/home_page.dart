import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../global.dart';
import 'reel_page.dart'; // isko add karo

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: isUploadingGlobal,
            builder: (_, uploading, __) {
              if (!uploading) return const SizedBox.shrink();
              return ValueListenableBuilder<double>(
                valueListenable: globalUploadProgress,
                builder: (_, p, __) {
                  return Container(
                    color: Colors.green.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cloud_upload, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text("${p.toStringAsFixed(0)}% Upload ho raha hai...", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))),
                            Text("${p.toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: p / 100, minHeight: 4, color: Colors.green, backgroundColor: Colors.white24),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Abhi koi Post nahi", style: TextStyle(color: Colors.white)));
                }
                var docs = snapshot.data!.docs;
                return ListView.builder(
                  cacheExtent: 500,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    var data = docs[i].data() as Map<String, dynamic>;
                    String mediaUrl = (data['mediaUrl']?? data['imageUrl']?? data['videoUrl']?? '').toString();
                    String thumbUrl = (data['thumbnail']?? mediaUrl).toString();
                    bool isVideo = data['isVideo'] == true || mediaUrl.toLowerCase().contains(".mp4");
                    String title = (data['title']?? data['caption']?? '').toString();

                    return InkWell(
                      onTap: () {
                        // Click pe ReelPage kholo - Instagram jaisa
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ReelPage(myReels: docs, initialIndex: i),
                        ));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.grey[900],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundImage: (data['userPhoto']?? '').toString().isNotEmpty? NetworkImage(data['userPhoto']) : null,
                                child: (data['userPhoto']?? '').toString().isEmpty? const Icon(Icons.person) : null,
                              ),
                              title: Text(data['username']?? 'User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2),
                            ),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: isVideo? thumbUrl : mediaUrl,
                                  width: double.infinity,
                                  height: 400,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(height: 400, color: Colors.black12),
                                  errorWidget: (_, __, ___) => Container(height: 400, color: Colors.black, child: const Icon(Icons.broken_image, color: Colors.white)),
                                ),
                                if (isVideo)
                                  const Icon(Icons.play_circle_fill, size: 60, color: Colors.white70),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}