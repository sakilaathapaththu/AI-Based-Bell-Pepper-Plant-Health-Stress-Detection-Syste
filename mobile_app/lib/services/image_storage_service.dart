import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads captured/picked images to Firebase Storage under
/// `users/{uid}/{category}/{autoId}.{ext}` and returns the download URL.
/// Shared by every image-based detection module (thermal, RGB, ...) so each
/// one doesn't reimplement its own upload logic.
class ImageStorageService {
  ImageStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadImage({
    required String uid,
    required String category,
    required Uint8List bytes,
    required String filename,
  }) async {
    final extension = filename.contains('.') ? filename.split('.').last : 'jpg';
    final path =
        'users/$uid/$category/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref(path);
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
