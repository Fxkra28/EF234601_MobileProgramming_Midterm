import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageService {
  static final ImageService instance = ImageService._();
  ImageService._();

  final ImagePicker _picker = ImagePicker();

  Future<String?> pickFromCamera() => _pick(ImageSource.camera);
  Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<String?> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return null;
    return _persistToDocs(File(picked.path));
  }

  Future<String> _persistToDocs(File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'task_images'));
    if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(source.path)}';
    final dest = File(p.join(imagesDir.path, filename));
    await source.copy(dest.path);
    return dest.path;
  }

  Future<void> deleteLocalIfExists(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (f.existsSync()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
}
