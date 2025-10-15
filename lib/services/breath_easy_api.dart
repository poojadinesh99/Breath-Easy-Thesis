import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class BreathEasyApi {
  static const String baseUrl = 'http://localhost:8000';

  Future<Map<String, dynamic>> predict(File audioFile, {String taskType = 'general'}) async {
    final uri = Uri.parse('$baseUrl/api/v1/unified');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path))
      ..fields['task_type'] = taskType;

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return json.decode(responseBody) as Map<String, dynamic>;
    } else {
      throw Exception('Error ${response.statusCode}: $responseBody');
    }
  }
}