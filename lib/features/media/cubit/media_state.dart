// lib/features/media/cubit/media_state.dart

part of 'media_cubit.dart';

abstract class MediaState extends Equatable {
  const MediaState();

  @override
  List<Object?> get props => [];
}

class MediaInitial extends MediaState {}

class MediaCompressing extends MediaState {
  final double progress; // 0..1
  const MediaCompressing(this.progress);

  @override
  List<Object?> get props => [progress];
}

class MediaUploading extends MediaState {
  final double progress; // 0..1
  const MediaUploading(this.progress);

  @override
  List<Object?> get props => [progress];
}

class MediaSuccess extends MediaState {}

class MediaFailure extends MediaState {
  final String message;
  const MediaFailure(this.message);

  @override
  List<Object?> get props => [message];
}
