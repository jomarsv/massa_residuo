import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/entities/app_status.dart';

class BackendService {
  BackendService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? _resolveBaseUrl();

  final http.Client _client;
  final String baseUrl;

  static String _resolveBaseUrl() {
    const configuredBaseUrl = String.fromEnvironment('BACKEND_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    if (kIsWeb) {
      return '/api/v1';
    }

    return 'http://10.0.2.2:8000/api/v1';
  }

  Future<AppStatus> checkStatus() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/health'));
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        if (payload['status'] == 'ok') {
          return const AppStatus(
            isBackendReachable: true,
            message: 'Backend FastAPI online e pronto para a Fase 2.',
          );
        }
      }
      return const AppStatus(
        isBackendReachable: false,
        message: 'Backend respondeu fora do esperado.',
      );
    } catch (_) {
      return const AppStatus(
        isBackendReachable: false,
        message: 'Backend indisponivel. O app segue em modo estrutural local.',
      );
    }
  }
}
