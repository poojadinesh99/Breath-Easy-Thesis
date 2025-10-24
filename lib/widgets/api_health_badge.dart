import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ApiHealthBadge extends StatefulWidget {
  const ApiHealthBadge({super.key});

  @override
  State<ApiHealthBadge> createState() => _ApiHealthBadgeState();
}

class _ApiHealthBadgeState extends State<ApiHealthBadge> {
  bool _loading = true;
  bool _ok = false;
  Map<String, dynamic>? _status;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Refresh status every 30 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final ok = await ApiService.checkApiHealth().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (!mounted) return;

      setState(() {
        _ok = ok;
        _loading = false;
        _status = ok 
          ? {'status': 'connected'} 
          : {'status': 'error', 'message': 'API is not responding'};
      });

      if (ok) {
        try {
          final status = await ApiService.getApiStatus().timeout(
            const Duration(seconds: 5),
            onTimeout: () => {'status': 'timeout'},
          );
          if (mounted) {
            setState(() {
              _status = status;
            });
          }
        } catch (e) {
          // Keep the basic status if detailed status fails
          if (mounted) {
            setState(() {
              _status = {'status': 'connected', 'details': 'Limited info'};
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _status = {'status': 'error', 'error': e.toString()};
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('API Status'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${_ok ? "Connected" : "Disconnected"}'),
                const SizedBox(height: 8),
                if (_status != null) ...[
                  for (final entry in _status!.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${entry.key}: ${entry.value}'),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _refresh();
                },
                child: const Text('Refresh'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _ok ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _ok ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              _ok ? 'API' : 'API',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
