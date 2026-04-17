import 'package:image_picker/image_picker.dart';

import '../data/models/selected_image_data.dart';
import 'camera_capture_service.dart';

class IoCameraCaptureService implements CameraCaptureService {
  IoCameraCaptureService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<SelectedImageData?> captureImage() async {
    final captured = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (captured == null) {
      return null;
    }

    final bytes = await captured.readAsBytes();
    final fileName = captured.name.isNotEmpty
        ? captured.name
        : 'captura-camera.jpg';

    return SelectedImageData(
      fileName: fileName,
      bytes: bytes,
      path: captured.path,
    );
  }
}

CameraCaptureService createCameraCaptureService() => IoCameraCaptureService();
