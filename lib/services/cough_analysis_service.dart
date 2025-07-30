import 'package:dio/dio.dart';

class CoughAnalysisService {
  static final Dio _dio = Dio();

  static Future<double> analyze(String fileUrl) async {
  const String backendUrl = 'https://breath-easy-thesis.onrender.com/predict';

    try {
      final response = await _dio.post(
        backendUrl,
        data: {'file_url': fileUrl},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final covidProb = response.data['covid_prob'];
        if (covidProb is double) {
          return covidProb;
        } else if (covidProb is num) {
          return covidProb.toDouble();
        } else {
          throw Exception('Invalid response format: covid_prob missing or not a number');
        }
      } else {
        throw Exception('Failed to get valid response from backend');
      }
    } catch (e) {
      throw Exception('Error during cough analysis: \$e');
    }
  }
}
