import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import '../data/models/selected_image_data.dart';
import 'camera_capture_service.dart';

class WebCameraCaptureService implements CameraCaptureService {
  @override
  Future<SelectedImageData?> captureImage() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..setAttribute('capture', 'environment');

    final completer = Completer<SelectedImageData?>();

    input.onChange.listen((_) {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        return;
      }

      final reader = html.FileReader();
      reader.onLoad.listen((_) {
        final result = reader.result;
        if (result is! String || !result.startsWith('data:')) {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError('Nao foi possivel ler a imagem capturada.'),
            );
          }
          return;
        }

        if (!completer.isCompleted) {
          final base64MarkerIndex = result.indexOf(',');
          if (base64MarkerIndex == -1) {
            completer.completeError(
              StateError('Nao foi possivel decodificar a imagem capturada.'),
            );
            return;
          }

          completer.complete(
            SelectedImageData(
              fileName: file.name.isNotEmpty ? file.name : 'captura-camera.jpg',
              bytes: base64Decode(result.substring(base64MarkerIndex + 1)),
            ),
          );
        }
      });
      reader.onError.listen((_) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Nao foi possivel ler a imagem capturada.'),
          );
        }
      });
      reader.readAsDataUrl(file);
    });

    input.click();
    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => null,
    );
  }
}

CameraCaptureService createCameraCaptureService() => WebCameraCaptureService();
