import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<ReordaUser?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return ReordaUser.fromMap(doc.data()!, uid);
    }
    return null;
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? entityId,
  }) async {
    final creds = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = ReordaUser(
      uid: creds.user!.uid,
      email: email,
      name: name,
      role: role,
      entityId: entityId,
    );

    await _firestore.collection('users').doc(creds.user!.uid).set(user.toMap());
    return creds;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}