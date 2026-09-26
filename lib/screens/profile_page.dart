import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../global.dart';
import '../widgets/login_dialog.dart';

class ProfilePage extends StatefulWidget { @override _ProfilePageState createState() => _ProfilePageState(); }
class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircleAvatar(radius: 50, backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=5")),
      SizedBox(height: 10),
      Text(isLoggedIn? "Aapka Profile" : "Demo Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(" 100 Followers "), Text(" 50 Following "), Text(" 10 Posts ")]),
      SizedBox(height: 20),
      if (!isLoggedIn) ElevatedButton(
        onPressed: () async {
          await showDialog(context: context, builder: (_) => LoginDialog());
          // Dialog band hone ke baad check karo login hua ya nahi
          if (FirebaseAuth.instance.currentUser != null) {
            setState(() {
              isLoggedIn = true;
            });
          }
        },
        child: Text("Login / Signup")
      )
      else ElevatedButton(onPressed: () { setState(() => isLoggedIn = false); }, child: Text("Logout"))
    ]));
  }
}