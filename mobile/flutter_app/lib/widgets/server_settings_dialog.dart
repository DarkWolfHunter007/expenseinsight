import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/api_constants.dart';
import '../providers/analytics_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/api_service.dart';

class ServerSettingsDialog extends StatefulWidget {
  const ServerSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ServerSettingsDialog(),
    );
  }

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  late final TextEditingController _controller;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiConstants.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testResult = 'Please enter a valid URL';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final uri = Uri.parse('$cleanUrl/health');
      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'X-Tunnel-Skip-Anti-Abuse-Header': 'true',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        try {
          final data = json.decode(res.body);
          if (data is Map && data['product'] == 'ExpenseInsight' && data['status'] == 'online') {
            setState(() {
              _isTesting = false;
              _testSuccess = true;
              _testResult = 'ExpenseInsight API Online (v${data['version'] ?? '1.0.0'})';
            });
            return;
          } else {
            setState(() {
              _isTesting = false;
              _testSuccess = false;
              _testResult = 'Received 200 OK from non-ExpenseInsight service. Make sure the FastAPI server is running on port 8000 and port visibility is Public in VS Code.';
            });
            return;
          }
        } catch (_) {
          setState(() {
            _isTesting = false;
            _testSuccess = false;
            _testResult = 'Returned HTML/proxy page instead of JSON. Check if your tunnel requires login or set port visibility to Public in VS Code.';
          });
          return;
        }
      } else {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testResult = 'Server replied with HTTP ${res.statusCode} (Endpoint: $cleanUrl/health)';
        });
      }
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testResult = 'Connection failed: Cannot reach backend server.\nMake sure uvicorn is running.';
      });
    }
  }

  Future<void> _saveUrl() async {
    final input = _controller.text.trim();
    await ApiService().updateBaseUrl(input.isNotEmpty ? input : null);
    if (!mounted) return;

    // Refresh active providers
    Provider.of<AnalyticsProvider>(context, listen: false).fetchAnalytics();
    Provider.of<ForecastProvider>(context, listen: false).fetchForecast();
    Provider.of<TransactionProvider>(context, listen: false).fetchTransactions();

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('API Base URL updated to: ${ApiConstants.baseUrl}'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Backend Connection',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure the FastAPI endpoint. Paste your VS Code forwarded public URL or select a preset below:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'https://xxxx-8000.devtunnels.ms or http://10.0.2.2:8000',
                  prefixIcon: const Icon(Icons.link_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => _controller.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Localhost (8000)'),
                    onPressed: () => setState(() => _controller.text = 'http://127.0.0.1:8000'),
                  ),
                  ActionChip(
                    label: const Text('Android Emulator (10.0.2.2)'),
                    onPressed: () => setState(() => _controller.text = 'http://10.0.2.2:8000'),
                  ),
                ],
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _testSuccess
                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                        : const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _testSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _testSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: _testSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _testSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          ),
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
      actions: [
        OutlinedButton.icon(
          onPressed: _isTesting ? null : _testConnection,
          icon: _isTesting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.speed_rounded, size: 16),
          label: const Text('Test Connection'),
        ),
        FilledButton(
          onPressed: _saveUrl,
          child: const Text('Save & Apply'),
        ),
      ],
    );
  }
}
