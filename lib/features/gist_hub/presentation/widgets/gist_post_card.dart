// lib/features/gist_hub/presentation/widgets/gist_post_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nigergram/features/gist_hub/domain/entities/gist_post_entity.dart';
import 'package:nigergram/features/gist_hub/data/services/gist_service.dart';
import 'package:nigergram/theme/ng_colors.dart';

// ==========================================================================
// CORE MONOLITH ENTRYPOINT
// ==========================================================================

class GistPostCard extends StatelessWidget {
  final Map<String, dynamic> postData;
  final String defaultReactionEmoji;
  final GistService _gistService;

  // Global Layout Architecture Constants
  static const double _cardPadding = 14.0;
  static const double _cardBorderRadius = 16.0;
  static const double _innerElementRadius = 12.0;
  
  // Weights and Threshold Parameters
  static const double _trendingThreshold = 25.0;
  static const double _reactionWeight = 1.0;
  static const double _commentWeight = 3.0;
  static const double _shareWeight = 5.0;
  static const double _bookmarkWeight = 2.0;

  GistPostCard({
    super.key,
    required this.postData,
    this.defaultReactionEmoji = "🇳🇬",
    GistService? gistService,
  }) : _gistService = gistService ?? GistService();

  bool _calculateIsTrending(int commentCount, int shareCount, int bookmarkCount, Map<String, dynamic> reactions) {
    int reactionsCount = 0;
    reactions.forEach((_, value) {
      if (value is num) {
        reactionsCount += value.toInt();
      }
    });
    final double trendingScore = (reactionsCount * _reactionWeight) + 
        (commentCount * _commentWeight) + 
        (shareCount * _shareWeight) + 
        (bookmarkCount * _bookmarkWeight);
    return trendingScore >= _trendingThreshold;
  }

