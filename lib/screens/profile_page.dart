import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'reel_page.dart';
import 'demo_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Map<String, dynamic>> savedAccounts = [];
  String myDisplayName = "";
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if(uid == null) return;
    await _saveCurrentAccount();
    var snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if(snap.exists){
      var d = snap.data() as Map<String,dynamic>;
      setState(() {
        myDisplayName = (d['name']?? d['displayName']?? d['username']?? "").toString();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
    await _loadSavedAccounts();
  }

  Future<void> _editName() async {
    TextEditingController ctrl = TextEditingController(text: myDisplayName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Name Edit Karo", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: "Naya naam likho",
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () async {
              String newName = ctrl.text.trim();
              if(newName.length < 2) return;
              String usernameLower = newName.toLowerCase().replaceAll(" ", "_");
              List<String> searchKeys = [];
              for(int i=1; i<=newName.length; i++) searchKeys.add(newName.substring(0,i).toLowerCase());
              for(int i=1; i<=usernameLower.length; i++) searchKeys.add(usernameLower.substring(0,i));
              await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).set({
                'name': newName,
                'displayName': newName,
                'username': usernameLower,
                'username_search': usernameLower,
                'searchKeys': searchKeys,
              }, SetOptions(merge: true));
              setState(()=> myDisplayName = newName);
              await _saveCurrentAccount();
              Navigator.pop(context);
            },
            child: Text("Save", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('yuopni_saved_accounts');
    if (data!= null) {
      setState(() {
        savedAccounts = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
    }
  }

  Future<void> _saveCurrentAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    String name = myDisplayName.isNotEmpty? myDisplayName : user.displayName?? "User";
    Map<String, dynamic> acc = {
      'uid': user.uid,
      'name': name,
      'email': user.email?? "",
      'photo': user.photoURL?? "",
    };
    List<Map<String,dynamic>> current = [];
    String? old = prefs.getString('yuopni_saved_accounts');
    if(old!=null) current = List<Map<String,dynamic>>.from(jsonDecode(old));
    current.removeWhere((a) => a['uid'] == user.uid);
    current.add(acc);
    savedAccounts = current;
    await prefs.setString('yuopni_saved_accounts', jsonEncode(savedAccounts));
    if(mounted) setState((){});
  }

  Future<void> _removeAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    savedAccounts.removeWhere((a) => a['uid'] == uid);
    await prefs.setString('yuopni_saved_accounts', jsonEncode(savedAccounts));
    setState((){});
  }

  // BINA LOGOUT HUYE NAYA ACCOUNT ADD / LOGIN
  Future<void> _addNewAccountDialog({bool isLogin = false}) async {
    TextEditingController emailCtrl = TextEditingController();
    TextEditingController passCtrl = TextEditingController();
    bool loadingDialog = false;
    bool sendingReset = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(isLogin? "Existing Account Login" : "Add New Account", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: emailCtrl, style: TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Email", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
            SizedBox(height: 10),
            TextField(controller: passCtrl, obscureText: true, style: TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Password", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
            if(isLogin)...[
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: sendingReset? SizedBox(height:16,width:16,child:CircularProgressIndicator(strokeWidth:2)) :
                TextButton(
                  onPressed: () async {
                    if(emailCtrl.text.trim().isEmpty){
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pehle email likho"), backgroundColor: Colors.red));
                      return;
                    }
                    setDialogState(()=> sendingReset = true);
                    try{
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailCtrl.text.trim());
                      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Reset link bhej diya ${emailCtrl.text.trim()} pe"), backgroundColor: Colors.green));
                    }catch(e){
                      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                    }
                    setDialogState(()=> sendingReset = false);
                  },
                  child: Text("Forgot Password?", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
            if(loadingDialog) Padding(padding: EdgeInsets.only(top: 15), child: Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.black))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: loadingDialog? null : () async {
                if(emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
                setDialogState(()=> loadingDialog = true);
                try {
                  await _saveCurrentAccount();
                  FirebaseApp tempApp = await Firebase.initializeApp(
                    name: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                    options: Firebase.app().options,
                  );
                  var tempAuth = FirebaseAuth.instanceFor(app: tempApp);
                  UserCredential tempCred;
                  if(isLogin){
                    tempCred = await tempAuth.signInWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
                  } else {
                    tempCred = await tempAuth.createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
                    await FirebaseFirestore.instance.collection('users').doc(tempCred.user!.uid).set({
                      'uid': tempCred.user!.uid,
                      'email': emailCtrl.text.trim(),
                      'name': emailCtrl.text.split('@')[0],
                      'displayName': emailCtrl.text.split('@')[0],
                      'username': emailCtrl.text.split('@')[0].toLowerCase(),
                      'username_search': emailCtrl.text.split('@')[0].toLowerCase(),
                      'photo': "",
                      'createdAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                  }
                  await tempApp.delete();

                  // FIX: signOut hata diya, direct signIn - fail hua to purana account safe rahega
                  await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());

                  if(mounted){
                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isLogin? "Login ho gaya!" : "Account add ho gaya!"), backgroundColor: Colors.green));
                    _loadProfile();
                  }
                } catch(e){
                  setDialogState(()=> loadingDialog = false);
                  String msg = e.toString();
                  if(msg.toLowerCase().contains("wrong-password") || msg.toLowerCase().contains("invalid-credential")) msg = "Wrong password";
                  if(msg.toLowerCase().contains("user-not-found")) msg = "Account nahi mila";
                  if(msg.toLowerCase().contains("email-already")) msg = "Email pehle se hai - 'Log into existing' use karo";
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
                }
              },
              child: Text(isLogin? "Login & Switch" : "Create & Switch", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchToAccount(Map<String,dynamic> acc) async {
    TextEditingController passCtrl = TextEditingController();
    bool sendingReset = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Switch to ${acc['name']}", style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Enter password for ${acc['email']}", style: TextStyle(color: Colors.grey, fontSize: 12)),
            SizedBox(height: 10),
            TextField(controller: passCtrl, obscureText: true, style: TextStyle(color: Colors.black), decoration: InputDecoration(hintText: "Password", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: sendingReset? SizedBox(height:16,width:16,child:CircularProgressIndicator(strokeWidth:2)) :
              TextButton(
                onPressed: () async {
                  setDialogState(()=> sendingReset = true);
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(email: acc['email']);
                    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Reset link bhej diya ${acc['email']} pe check karo"), backgroundColor: Colors.green, duration: Duration(seconds: 4)));
                  } catch(e){
                    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                  }
                  setDialogState(()=> sendingReset = false);
                },
                child: Text("Forgot Password?", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(context), child: Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _saveCurrentAccount();
                  // FIX: yahan signOut bilkul nahi karna
                  await FirebaseAuth.instance.signInWithEmailAndPassword(email: acc['email'], password: passCtrl.text.trim());
                  if(mounted){
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Switched to ${acc['name']}"), backgroundColor: Colors.green));
                    _loadProfile();
                  }
                } catch(e){
                  String msg = "Wrong password for ${acc['email']}";
                  if(e.toString().toLowerCase().contains("user-not-found")) msg = "Ye account Google se bana hai, password nahi hai - Delete karke naya banao";
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
                }
              },
              child: Text("Switch", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await _saveCurrentAccount();
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    await prefs.remove('userPhoto');
    await prefs.remove('isLoggedIn');
    await prefs.setBool('seenDemo', false);
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DemoPage()), (route) => false);
    }
  }

  Future<void> _deletePost(String postId, Map<String, dynamic> data) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Delete kare?", style: TextStyle(color: Colors.black)),
        content: const Text("Ye post hamesha ke liye delete ho jayegi.", style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm!= true) return;
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      if (data['videoPath']!= null && data['videoPath'].toString().isNotEmpty) {
        try { await Supabase.instance.client.storage.from('videos').remove([data['videoPath']]); } catch (_) {}
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post delete ho gayi")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _switchAccountDialog() async {
    await _loadSavedAccounts();
    await _saveCurrentAccount();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 15),
            const Text("Switch Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
            const SizedBox(height: 10),
            ListTile(
              leading: CircleAvatar(radius: 22, backgroundImage: FirebaseAuth.instance.currentUser?.photoURL!= null && FirebaseAuth.instance.currentUser!.photoURL!.isNotEmpty? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!) : null, child: (FirebaseAuth.instance.currentUser?.photoURL==null || FirebaseAuth.instance.currentUser!.photoURL!.isEmpty)? Text((myDisplayName.isNotEmpty? myDisplayName[0] : "U").toUpperCase()) : null),
              title: Text(myDisplayName.isNotEmpty? myDisplayName : FirebaseAuth.instance.currentUser?.displayName?? "Current User", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              subtitle: Text(FirebaseAuth.instance.currentUser?.email?? "", style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
            const Divider(),
          ...savedAccounts.where((a) => a['uid']!= FirebaseAuth.instance.currentUser?.uid).map((acc) => ListTile(
                  leading: acc['photo']!= ""? CircleAvatar(radius: 22, backgroundImage: NetworkImage(acc['photo'])) : CircleAvatar(radius: 22, child: Text(acc['name'].toString().isNotEmpty? acc['name'][0].toUpperCase() : "U")),
                  title: Text(acc['name'], style: const TextStyle(color: Colors.black)),
                  subtitle: Text(acc['email'], style: TextStyle(fontSize: 11)),
                  trailing: IconButton(icon: Icon(Icons.delete, size: 20, color: Colors.grey), onPressed: ()=> _removeAccount(acc['uid'])),
                  onTap: () async {
                    Navigator.pop(context);
                    await _switchToAccount(acc);
                  },
                )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.black), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text("Add Account", style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.pop(context);
                _addNewAccountDialog(isLogin: false);
              }
            )),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.black12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.login, color: Colors.black),
              label: const Text("Log into existing account", style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.pop(context);
                _addNewAccountDialog(isLogin: true);
              }
            )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text("Logout", style: TextStyle(color: Colors.white)), onPressed: () async { Navigator.pop(context); await _logout(); })),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 10),
          ],
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _sortDocs(List<QueryDocumentSnapshot> docs) {
    docs.sort((a, b) {
      var da = (a.data() as Map<String, dynamic>);
      var db = (b.data() as Map<String, dynamic>);
      Timestamp? ta = da['createdAt'] is Timestamp? da['createdAt'] : da['timestamp'] is Timestamp? da['timestamp'] : null;
      Timestamp? tb = db['createdAt'] is Timestamp? db['createdAt'] : db['timestamp'] is Timestamp? db['timestamp'] : null;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return docs;
  }

  Widget _buildMedia(String url) {
    bool isVideoFile = url.toLowerCase().contains('.mp4');
    if (url.isEmpty) {
      return Container(color: Colors.grey[300], child: const Center(child: Icon(Icons.videocam, color: Colors.black54, size: 28)));
    }
    if (isVideoFile) {
      return Container(color: Colors.black, child: Stack(fit: StackFit.expand, children: [Container(color: Colors.grey[900]), const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36))]));
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey[300], child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))),
      errorWidget: (_, __, ___) => Container(color: Colors.grey[900], child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 30))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            const SizedBox(height: 40),
            Stack(children: [
              CircleAvatar(radius: 45, backgroundColor: Colors.deepOrange, backgroundImage: user?.photoURL!= null && user!.photoURL!.isNotEmpty? NetworkImage(user!.photoURL!) : null, child: (user?.photoURL == null || user!.photoURL!.isEmpty)? Text((myDisplayName.isNotEmpty? myDisplayName[0] : "T").toUpperCase(), style: const TextStyle(fontSize: 30, color: Colors.white)) : null),
              Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: _switchAccountDialog, child: const CircleAvatar(radius: 12, backgroundColor: Colors.black, child: Icon(Icons.switch_account, size: 14, color: Colors.white))))
            ]),
            const SizedBox(height: 10),
            _loading? CircularProgressIndicator(strokeWidth: 2)
            : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(myDisplayName.isNotEmpty? myDisplayName : (user?.displayName?? "Yuopni User"), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _editName,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [Icon(Icons.edit, size: 12, color: Colors.white), SizedBox(width: 4), Text("Edit", style: TextStyle(color: Colors.white, fontSize: 12))]),
                  ),
                )
              ],
            ),
            const SizedBox(height: 4),
            Text(user?.email?? "", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(onPressed: _editName, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), child: const Text("Edit ID")),
              const SizedBox(width: 10),
              ElevatedButton(onPressed: _switchAccountDialog, child: const Text("Switch")),
              const SizedBox(width: 10),
              ElevatedButton(onPressed: _logout, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), child: const Text("Logout"))
            ]),
            const SizedBox(height: 5),
            Text("${savedAccounts.length} account saved", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            const TabBar(labelColor: Colors.black, unselectedLabelColor: Colors.grey, indicatorColor: Colors.black, indicatorWeight: 3, tabs: [Tab(icon: Icon(Icons.grid_on), text: "Posts"), Tab(icon: Icon(Icons.video_library), text: "Reels")]),
            const Divider(height: 1, color: Colors.black12),
            Expanded(
              child: TabBarView(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: user?.uid).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));
                      if (snap.data!.docs.isEmpty) return const Center(child: Text("Abhi koi Post nahi", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)));
                      var docs = _sortDocs(snap.data!.docs);
                      return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: docs.length, itemBuilder: (_, i) {
                          var doc = docs[i]; var d = doc.data() as Map<String, dynamic>; String url = (d['mediaUrl']?? d['imageUrl']?? d['videoUrl']?? d['thumbnail']?? '').toString(); bool isVideo = d['isVideo'] == true || url.toLowerCase().contains('.mp4') || d['videoUrl']!= null;
                          return GestureDetector(onTap: () { if (isVideo) Navigator.push(context, MaterialPageRoute(builder: (_) => ReelPage(initialIndex: i, myReels: docs))); }, child: Stack(fit: StackFit.expand, children: [_buildMedia(url), if (isVideo) Container(color: Colors.black26), Positioned(top: 4, right: 4, child: InkWell(onTap: () => _deletePost(doc.id, d), child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: const Icon(Icons.delete, size: 14, color: Colors.white))))]));
                        });
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: user?.uid).snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));
                      var all = _sortDocs(snap.data!.docs); var reels = all.where((doc) { var d = doc.data() as Map<String, dynamic>; var url = (d['mediaUrl']?? d['videoUrl']?? '').toString(); return d['isVideo'] == true || url.toLowerCase().contains('.mp4') || d['videoUrl']!= null; }).toList();
                      if (reels.isEmpty) return const Center(child: Text("Abhi koi Reel nahi", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)));
                      return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: reels.length, itemBuilder: (_, i) {
                          var doc = reels[i]; var d = doc.data() as Map<String, dynamic>; String thumb = (d['thumbnail']?? d['mediaUrl']?? d['videoUrl']?? '').toString();
                          return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReelPage(initialIndex: i, myReels: reels))), child: Stack(fit: StackFit.expand, children: [_buildMedia(thumb), Container(color: Colors.black26), const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32)), Positioned(top: 4, right: 4, child: InkWell(onTap: () => _deletePost(doc.id, d), child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: const Icon(Icons.delete, size: 14, color: Colors.white))))]));
                        });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}