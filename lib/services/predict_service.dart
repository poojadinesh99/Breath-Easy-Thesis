import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_config.dart';

class PredictService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    followRedirects: true,
  ));

  Future<String> getInferenceSource() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('inference_source') ?? 'default';
  }

  Future<Map<String, dynamic>> uploadAndPredict(File file, {String? inference}) async {
    inference ??= await getInferenceSource();
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: 'input.wav', contentType: MediaType('audio', 'wav')),
      if (inference != 'default') 'inference': inference,
    });
    try {
      final resp = await _dio.post('${BackendConfig.baseUrl}/api/v1/unified', data: form);
      return Map<String, dynamic>.from(resp.data as Map);
    } on DioException catch (e) {
      // simple one-shot retry for connection timeout
      if (e.type == DioExceptionType.connectionTimeout) {
        final resp = await _dio.post('${BackendConfig.baseUrl}/api/v1/unified', data: form);
        return Map<String, dynamic>.from(resp.data as Map);
      }
      rethrow;
    }
  }
}