  void _showFeedback(BuildContext context, String message, {bool isError = false}) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? NGColors.fireRed : NGColors.interactiveBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, Future<void> Function() action, String successMessage) async {
    try {
      await action();
      if (context.mounted) {
        _showFeedback(context, successMessage);
      }
    } catch (e) {
      if (context.mounted) {
        _showFeedback(
          context, 
          'Something went wrong. Please check your network connection and try again.', 
          isError: true
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();

    final String id = postData['id']?.toString() ?? '';
    final String displayName = postData['displayName']?.toString() ?? 'Anonymous';
    final String username = postData['username']?.toString() ?? 'anonymous';
    final String profilePic = postData['profilePic']?.toString() ?? '';
    final String content = postData['content']?.toString() ?? '';
    final String? imageUrl = postData['imageUrl']?.toString();
    
    final int commentCount = (postData['commentCount'] as num?)?.toInt() ?? 0;
    final int shareCount = (postData['shareCount'] as num?)?.toInt() ?? 0;
    final int bookmarkCount = (postData['bookmarkCount'] as num?)?.toInt() ?? 0;
    
    final Map<String, dynamic> reactions = postData['reactions'] is Map 
        ? Map<String, dynamic>.from(postData['reactions'] as Map) 
        : <String, dynamic>{};

    final int totalReactionCount = reactions.values
        .whereType<num>()
        .fold<int>(0, (sum, value) => sum + value.toInt());

    final GistType gistType = GistType.values.firstWhere(
      (e) => e.name == postData['gistType'],
      orElse: () => GistType.text,
    );

    final GistPollStatus pollStatus = GistPollStatus.values.firstWhere(
      (e) => e.name == postData['pollStatus'],
      orElse: () => GistPollStatus.none,
    );

    final GistAnnouncementType announcementType = GistAnnouncementType.values.firstWhere(
      (e) => e.name == postData['announcementType'],
      orElse: () => GistAnnouncementType.none,
    );

    final bool isTrending = _calculateIsTrending(commentCount, shareCount, bookmarkCount, reactions);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardBorderRadius),
        side: const BorderSide(color: NGColors.borderOption, width: 0.5),
      ),
      color: NGColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GistPostHeader(
              displayName: displayName,
              username: username,
              profilePic: profilePic,
              gistType: gistType,
              announcementType: announcementType,
              isTrending: isTrending,
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(color: NGColors.textPrimary, fontSize: 15.0, height: 1.4),
            ),
            if (gistType == GistType.announcement && announcementType == GistAnnouncementType.pollWinner)
              GistWinnerCard(postData: postData, borderRadius: _innerElementRadius),
            if (gistType == GistType.poll)
              GistPollEngine(
                postId: id,
                postData: postData,
                pollStatus: pollStatus,
                currentTime: now,
                onVoteCast: (choiceIndex) => _handleAction(
                  context,
                  () => _gistService.castVote(postId: id, choiceIndex: choiceIndex),
                  'Vote registered successfully',
                ),
              ),
            if (pollStatus == GistPollStatus.none && gistType != GistType.announcement)
              GistPollProgressMeter(postData: postData),
            if (imageUrl != null && imageUrl.isNotEmpty && gistType == GistType.image)
              GistPostImage(postId: id, imageUrl: imageUrl, borderRadius: _innerElementRadius),
            const SizedBox(height: 14),
            GistInteractiveActionBar(
              postId: id,
              pollStatus: pollStatus,
              reactionsCount: totalReactionCount,
              onReactionPressed: () => _handleAction(
                context,
                () => _gistService.addReaction(postId: id, emoji: defaultReactionEmoji),
                'Reaction added',
              ),
              onPollRequestPressed: () => _handleAction(
                context,
                () => _gistService.submitPollRequest(
                  postId: id, 
                  systemGeneratedOptions: const ['Agree', 'Disagree', 'Needs Proof']
                ),
                'Poll request submitted successfully',
              ),
              onBookmarkPressed: () => _handleAction(
                context,
                () => _gistService.incrementBookmark(postId: id),
                'Gist saved to bookmarks',
              ),
              onSharePressed: () => _handleAction(
                context,
                () => _gistService.incrementShare(postId: id),
                'Link shared successfully',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// SUB-COMPONENT MODULE 1: HEADER SUB-LAYOUT
// ==========================================================================

class GistPostHeader extends StatelessWidget {
  final String displayName;
  final String username;
  final String profilePic;
  final GistType gistType;
  final GistAnnouncementType announcementType;
  final bool isTrending;

  const GistPostHeader({
    super.key,
    required this.displayName,
    required this.username,
    required this.profilePic,
    required this.gistType,
    required this.announcementType,
    required this.isTrending,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20.0,
          backgroundColor: NGColors.surfaceVariant,
          backgroundImage: profilePic.isNotEmpty ? CachedNetworkImageProvider(profilePic) : null,
          onBackgroundImageError: profilePic.isNotEmpty 
              ? (exception, stackTrace) {
                  // Production diagnostic diagnostic logs hook
                }
              : null,
          child: profilePic.isEmpty ? const Icon(Icons.person, color: NGColors.textMuted) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, color: NGColors.textPrimary, fontSize: 15.0),
              ),
              Text(
                '@$username',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: NGColors.textSecondary, fontSize: 13.0),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              if (isTrending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: NGColors.fireRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8.0),
                    border: const BorderSide(color: NGColors.fireRed, width: 0.5),
                  ),
                  child: const Text(
                    '🔥 TRENDING',
                    style: TextStyle(color: NGColors.fireRed, fontWeight: FontWeight.bold, fontSize: 11.0),
                  ),
                ),
              if (gistType == GistType.announcement)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: NGColors.brandPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8.0),
                    border: const BorderSide(color: NGColors.brandPurple, width: 0.5),
                  ),
                  child: Text(
                    announcementType == GistAnnouncementType.pollWinner ? '🗳️ POLL WINNER' : 'ANNOUNCEMENT',
                    style: const TextStyle(color: NGColors.brandPurple, fontWeight: FontWeight.bold, fontSize: 11.0),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// SUB-COMPONENT MODULE 2: WINNER ANNOUNCEMENT ARCHITECTURE
// ==========================================================================

class GistWinnerCard extends StatelessWidget {
  final Map<String, dynamic> postData;
  final double borderRadius;

  const GistWinnerCard({
    super.key,
    required this.postData,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> finalResults = postData['finalPollResults'] is Map 
        ? Map<String, dynamic>.from(postData['finalPollResults'] as Map) 
        : <String, dynamic>{};
    final int totalVotes = (finalResults['totalVotes'] as num?)?.toInt() ?? 0;
    final List<dynamic> options = postData['pollOptions'] is List ? postData['pollOptions'] as List : [];
    final int winnerIndex = (finalResults['winnerIndex'] as num?)?.toInt() ?? -1;
    final bool isTie = (finalResults['isTie'] as bool?) ?? false;
    
    String statusText;
    if (options.isEmpty || totalVotes == 0) {
      statusText = "Poll concluded with no votes cast.";
    } else if (isTie) {
      statusText = "🏆 Concluded in a Tie match!";
    } else if (winnerIndex >= 0 && winnerIndex < options.length) {
      statusText = '🏆 Winner: ${options[winnerIndex]}';
    } else {
      statusText = "Poll concluded.";
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NGColors.brandPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: const BorderSide(color: NGColors.brandPurple, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.stars, color: NGColors.brandPurple, size: 18),
              SizedBox(width: 6),
              Text(
                'OFFICIAL POLL RESULT',
                style: TextStyle(color: NGColors.brandPurple, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: const TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Votes Counted: $totalVotes',
            style: const TextStyle(color: NGColors.textSecondary, fontSize: 13.0),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// SUB-COMPONENT MODULE 3: INTERACTIVE VOTING COMPONENT ENGINE
// ==========================================================================

class GistPollEngine extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final GistPollStatus pollStatus;
  final DateTime currentTime;
  final Function(int index) onVoteCast;

  const GistPollEngine({
    super.key,
    required this.postId,
    required this.postData,
    required this.pollStatus,
    required this.currentTime,
    required this.onVoteCast,
  });

  String _formatRemainingTime(Duration difference) {
    if (difference.isNegative) return 'Voting Period Concluded';
    
    final int days = difference.inDays;
    final int hours = difference.inHours % 24;
    final int minutes = difference.inMinutes % 60;

    if (days > 0) {
      return 'Closes in: ${days}d ${hours}h left';
    } else if (hours > 0) {
      return 'Closes in: ${hours}h ${minutes}m left';
    } else {
      return 'Closes in: ${minutes}m left';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> options = postData['pollOptions'] is List ? postData['pollOptions'] as List : [];
    final Map<String, dynamic> votes = postData['pollVotes'] is Map 
        ? Map<String, dynamic>.from(postData['pollVotes'] as Map) 
        : <String, dynamic>{};
    
    final dynamic expiresAtRaw = postData['expiresAt'];
    final Timestamp? expiresAt = expiresAtRaw is Timestamp ? expiresAtRaw : null;
    
    int totalVotes = 0;
    votes.forEach((_, val) {
      if (val is num) {
        totalVotes += val.toInt();
      }
    });

    final bool isExpiredTime = expiresAt != null && expiresAt.toDate().isBefore(currentTime);
    final bool canVote = (pollStatus == GistPollStatus.votingActive) && !isExpiredTime;
    final Duration remainingDuration = expiresAt != null ? expiresAt.toDate().difference(currentTime) : Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (expiresAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Icon(Icons.timer, size: 14, color: canVote ? NGColors.interactiveBlue : NGColors.fireRed),
                const SizedBox(width: 4),
                Text(
                  canVote ? _formatRemainingTime(remainingDuration) : 'Voting Period Concluded',
                  style: TextStyle(color: canVote ? NGColors.textSecondary : NGColors.fireRed, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ...List.generate(options.length, (index) {
          final String optionText = options[index].toString();
          final int optionVotes = (votes[index.toString()] as num?)?.toInt() ?? 0;
          final double alignmentFactor = totalVotes > 0 ? (optionVotes / totalVotes).clamp(0.0, 1.0) : 0.0;

          return GistPollOptionTile(
            optionText: optionText,
            alignmentFactor: alignmentFactor,
            canVote: canVote,
            onTap: () => onVoteCast(index),
          );
        }),
      ],
    );
  }
}

class GistPollOptionTile extends StatelessWidget {
  final String optionText;
  final double alignmentFactor;
  final bool canVote;
  final VoidCallback onTap;

  const GistPollOptionTile({
    super.key,
    required this.optionText,
    required this.alignmentFactor,
    required this.canVote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: canVote ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: const BorderSide(color: NGColors.borderOption, width: 1),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: alignmentFactor,
                  child: Container(
                    decoration: BoxDecoration(
                      color: NGColors.interactiveBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        optionText, 
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: NGColors.textPrimary, fontSize: 14)
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(alignmentFactor * 100).toStringAsFixed(1)}%', 
                      style: const TextStyle(color: NGColors.textSecondary, fontSize: 13.0, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// SUB-COMPONENT MODULE 4: COMMUNITY PROGRESS REQUEST PROGRESSION ENGINE
// ==========================================================================

class GistPollProgressMeter extends StatelessWidget {
  final Map<String, dynamic> postData;

  const GistPollProgressMeter({
    super.key,
    required this.postData,
  });

  @override
  Widget build(BuildContext context) {
    final int currentRequests = (postData['pollRequestsCount'] as num?)?.toInt() ?? 0;
    final int uniqueEngaged = (postData['uniqueEngagedUsers'] as num?)?.toInt() ?? 1;
    
    int threshold = 5;
    if (uniqueEngaged > 10) {
      threshold = (uniqueEngaged * 0.15).clamp(5, 500).round();
    }
    
    final double progressPercent = threshold > 0 ? (currentRequests / threshold).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NGColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Community Poll Requests', 
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: NGColors.textSecondary, fontSize: 12)
                ),
              ),
              const SizedBox(width: 8),
              Text('$currentRequests/$threshold requested', style: const TextStyle(color: NGColors.interactiveBlue, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressPercent,
              backgroundColor: NGColors.borderOption,
              valueColor: const AlwaysStoppedAnimation<Color>(NGColors.interactiveBlue),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// SUB-COMPONENT MODULE 5: RENDER TARGETED MEDIA COMPONENT IMAGE
// ==========================================================================

class GistPostImage extends StatelessWidget {
  final String postId;
  final String imageUrl;
  final double borderRadius;
  static const int _diskCacheSize = 600;

  const GistPostImage({
    super.key,
    required this.postId,
    required this.imageUrl,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Hero(
          tag: 'gist_media_${postId}_$imageUrl',
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            maxWidthDiskCache: _diskCacheSize,
            maxHeightDiskCache: _diskCacheSize,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (context, url) => Container(
              height: 200,
              color: NGColors.surfaceVariant,
              child: const Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(NGColors.interactiveBlue),
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 150,
              color: NGColors.surfaceVariant,
              child: const Center(
                child: Icon(Icons.broken_image, color: NGColors.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// SUB-COMPONENT MODULE 6: COMPACT INTERACTIVE METRIC PANEL
// ==========================================================================

class GistInteractiveActionBar extends StatelessWidget {
  final String postId;
  final GistPollStatus pollStatus;
  final int reactionsCount;
  final VoidCallback onReactionPressed;
  final VoidCallback onPollRequestPressed;
  final VoidCallback onBookmarkPressed;
  final VoidCallback onSharePressed;

  const GistInteractiveActionBar({
    super.key,
    required this.postId,
    required this.pollStatus,
    required this.reactionsCount,
    required this.onReactionPressed,
    required this.onPollRequestPressed,
    required this.onBookmarkPressed,
    required this.onSharePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Semantics(
          label: 'Reaction panel tracking $reactionsCount interaction selections',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border, size: 20, color: NGColors.textMuted),
                tooltip: 'React with default emoji',
                onPressed: onReactionPressed,
              ),
              const SizedBox(width: 4),
              Text('$reactionsCount', style: const TextStyle(color: NGColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pollStatus == GistPollStatus.none)
              IconButton(
                icon: const Icon(Icons.how_to_vote, size: 20, color: NGColors.interactiveBlue),
                tooltip: 'Request Official Poll from community',
                onPressed: onPollRequestPressed,
              ),
            IconButton(
              icon: const Icon(Icons.bookmark_border, size: 20, color: NGColors.textMuted),
              tooltip: 'Bookmark Gist to your collection',
              onPressed: onBookmarkPressed,
            ),
            IconButton(
              icon: const Icon(Icons.share, size: 18, color: NGColors.textMuted),
              tooltip: 'Share Gist link with others',
              onPressed: onSharePressed,
            ),
          ],
        ),
      ],
    );
  }
}
