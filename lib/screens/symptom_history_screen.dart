import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SymptomHistoryScreen extends StatelessWidget {
  const SymptomHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Symptom History")),
        body: Center(child: Text("User not logged in.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Symptom History")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No symptom logs found."));
          }
          final logs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index].data() as Map<String, dynamic>;
              final timestamp = log['timestamp'] as Timestamp?;
              final date = timestamp != null
                  ? timestamp.toDate().toLocal().toString()
                  : 'Unknown date';
              final symptoms = log['symptoms'] as List<dynamic>? ?? [];
              final symptomSummary = symptoms.map((symptom) {
                final name = symptom['name'] ?? 'Unknown';
                final intensity = symptom['intensity'] != null
                    ? ' (Intensity: ${symptom['intensity']})'
                    : '';
                return '$name$intensity';
              }).join(', ');

              return ListTile(
                title: Text("Date: $date"),
                subtitle: Text(symptomSummary),
              );
            },
          );
        },
      ),
    );
  }
}
