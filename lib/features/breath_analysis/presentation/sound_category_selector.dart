import 'package:flutter/material.dart';
import '../data/models/sound_sample.dart';

typedef OnCategorySelected = void Function(SoundCategory category);

class SoundCategorySelector extends StatelessWidget {
  final SoundCategory selectedCategory;
  final OnCategorySelected onCategorySelected;

  const SoundCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  String _categoryToString(SoundCategory category) {
    switch (category) {
      case SoundCategory.breathingShallow:
        return 'Breathing - Shallow';
      case SoundCategory.breathingDeep:
        return 'Breathing - Deep';
      case SoundCategory.coughShallow:
        return 'Cough - Shallow';
      case SoundCategory.coughHeavy:
        return 'Cough - Heavy';
      case SoundCategory.vowelU:
        return 'Vowel [u]';
      case SoundCategory.vowelI:
        return 'Vowel [i]';
      case SoundCategory.vowelAE:
        return 'Vowel [æ]';
      case SoundCategory.countNormal:
        return 'Counting - Normal';
      case SoundCategory.countFast:
        return 'Counting - Fast';
      default:
        return category.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: SoundCategory.values.map((category) {
        final isSelected = category == selectedCategory;
        return ChoiceChip(
          label: Text(_categoryToString(category)),
          selected: isSelected,
          onSelected: (_) => onCategorySelected(category),
        );
      }).toList(),
    );
  }
}
