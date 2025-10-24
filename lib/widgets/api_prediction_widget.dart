import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class ApiPredictionWidget extends StatefulWidget {
  final String apiUrl;

  const ApiPredictionWidget({super.key, required this.apiUrl});

  @override
  State<ApiPredictionWidget> createState() => _ApiPredictionWidgetState();
}

class _ApiPredictionWidgetState extends State<ApiPredictionWidget> {
  final Dio _dio = Dio();
  bool _isLoading = false;
  String? _prediction;
  String? _source;
  String? _error;

  Future<void> _postData(Map<String, dynamic> jsonData) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _prediction = null;
      _source = null;
    });

    try {
      final response = await _dio.post(widget.apiUrl, data: jsonData);
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _prediction = data['prediction']?.toString() ?? 'No prediction';
          _source = data['source']?.toString() ?? 'Unknown source';
        });
      } else {
        setState(() {
          _error = 'Error: Received status code ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Request failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Example JSON data to post
  final Map<String, dynamic> exampleJson = {
    "file": null,
    "audio_url": "https://example.com/audio.wav"
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : () => _postData(exampleJson),
          child: Text('Send Prediction Request'),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red),
            ),
          ),
        if (_prediction != null && _source != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Prediction: $_prediction\nSource: $_source',
              style: TextStyle(fontSize: 16),
            ),
          ),
      ],
    );
  }
}
