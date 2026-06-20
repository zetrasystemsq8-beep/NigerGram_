import 'package:equatable/equatable.dart';

class UserVideoEntity extends Equatable {
  const UserVideoEntity({
    required this.videoId,
    required this.userId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.views,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.savedCount,
    required this.createdAt,
    required this.updatedAt,
    required this.isPrivate,
    required this.allowComments,
    required this.allowDuets,
    required this.allowStitches,
    this.tags = const [],
    this.category = '',
  });

  final String videoId;
  final String userId;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final int duration;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final int savedCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPrivate;
  final bool allowComments;
  final bool allowDuets;
  final bool allowStitches;
  final List<String> tags;
  final String category;

  @override
  List<Object?> get props => [
    videoId,
    userId,
    title,
    description,
    videoUrl,
    thumbnailUrl,
    duration,
    views,
    likes,
    comments,
    shares,
    savedCount,
    createdAt,
    updatedAt,
    isPrivate,
    allowComments,
    allowDuets,
    allowStitches,
    tags,
    category,
  ];
}
