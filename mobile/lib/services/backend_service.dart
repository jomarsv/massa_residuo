import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';

import '../data/models/estimate_response.dart';
import '../data/models/estimation_record.dart';
import '../data/models/image_analysis.dart';
import '../domain/entities/app_status.dart';

class BackendService {
  static const int _targetUploadBytes = 3 * 1024 * 1024;

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
    final preparedImage = _prepareImageForUpload(
      bytes: file.bytes,
      originalName: file.name,
    );
    final bytes = preparedImage.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Nao foi possivel ler os bytes da imagem selecionada.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/estimates/analyze-image'),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: preparedImage.filename,
        contentType: preparedImage.mediaType,
      ),
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

  _PreparedImage _prepareImageForUpload({
    required Uint8List? bytes,
    required String originalName,
  }) {
    if (bytes == null || bytes.isEmpty) {
      return _PreparedImage(
        bytes: bytes,
        filename: originalName,
        mediaType:
            _mediaTypeFromFilename(originalName) ?? MediaType('image', 'jpeg'),
      );
    }

    final originalMediaType =
        _mediaTypeFromFilename(originalName) ?? MediaType('image', 'jpeg');

    if (bytes.lengthInBytes <= _targetUploadBytes) {
      return _PreparedImage(
        bytes: bytes,
        filename: originalName,
        mediaType: originalMediaType,
      );
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception(
        'A imagem selecionada excede o limite de upload e nao pode ser comprimida automaticamente.',
      );
    }

    var workingImage = decoded;
    if (workingImage.width > 1400 || workingImage.height > 1400) {
      workingImage = img.copyResize(
        workingImage,
        width: workingImage.width >= workingImage.height ? 1400 : null,
        height: workingImage.height > workingImage.width ? 1400 : null,
        interpolation: img.Interpolation.average,
      );
    }

    for (final quality in [76, 66, 58, 50, 42]) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(workingImage, quality: quality),
      );
      if (encoded.lengthInBytes <= _targetUploadBytes) {
        return _PreparedImage(
          bytes: encoded,
          filename: _jpegFilename(originalName),
          mediaType: MediaType('image', 'jpeg'),
        );
      }
    }

    workingImage = img.copyResize(
      workingImage,
      width: workingImage.width >= workingImage.height ? 1024 : null,
      height: workingImage.height > workingImage.width ? 1024 : null,
      interpolation: img.Interpolation.average,
    );

    for (final quality in [50, 42, 35, 28]) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(workingImage, quality: quality),
      );
      if (encoded.lengthInBytes <= _targetUploadBytes) {
        return _PreparedImage(
          bytes: encoded,
          filename: _jpegFilename(originalName),
          mediaType: MediaType('image', 'jpeg'),
        );
      }
    }

    throw Exception(
      'A imagem continua grande demais para envio. Tente uma foto menor ou com menor resolucao.',
    );
  }

  MediaType? _mediaTypeFromFilename(String filename) {
    final mimeType = lookupMimeType(filename);
    if (mimeType == null || !mimeType.contains('/')) {
      return null;
    }
    final parts = mimeType.split('/');
    return MediaType(parts.first, parts.last);
  }

  String _jpegFilename(String originalName) {
    final dotIndex = originalName.lastIndexOf('.');
    if (dotIndex == -1) {
      return '$originalName.jpg';
    }
    return '${originalName.substring(0, dotIndex)}.jpg';
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

class _PreparedImage {
  const _PreparedImage({
    required this.bytes,
    required this.filename,
    required this.mediaType,
  });

  final Uint8List? bytes;
  final String filename;
  final MediaType mediaType;
}
