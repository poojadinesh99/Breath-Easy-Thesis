import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'models/exercise_item.dart';

class ExerciseService {
  Future<List<ExerciseItem>> loadExercises() async {
    final csvString = await rootBundle.loadString('assets/data/instructions.csv');
    final lines = const LineSplitter().convert(csvString);
    final List<ExerciseItem> exercises = [];

    for (int i = 1; i < lines.length; i++) {
      final row = lines[i].split(';');
      exercises.add(ExerciseItem.fromCsvRow(row));
    }

    return exercises;
  }
}
