import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Notifications")),
      body: ListView.builder(
        itemCount: 12,
        itemBuilder: (_, i) => ListTile(
          leading: CircleAvatar(backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=${i+2}")),
          title: Text("user_$i ne aapko like kiya"),
          subtitle: Text("${i+1} minute pehle"),
          trailing: Icon(Icons.favorite, color: Colors.red),
        ),
      ),
    );
  }
}