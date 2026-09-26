import 'package:flutter/material.dart';
import '../global.dart';
import '../widgets/login_dialog.dart';

class HomePage extends StatelessWidget {
  final filters = ["All", "For You", "Trending", "Movie", "Song", "Comedy", "Gaming"];
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 10, itemBuilder: (_, i) => Padding(padding: EdgeInsets.all(8), child: Column(children: [CircleAvatar(radius: 28, backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=${i+1}")), Text("user $i")])))),
        SizedBox(height: 40, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: filters.length, itemBuilder: (_, i) => Container(margin: EdgeInsets.symmetric(horizontal: 5), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), child: Text(filters[i])))),
        Expanded(child: ListView.builder(itemCount: 5, itemBuilder: (_, i) => Card(color: Colors.white10, child: ListTile(title: Text("Demo Post ${i+1}"), subtitle: Text("Like/Comment par login aayega"), trailing: Icon(Icons.more_vert), onTap: () { if(!isLoggedIn) showDialog(context: context, builder: (_) => LoginDialog()); }))))
      ],
    );
  }
}