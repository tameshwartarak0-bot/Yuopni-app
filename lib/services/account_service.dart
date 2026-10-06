import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AccountService {
  static const _key = "saved_accounts";

  static Future<void> saveAccount(User user) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList(_key)?? [];

    Map<String, dynamic> acc = {
      'uid': user.uid,
      'email': user.email,
      'name': user.displayName?? "User",
      'photo': user.photoURL?? "",
    };

    // duplicate hatao
    accounts.removeWhere((e) => jsonDecode(e)['uid'] == user.uid);
    accounts.add(jsonEncode(acc));
    await prefs.setStringList(_key, accounts);
  }

  static Future<List<Map<String,dynamic>>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList(_key)?? [];
    return accounts.map((e) => jsonDecode(e) as Map<String,dynamic>).toList();
  }

  static Future<void> removeAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList(_key)?? [];
    accounts.removeWhere((e) => jsonDecode(e)['uid'] == uid);
    await prefs.setStringList(_key, accounts);
  }

  // Bina logout huye naya account login karna
  static Future<UserCredential> createNewAccount(String email, String password) async {
    // Dusra firebase app
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'tempApp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    var tempAuth = FirebaseAuth.instanceFor(app: tempApp);
    var cred = await tempAuth.createUserWithEmailAndPassword(email: email, password: password);
    await tempApp.delete();
    await saveAccount(cred.user!);
    return cred;
  }

  static Future<UserCredential> loginNewAccount(String email, String password) async {
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'tempApp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    var tempAuth = FirebaseAuth.instanceFor(app: tempApp);
    var cred = await tempAuth.signInWithEmailAndPassword(email: email, password: password);
    await tempApp.delete();
    await saveAccount(cred.user!);
    // Ab main app me us account se login karao
    var mainCred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    return mainCred;
  }
}