// lib/features/media/utils/file_utils.dart

import 'dart:io';

class FileUtils {
  static Future<void> deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // swallow - caller can log if needed
    }
  }
}
