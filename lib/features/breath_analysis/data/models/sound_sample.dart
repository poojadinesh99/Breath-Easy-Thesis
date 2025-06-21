enum SoundCategory {
  breathingShallow,
  breathingDeep,
  coughShallow,
  coughHeavy,
  vowelU,
  vowelI,
  vowelAE,
  countNormal,
  countFast,
}

class SoundSample {
  final SoundCategory category;
  final String filePath;
  final DateTime recordedAt;

  SoundSample({
    required this.category,
    required this.filePath,
    required this.recordedAt,
  });
}
