import 'dart:typed_data';

class SelectedImageData {
  const SelectedImageData({
    required this.fileName,
    required this.bytes,
    this.path,
  });

  final String fileName;
  final Uint8List bytes;
  final String? path;
}
