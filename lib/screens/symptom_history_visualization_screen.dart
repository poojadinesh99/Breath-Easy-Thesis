import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class SymptomHistoryVisualizationScreen extends StatelessWidget {
  const SymptomHistoryVisualizationScreen({super.key});

  Future<List<charts.Series<SymptomData, DateTime>>> _createChartData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return [];
    }

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .orderBy('timestamp')
        .get();

    Map<String, List<SymptomData>> symptomMap = {};

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp == null) continue;
      final date = timestamp.toDate();

      final symptoms = data['symptoms'] as List<dynamic>? ?? [];
      for (var symptom in symptoms) {
        final name = symptom['name'] ?? 'Unknown';
        final intensity = (symptom['intensity'] ?? 0).toDouble();

        symptomMap.putIfAbsent(name, () => []);
        symptomMap[name]!.add(SymptomData(date, intensity));
      }
    }

    List<charts.Series<SymptomData, DateTime>> seriesList = [];

    symptomMap.forEach((name, dataPoints) {
      seriesList.add(
        charts.Series<SymptomData, DateTime>(
          id: name,
          colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
          domainFn: (SymptomData sd, _) => sd.date,
          measureFn: (SymptomData sd, _) => sd.intensity,
          data: dataPoints,
        ),
      );
    });

    return seriesList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Symptom History Visualization'),
      ),
      body: FutureBuilder<List<charts.Series<SymptomData, DateTime>>>(
        future: _createChartData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No symptom data available.'));
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: charts.TimeSeriesChart(
              snapshot.data!,
              animate: true,
              dateTimeFactory: const charts.LocalDateTimeFactory(),
              behaviors: [
                charts.SeriesLegend(),
                charts.PanAndZoomBehavior(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SymptomData {
  final DateTime date;
  final double intensity;

  SymptomData(this.date, this.intensity);
}
