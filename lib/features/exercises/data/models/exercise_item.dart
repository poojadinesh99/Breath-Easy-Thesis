class ExerciseItem {
  final String id;
  final String module;
  final String category;
  final String name;
  final String shortDescription;
  final String instructions;
  final String nameDe;
  final String shortDescriptionDe;
  final String instructionsDe;
  final String nameEs;
  final String shortDescriptionEs;
  final String instructionsEs;
  final String namePl;
  final String shortDescriptionPl;
  final String instructionsPl;
  final String mediaFile;

  ExerciseItem({
    required this.id,
    required this.module,
    required this.category,
    required this.name,
    required this.shortDescription,
    required this.instructions,
    required this.nameDe,
    required this.shortDescriptionDe,
    required this.instructionsDe,
    required this.nameEs,
    required this.shortDescriptionEs,
    required this.instructionsEs,
    required this.namePl,
    required this.shortDescriptionPl,
    required this.instructionsPl,
    required this.mediaFile,
  });

  factory ExerciseItem.fromCsvRow(List<String> row) {
    return ExerciseItem(
      id: row.length > 0 ? row[0] : '',
      module: row.length > 1 ? row[1] : '',
      category: row.length > 2 ? row[2] : '',
      name: row.length > 3 ? row[3] : '',
      shortDescription: row.length > 4 ? row[4] : '',
      instructions: row.length > 5 ? row[5] : '',
      nameDe: row.length > 6 ? row[6] : '',
      shortDescriptionDe: row.length > 7 ? row[7] : '',
      instructionsDe: row.length > 8 ? row[8] : '',
      nameEs: row.length > 9 ? row[9] : '',
      shortDescriptionEs: row.length > 10 ? row[10] : '',
      instructionsEs: row.length > 11 ? row[11] : '',
      namePl: row.length > 12 ? row[12] : '',
      shortDescriptionPl: row.length > 13 ? row[13] : '',
      instructionsPl: row.length > 14 ? row[14] : '',
      mediaFile: row.length > 15 ? row[15] : '',
    );
  }
}
