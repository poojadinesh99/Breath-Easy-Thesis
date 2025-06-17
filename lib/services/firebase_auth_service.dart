import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result =
          await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      throw Exception("Failed to sign in: $e");
    }
  }

  // Register with email and password
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result =
          await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      if (user != null) {
        // Create user document in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } catch (e) {
      throw Exception("Failed to sign up: $e");
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Store symptom log in Firestore
  Future<void> logSymptom(Map<String, dynamic> symptomData) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception("User is not logged in");
      }
      // Store symptom log in Firestore under the user's document
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('symptoms')
          .add(symptomData);
    } catch (e) {
      throw Exception("Failed to log symptom: $e");
    }
  }

  // Store a full session: patient + symptoms
  Future<void> logSession({
    required String patientName,
    required int age,
    required bool consent,
    required List<Map<String, dynamic>> symptoms,
    String? customSymptom,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) throw Exception("User is not logged in");

      final sessionData = {
        'patientName': patientName,
        'age': age,
        'consent': consent,
        'timestamp': FieldValue.serverTimestamp(),
        'symptoms': symptoms,
        'customSymptom': customSymptom,
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .add(sessionData);
    } catch (e) {
      throw Exception("Failed to log session: $e");
    }
  }
}
