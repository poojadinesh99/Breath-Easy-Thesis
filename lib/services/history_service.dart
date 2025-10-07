class HistoryService {
  static final List<Map<String, dynamic>> _history = [
    {
      'label': 'Clear',
      'confidence': 0.95,
      'source': 'Breath Analysis',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'predictions': {
        'Clear': 0.95,
        'Wheezing': 0.03,
        'Crackles': 0.02,
      },
    },
    {
      'label': 'Wheezing',
      'confidence': 0.87,
      'source': 'Speech Analysis',
      'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
      'predictions': {
        'Wheezing': 0.87,
        'Clear': 0.10,
        'Stridor': 0.03,
      },
    },
    {
      'label': 'Clear',
      'confidence': 0.92,
      'source': 'Breath Analysis',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      'predictions': {
        'Clear': 0.92,
        'Wheezing': 0.05,
        'Crackles': 0.03,
      },
    },
    {
      'label': 'Crackles',
      'confidence': 0.78,
      'source': 'Demo Analysis',
      'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      'predictions': {
        'Crackles': 0.78,
        'Clear': 0.15,
        'Wheezing': 0.07,
      },
    },
  ];

  static void addEntry(Map<String, dynamic> entry) {
    _history.insert(0, entry); // insert at top (most recent first)
  }

  static List<Map<String, dynamic>> getHistory() {
    return _history;
  }
}
