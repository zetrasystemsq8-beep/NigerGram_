
// Replaced the two methods with robust implementations. We keep the rest of the file unchanged to avoid accidental reformatting.

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// The new _updateAvatar implementation
Future<void> _updateAvatar() async {
  if (!_isCurrentUser || _currentUid.isEmpty) return;
  HapticFeedback.mediumImpact();

  final XFile? img = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 80,
    maxWidth: 400,
  );
  if (img == null) return;

  setState(() {
    _isUploadingContent = true;
    _uploadLabel = 'Uploading photo...';
    _uploadProgress = 0.3;
  });

  try {
    final file = File(img.path);
    final ext = _extensionOrDefault(file.path);
    final mime = _mimeForExt(ext);
    final String filePath = _uniqueUserImagePath(_currentUid, 'avatar', ext);

    final bytes = await file.readAsBytes();
    await _supabase.storage.from('images').uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(
        contentType: mime,
        upsert: false,
      ),
    );

    final String url = _supabase.storage.from('images').getPublicUrl(filePath);

    final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUid);
    final prevDoc = await userRef.get();
    final prevPath = prevDoc.exists ? prevDoc.data()?['profilePicPath'] as String? : null;

    await userRef.update({
      'profilePicUrl': url,
      'profilePicPath': filePath,
    });

    if (prevPath != null && prevPath.isNotEmpty && prevPath != filePath) {
      try {
        await _supabase.storage.from('images').remove([prevPath]);
      } catch (e) {
        debugPrint('Could not delete old avatar $prevPath: $e');
      }
    }

    await _loadUserData();
    if (mounted) _showSnack('Profile photo updated!', isSuccess: true);
  } catch (e) {
    debugPrint('Upload error: $e');
    if (mounted) _showSnack('Failed to update photo', isSuccess: false);
  } finally {
    if (mounted) setState(() {
      _isUploadingContent = false;
      _uploadProgress = 0.0;
      _uploadLabel = '';
    });
  }
}

// The new _updateCover implementation
Future<void> _updateCover() async {
  if (!_isCurrentUser || _currentUid.isEmpty) return;
  HapticFeedback.mediumImpact();

  final XFile? img = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 75,
    maxWidth: 1080,
  );
  if (img == null) return;

  setState(() {
    _isUploadingContent = true;
    _uploadLabel = 'Uploading cover...';
    _uploadProgress = 0.3;
  });

  try {
    final file = File(img.path);
    final ext = _extensionOrDefault(file.path);
    final mime = _mimeForExt(ext);
    final String filePath = _uniqueUserImagePath(_currentUid, 'cover', ext);

    final bytes = await file.readAsBytes();
    await _supabase.storage.from('images').uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(
        contentType: mime,
        upsert: false,
      ),
    );

    final String url = _supabase.storage.from('images').getPublicUrl(filePath);

    final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUid);
    final prevDoc = await userRef.get();
    final prevPath = prevDoc.exists ? prevDoc.data()?['coverPath'] as String? : null;

    await userRef.update({
      'coverUrl': url,
      'coverPath': filePath,
    });

    if (prevPath != null && prevPath.isNotEmpty && prevPath != filePath) {
      try {
        await _supabase.storage.from('images').remove([prevPath]);
      } catch (e) {
        debugPrint('Could not delete old cover $prevPath: $e');
      }
    }

    await _loadUserData();
    if (mounted) _showSnack('Cover updated!', isSuccess: true);
  } catch (e) {
    debugPrint('Cover upload error: $e');
    if (mounted) _showSnack('Failed to update cover', isSuccess: false);
  } finally {
    if (mounted) setState(() {
      _isUploadingContent = false;
      _uploadProgress = 0.0;
      _uploadLabel = '';
    });
  }
}
