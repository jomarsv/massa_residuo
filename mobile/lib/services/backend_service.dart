import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../data/models/estimate_response.dart';
import '../data/models/estimation_record.dart';
import '../data/models/image_analysis.dart';
import '../domain/entities/app_status.dart';

class BackendService {
  static const int _maxUploadBytes = 4 * 1024 * 1024;

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

  Future<EstimateResponseModel> createEstimate(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/estimates'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 201) {
      throw Exception(_extractErrorMessage(response.body));
    }

    return EstimateResponseModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<EstimationRecord>> fetchHistory() async {
    final response = await _client.get(Uri.parse('$baseUrl/estimates/history'));

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body));
    }

    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((item) => EstimationRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ImageAnalysisResponse> analyzeImage(PlatformFile file) async {
    final originalBytes = file.bytes;
    final bytes = _prepareImageForUpload(originalBytes);
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Nao foi possivel ler os bytes da imagem selecionada.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/estimates/analyze-image'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: file.name),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body));
    }

    return ImageAnalysisResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Uint8List? _prepareImageForUpload(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return bytes;
    }

    if (bytes.lengthInBytes <= _maxUploadBytes) {
      return bytes;
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception(
        'A imagem selecionada excede o limite de upload e nao pode ser comprimida automaticamente.',
      );
    }

    var workingImage = decoded;
    if (workingImage.width > 1600 || workingImage.height > 1600) {
      workingImage = img.copyResize(
        workingImage,
        width: workingImage.width >= workingImage.height ? 1600 : null,
        height: workingImage.height > workingImage.width ? 1600 : null,
        interpolation: img.Interpolation.average,
      );
    }

    for (final quality in [82, 72, 62, 52, 42]) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(workingImage, quality: quality),
      );
      if (encoded.lengthInBytes <= _maxUploadBytes) {
        return encoded;
      }
    }

    workingImage = img.copyResize(
      workingImage,
      width: workingImage.width >= workingImage.height ? 1280 : null,
      height: workingImage.height > workingImage.width ? 1280 : null,
      interpolation: img.Interpolation.average,
    );

    for (final quality in [60, 50, 40, 35]) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(workingImage, quality: quality),
      );
      if (encoded.lengthInBytes <= _maxUploadBytes) {
        return encoded;
      }
    }

    throw Exception(
      'A imagem continua grande demais para envio. Tente uma foto menor ou com menor resolucao.',
    );
  }

  String _extractErrorMessage(String body) {
    try {
      final payload = jsonDecode(body);
      if (payload is Map<String, dynamic> && payload['detail'] != null) {
        return payload['detail'].toString();
      }
    } catch (_) {
      // Ignore parse failures and use fallback message below.
    }
    return 'Nao foi possivel concluir a operacao com o backend.';
  }
}
