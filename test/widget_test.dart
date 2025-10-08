import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breath_easy/screens/breath_analysis_screen.dart';
import 'package:breath_easy/widgets/prediction_result_widget.dart';

void main() {
  testWidgets('BreathAnalysisScreen recording and prediction flow', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: const BreathAnalysisScreen(),
    ));

    // Verify initial UI elements
    expect(find.text('Breath Analysis - Record'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    // Tap the record button to start recording
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();

    // Simulate recording state
    expect(find.text('Recording...'), findsOneWidget);

    // Tap the stop button to stop recording
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();

    // Simulate processing state
    expect(find.textContaining('Processing'), findsOneWidget);

    // Simulate prediction result display
    await tester.pumpAndSettle();

    // Check if PredictionResultWidget is displayed
    expect(find.byType(PredictionResultWidget), findsOneWidget);

    // Tap retry button
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    // Verify retry state
    expect(find.textContaining('Retrying analysis'), findsOneWidget);
  });
}
