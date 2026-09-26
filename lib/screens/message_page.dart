import 'package:flutter/material.dart';
import '../global.dart';
import '../widgets/login_dialog.dart';

class MessagePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: TextField(decoration: InputDecoration(hintText: "ID Search..."))),
      body: ListView.builder(itemCount: 10, itemBuilder: (_, i) => ListTile(leading: CircleAvatar(), title: Text("user_$i"), onTap: () { if(!isLoggedIn) showDialog(context: context, builder: (_) => LoginDialog()); }))
    );
  }
}