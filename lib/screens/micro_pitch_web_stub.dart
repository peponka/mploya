import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

/// Stub for non-web platforms. This file is never actually used on web.
/// The conditional import in micro_pitch_camera.dart handles the routing.
class WebRecorderHelper {
  static Future<XFile?> recordVideo(BuildContext context) async {
    // On mobile, this should never be called since we use ImagePicker directly.
    // But just in case, fall back to ImagePicker.
    final picker = ImagePicker();
    return picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
      preferredCameraDevice: CameraDevice.front,
    );
  }
}
