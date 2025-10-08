import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:breath_easy/services/unified_analysis_service.dart';

class MockDio {
  Future<Response<dynamic>> post(
    String path, {
    data,
    Options? options,
  }) async {
    return Response<dynamic>(
      data: {
        'predictions': {'covid': 0.7, 'flu': 0.2, 'normal': 0.1},
        'label': 'covid',
        'confidence': 0.7,
        'source': 'local',
      },
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  group('UnifiedAnalysisService', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      UnifiedAnalysisService.setDio(mockDio as Dio);
    });

    test('analyzeUnified returns parsed predictions on success', () async {
      final fileUrl = 'https://example.com/audio.wav';

      final result = await UnifiedAnalysisService.analyzeUnified(fileUrl);

      expect(result['predictions'], isA<Map<String, double>>());
      expect(result['label'], 'covid');
      expect(result['confidence'], 0.7);
      expect(result['source'], 'local');
    });

    test('analyzeUnified throws exception on error', () async {
      UnifiedAnalysisService.setDio(Dio()); // Reset to real Dio to simulate error

      expect(
        () async => await UnifiedAnalysisService.analyzeUnified('bad_url'),
        throwsException,
      );
    });
  });
}
