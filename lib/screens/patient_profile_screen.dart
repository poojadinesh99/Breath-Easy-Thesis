import 'package:flutter/material.dart';
import 'patient_intake_form.dart';
import 'symptom_tracker_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  _PatientProfileScreenState createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient Profile'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Intake Form'),
            Tab(text: 'Symptom Tracker'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PatientIntakeFormScreen(),
          SymptomTrackerScreen(),
        ],
      ),
    );
  }
}
