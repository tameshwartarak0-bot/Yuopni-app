import 'package:flutter/material.dart';
import '../global.dart';
import '../widgets/login_dialog.dart';

class ReelPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PageView.builder(itemCount: 5, scrollDirection: Axis.vertical, itemBuilder: (_, i) {
      return Stack(children: [
        Container(color: Colors.primaries[i % Colors.primaries.length]),
        Positioned(right: 10, bottom: 100, child: Column(children: [
          IconButton(icon: Icon(Icons.favorite, size: 35), onPressed: () { if(!isLoggedIn) showDialog(context: context, builder: (_) => LoginDialog()); }),
          Text("12.5k"), SizedBox(height: 15),
          IconButton(icon: Icon(Icons.comment, size: 35), onPressed: () { if(!isLoggedIn) showDialog(context: context, builder: (_) => LoginDialog()); }),
          Text("500"), SizedBox(height: 15),
          IconButton(icon: Icon(Icons.share, size: 35), onPressed: () {}),
          Text("Share"),
        ]))
      ]);
    });
  }
}