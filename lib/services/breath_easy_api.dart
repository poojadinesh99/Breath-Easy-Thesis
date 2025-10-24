import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'backend_config.dart';

class BreathEasyApi {
  Future<Map<String, dynamic>> predict(File audioFile, {String taskType = 'general'}) async {
    final endpointUrl = await BackendConfig.unifiedAnalysis;
    final uri = Uri.parse(endpointUrl);
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