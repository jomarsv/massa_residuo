import '../data/models/selected_image_data.dart';
import 'camera_capture_service_impl.dart';

abstract class CameraCaptureService {
  Future<SelectedImageData?> captureImage();
}

CameraCaptureService buildCameraCaptureService() =>
    createCameraCaptureService();
