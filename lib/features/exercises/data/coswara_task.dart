class CoswaraTask {
  final String category;        // e.g. "Breathing", "Cough", "Speech"
  final String sampleName;      // e.g. "Breathing-deep"
  final String description;     // User-friendly description

  CoswaraTask({
    required this.category,
    required this.sampleName,
    required this.description,
  });
}

final List<CoswaraTask> coswaraTasks = [
  CoswaraTask(
    category: "Breathing",
    sampleName: "Breathing-shallow",
    description: "Take a few gentle breaths in and out, without straining your lungs.",
  ),
  CoswaraTask(
    category: "Breathing",
    sampleName: "Breathing-deep",
    description: "Take a few deep breaths, filling your lungs fully and exhaling slowly.",
  ),
  CoswaraTask(
    category: "Cough",
    sampleName: "Cough-shallow",
    description: "Cough gently a few times without putting too much pressure on your lungs.",
  ),
  CoswaraTask(
    category: "Cough",
    sampleName: "Cough-heavy",
    description: "Cough a few times with more force, but only as comfortable for you.",
  ),
  CoswaraTask(
    category: "Vowel Phonation",
    sampleName: "Vowel-[u]",
    description: "Sustain the vowel sound 'u' as in 'boot' for a few seconds.",
  ),
  CoswaraTask(
    category: "Vowel Phonation",
    sampleName: "Vowel-[i]",
    description: "Sustain the vowel sound 'i' as in 'beet' for a few seconds.",
  ),
  CoswaraTask(
    category: "Vowel Phonation",
    sampleName: "Vowel-[æ]",
    description: "Sustain the vowel sound 'æ' as in 'bat' for a few seconds.",
  ),
  CoswaraTask(
    category: "Speech",
    sampleName: "Counting-normal",
    description: "Count from 1 to 20 at a normal pace.",
  ),
  CoswaraTask(
    category: "Speech",
    sampleName: "Counting-fast",
    description: "Count from 1 to 20 as fast as you comfortably can.",
  ),
];
