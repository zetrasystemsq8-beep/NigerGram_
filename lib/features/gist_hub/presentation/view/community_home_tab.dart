import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/gist_hub/data/services/activity_service.dart';

class CommunityHomeTab extends StatefulWidget {
  final String communityId;
  const CommunityHomeTab({required this.communityId, super.key});

  @override
  State<CommunityHomeTab> createState() => _CommunityHomeTabState();
}

class _CommunityHomeTabState extends State<CommunityHomeTab> {
  final _service = ActivityService();

  static const Map<String, Map<String, dynamic>> _subtypeStyle = {
    'debate': {'emoji': '🔥', 'label': 'Happening now', 'icon': Icons.forum_outlined, 'color': Color(0xFFFF7043)},
    'quick_battle': {'emoji': '⚡', 'label': 'Quick Battle', 'icon': Icons.bolt, 'color': Color(0xFFFFCA28)},
    'quiz': {'emoji': '🧠', 'label': 'Quiz', 'icon': Icons.quiz_outlined, 'color': Color(0xFF64B5F6)},
    'prediction': {'emoji': '🔮', 'label': 'Prediction', 'icon': Icons.query_stats, 'color': Color(0xFFBA68C8)},
    'goal': {'emoji': '🎯', 'label': 'Community Goal', 'icon': Icons.flag_outlined, 'color': Color(0xFF81C784)},
    'challenge': {'emoji': '🏆', 'label': 'Challenge', 'icon': Icons.emoji_events_outlined, 'color': Color(0xFFFFD54F)},
    'announcement': {'emoji': '📢', 'label': 'Announcement', 'icon': Icons.campaign_outlined, 'color': Color(0xFF4DB6AC)},
    'event': {'emoji': '🗓️', 'label': 'Event', 'icon': Icons.event_outlined, 'color': Color(0xFFE57373)},
  };

  Map<String, dynamic> _styleFor(String subtype) =>
      _subtypeStyle[subtype] ?? {'emoji': '•', 'label': subtype, 'icon': Icons.circle_outlined, 'color': NGColors.accent};

  String _relativeTime(dynamic ts) {
    if (ts == null) return '';
    final date = (ts as dynamic).toDate();
    final diff = DateTime.now().difference(date as DateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _vote(String activityId, String optionId) async {
    try {
      await _service.voteOnPoll(communityId: widget.communityId, activityId: activityId, optionId: optionId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _contribute(String activityId) async {
    try {
      await _service.contributeToGoal(communityId: widget.communityId, activityId: activityId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _cardShell({required String subtype, required Widget child}) {
    final style = _styleFor(subtype);
    final color = style['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NGColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(style['emoji'] as String, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text((style['label'] as String).toUpperCase(),
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _pollCard(Map<String, dynamic> activity) {
    final options = List<Map<String, dynamic>>.from(activity['options'] ?? []);
    final voters = Map<String, dynamic>.from(activity['voters'] ?? {});
    final myVote = voters[AppAuth.uid] as String?;
    final totalVotes = options.fold<int>(0, (sum, o) => sum + (o['votes'] as int));
    final style = _styleFor(activity['subtype']);
    final color = style['color'] as Color;

    return _cardShell(
      subtype: activity['subtype'],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(activity['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        Text('${voters.length} people participating · ${_relativeTime(activity['createdAt'])}',
            style: TextStyle(color: NGColors.textMuted, fontSize: 11.5)),
        const SizedBox(height: 12),
        ...options.map((opt) {
          final votes = opt['votes'] as int;
          final pct = totalVotes == 0 ? 0.0 : votes / totalVotes;
          final isMine = myVote == opt['id'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _vote(activity['id'], opt['id']),
              child: Stack(children: [
                Container(
                  height: 40,
                  decoration: BoxDecoration(color: NGColors.background, borderRadius: BorderRadius.circular(10)),
                ),
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(isMine ? 0.45 : 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      if (isMine) const Icon(Icons.check_circle, color: Colors.white, size: 15),
                      if (isMine) const SizedBox(width: 6),
                      Expanded(
                        child: Text(opt['label'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Text('${(pct * 100).round()}%', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
                    ]),
                  ),
                ),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  Widget _goalCard(Map<String, dynamic> activity) {
    final current = (activity['currentCount'] as num?)?.toInt() ?? 0;
    final target = (activity['targetCount'] as num?)?.toInt() ?? 1;
    final participants = List<String>.from(activity['participants'] ?? []);
    final iContributed = participants.contains(AppAuth.uid);
    final style = _styleFor(activity['subtype']);
    final color = style['color'] as Color;

    return _cardShell(
      subtype: activity['subtype'],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(activity['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        if ((activity['description'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(activity['description'], style: TextStyle(color: NGColors.textSecondary, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (current / target).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: NGColors.background,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text('$current / $target', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: iContributed ? null : () => _contribute(activity['id']),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: iContributed ? NGColors.divider : color),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(iContributed ? Icons.check : Icons.add, size: 16, color: iContributed ? NGColors.textMuted : color),
            label: Text(iContributed ? 'Done' : 'I did this',
                style: TextStyle(color: iContributed ? NGColors.textMuted : color, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _announcementCard(Map<String, dynamic> activity) {
    final eventDate = activity['eventDate'];
    return _cardShell(
      subtype: activity['subtype'],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(activity['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        if ((activity['description'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(activity['description'], style: TextStyle(color: NGColors.textSecondary, fontSize: 13, height: 1.4)),
        ],
        if (eventDate != null || (activity['location'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (eventDate != null) ...[
              Icon(Icons.calendar_today_outlined, size: 13, color: NGColors.textMuted),
              const SizedBox(width: 4),
              Text('${eventDate.toDate().day}/${eventDate.toDate().month}/${eventDate.toDate().year}',
                  style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
              const SizedBox(width: 12),
            ],
            if ((activity['location'] ?? '').toString().isNotEmpty) ...[
              Icon(Icons.location_on_outlined, size: 13, color: NGColors.textMuted),
              const SizedBox(width: 4),
              Text(activity['location'], style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
            ],
          ]),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.getActivitiesStream(widget.communityId, activeOnly: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: NGColors.accent));
        }
        final activities = snapshot.data!;
        if (activities.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bolt_outlined, size: 40, color: NGColors.textMuted.withOpacity(0.6)),
              const SizedBox(height: 10),
              Text('Nothing happening yet', style: TextStyle(color: NGColors.textMuted)),
              const SizedBox(height: 4),
              Text('Start a debate, poll, or goal from the Activities tab',
                  style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            switch (activity['type']) {
              case 'poll':
                return _pollCard(activity);
              case 'goal':
                return _goalCard(activity);
              case 'announcement':
                return _announcementCard(activity);
              default:
                return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }
}
