import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class Instruction {
  final int id;
  final String category;
  final String type;
  final String name;
  final String description;
  final Map<String, String> localizedInstructions;
  final String mediaFile;

  Instruction({
    required this.id,
    required this.category,
    required this.type,
    required this.name,
    required this.description,
    required this.localizedInstructions,
    required this.mediaFile,
  });

  factory Instruction.fromCsvLine(String line) {
    // CSV columns:
    // id;category;type;name;description;en;de;es;pl;mediaFile
    final parts = line.split(';');
    if (parts.length < 11) {
      throw FormatException('Invalid CSV line: $line');
    }
    return Instruction(
      id: int.parse(parts[0]),
      category: parts[1],
      type: parts[2],
      name: parts[3],
      description: parts[4],
      localizedInstructions: {
        'en': parts[5],
        'de': parts[6],
        'es': parts[7],
        'pl': parts[8],
      },
      mediaFile: parts[10],
    );
  }
}

class InstructionService {
  List<Instruction> _instructions = [];

  Future<void> loadInstructions() async {
    final csvString = await rootBundle.loadString('instructions.csv');
    final lines = LineSplitter.split(csvString).toList();

    // Skip header line if present
    int startIndex = 0;
    if (lines.isNotEmpty && lines[0].startsWith(';;;en')) {
      startIndex = 1;
    }

    _instructions = lines
        .sublist(startIndex)
        .where((line) => line.trim().isNotEmpty)
        .map((line) => Instruction.fromCsvLine(line))
        .toList();
  }

  List<Instruction> getInstructions() {
    return _instructions;
  }

  Instruction? getInstructionById(int id) {
    return _instructions.firstWhere((inst) => inst.id == id, orElse: () => throw Exception('Instruction not found'));
  }
}
