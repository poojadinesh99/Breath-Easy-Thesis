import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

/// A comprehensive StatefulWidget that demonstrates:
/// - JSON POST requests with Dio
/// - Loading states
/// - Error handling
/// - Response display
/// - Form validation
class ApiJsonPostWidget extends StatefulWidget {
  final String apiEndpoint;
  final Map<String, dynamic>? defaultData;
  final String title;

  const ApiJsonPostWidget({
    super.key,
    required this.apiEndpoint,
    this.defaultData,
    this.title = 'JSON POST Demo',
  });

  @override
  State<ApiJsonPostWidget> createState() => _ApiJsonPostWidgetState();
}

class _ApiJsonPostWidgetState extends State<ApiJsonPostWidget> {
  final Dio _dio = Dio();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _responseData;
  String? _source;

  @override
  void initState() {
    super.initState();
    if (widget.defaultData != null) {
      _nameController.text = widget.defaultData?['name'] ?? '';
      _emailController.text = widget.defaultData?['email'] ?? '';
      _messageController.text = widget.defaultData?['message'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _responseData = null;
      _source = null;
    });

    try {
      final jsonData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'message': _messageController.text,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await _dio.post(
        widget.apiEndpoint,
        data: jsonData,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      setState(() {
        _isLoading = false;
        if (response.statusCode == 200 || response.statusCode == 201) {
          _responseData = response.data is Map<String, dynamic> 
              ? response.data 
              : {'response': response.data};
          _source = response.data?['source'] ?? 'api';
        } else {
          _errorMessage = 'Server error: ${response.statusCode}';
        }
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.type == DioExceptionType.connectionTimeout) {
          _errorMessage = 'Connection timeout';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          _errorMessage = 'Receive timeout';
        } else if (e.type == DioExceptionType.badResponse) {
          _errorMessage = 'Server error: ${e.response?.statusCode}';
        } else if (e.type == DioExceptionType.cancel) {
          _errorMessage = 'Request cancelled';
        } else {
          _errorMessage = 'Network error: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unexpected error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              
              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              
              // Message Field
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitData,
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Sending...'),
                          ],
                        )
                      : const Text('Send JSON Data'),
                ),
              ),
              
              // Error Display
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Response Display
              if (_responseData != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Success!',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Source: ${_source ?? 'Unknown'}',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                      if (_responseData?['prediction'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Prediction: ${_responseData!['prediction']}',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Full Response: ${_responseData.toString()}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Example usage widget
class ApiJsonPostExample extends StatelessWidget {
  const ApiJsonPostExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JSON POST Demo'),
      ),
      body: SingleChildScrollView(
        child: ApiJsonPostWidget(
          apiEndpoint: 'https://jsonplaceholder.typicode.com/posts',
          title: 'JSON POST with Dio',
          defaultData: {
            'name': 'Test User',
            'email': 'test@example.com',
            'message': 'Hello from Flutter!',
          },
        ),
      ),
    );
  }
}
