// lib/features/media/cubit/media_cubit.dart

import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../repository/media_repository.dart';

part 'media_state.dart';

class MediaCubit extends Cubit<MediaState> {
  final MediaRepository _repository;

  MediaCubit({MediaRepository? repository})
      : _repository = repository ?? MediaRepository(),
        super(MediaInitial());

  /// Orchestrates compress -> upload -> cleanup
  Future<void> compressAndUpload(File originalFile, String destinationPath,
      {int quality = 1}) async {
    try {
      emit(MediaCompressing(0.0));

      await _repository.compressUploadAndCleanup(originalFile, destinationPath,
          onCompressProgress: (p) => emit(MediaCompressing(p)),
          onUploadProgress: (p) => emit(MediaUploading(p)),
          bucketName: 'videos');

      emit(MediaSuccess());
    } catch (e) {
      emit(MediaFailure(e.toString()));
    }
  }
}
