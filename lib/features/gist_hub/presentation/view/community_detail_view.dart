import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/gist_hub/data/services/community_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/community_entity.dart';

class CommunityDetailView extends StatefulWidget {
  final String communityId;
  const CommunityDetailView({required this.communityId, super.key});

  @override
  State<CommunityDetailView> createState() => _CommunityDetailViewState();
}

class _CommunityDetailViewState extends State<CommunityDetailView> {
  final _service = CommunityService();
  final _postController = TextEditingController();
  String? _myRole;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final role = await _service.getMemberRole(widget.communityId, AppAuth.uid);
    if (mounted) setState(() => _myRole = role);
  }

  Future<void> _post() async {
    if (_postController.text.trim().isEmpty) return;
    setState(() => _isPosting = true);
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('posts')
          .add({
        'userId': AppAuth.uid,
        'username': AppAuth.displayHandle,
        'text': _postController.text.trim(),
        'role': _myRole ?? 'member',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _postController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _leave() async {
    try {
      await _service.leaveCommunity(widget.communityId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _togglePin(String postId, bool isCurrentlyPinned) async {
    try {
      await FirebaseFirestore.instance.collection('communities').doc(widget.communityId).update({
        'pinnedPostId': isCurrentlyPinned ? FieldValue.delete() : postId,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pin: $e')));
      }
    }
  }

  Future<void> _toggleReaction(DocumentReference ref, String reactionKey, List<dynamic> currentUsers) async {
    final uid = AppAuth.uid;
    final hasReacted = currentUsers.contains(uid);
    try {
      await ref.update({
        'reactions.$reactionKey': hasReacted ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
      });
    } catch (e) {
      // Silently ignore — a failed reaction tap shouldn't interrupt the user.
    }
  }

  static const List<Color> _avatarPalette = [
    Color(0xFFE57373),
    Color(0xFF64B5F6),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFF4DB6AC),
  ];

  Color _colorForUsername(String username) {
    if (username.isEmpty) return _avatarPalette[0];
    final hash = username.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return _avatarPalette[hash % _avatarPalette.length];
  }

  String _relativeTime(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _roleBadge(String role) {
    if (role == 'owner') {
      return Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD54F).withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('OWNER',
            style: TextStyle(color: Color(0xFFFFD54F), fontSize: 9, fontWeight: FontWeight.bold)),
      );
    }
    if (role == 'moderator') {
      return Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: NGColors.accent.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('MOD', style: TextStyle(color: NGColors.accent, fontSize: 9, fontWeight: FontWeight.bold)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _statChip(IconData icon, String label, {Color? fillColor, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fillColor ?? NGColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fillColor != null ? Colors.transparent : NGColors.divider),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: textColor ?? NGColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: textColor ?? NGColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _reactionChip({
    required IconData icon,
    required IconData filledIcon,
    required Color activeColor,
    required List<dynamic> users,
    required DocumentReference ref,
    required String reactionKey,
  }) {
    final uid = AppAuth.uid;
    final active = users.contains(uid);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _toggleReaction(ref, reactionKey, users),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(active ? filledIcon : icon, size: 16, color: active ? activeColor : NGColors.textMuted),
          if (users.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text('${users.length}',
                style: TextStyle(color: active ? activeColor : NGColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ]),
      ),
    );
  }

  void _openReplies(String postId, bool canReply) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RepliesSheet(communityId: widget.communityId, postId: postId, canReply: canReply),
    );
  }

  void _openMembers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MembersSheet(communityId: widget.communityId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('communities').doc(widget.communityId).snapshots(),
        builder: (context, communitySnap) {
          if (!communitySnap.hasData || !communitySnap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final rawCommunityData = communitySnap.data!.data() as Map<String, dynamic>;
          final community = CommunityEntity.fromMap(rawCommunityData, communitySnap.data!.id);
          final pinnedPostId = rawCommunityData['pinnedPostId'] as String?;
          final isMember = _myRole != null;
          final canPost = _myRole == 'owner' || _myRole == 'moderator';
          final showComposeBar = isMember && (canPost || community.type == CommunityType.group);

          return SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(community.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            Text('${community.memberCount} members', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.groups_outlined, color: Colors.white),
                        tooltip: 'Members',
                        onPressed: _openMembers,
                      ),
                      if (isMember && _myRole != 'owner')
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.redAccent),
                          tooltip: 'Leave community',
                          onPressed: _leave,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: NGColors.divider),

                // Chat feed
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: NGColors.surface,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(community.description, style: TextStyle(color: NGColors.textMuted, fontSize: 13.5, height: 1.4)),
                                const SizedBox(height: 14),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  _statChip(
                                    community.type == CommunityType.channel ? Icons.campaign_outlined : Icons.groups_outlined,
                                    community.type == CommunityType.channel ? 'Channel' : 'Group',
                                  ),
                                  if (_myRole != null)
                                    _statChip(Icons.badge_outlined, _myRole!.toUpperCase(),
                                        fillColor: NGColors.accent.withOpacity(0.16), textColor: NGColors.accent),
                                ]),
                                if (community.rules.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  Row(children: [
                                    Icon(Icons.rule_outlined, size: 15, color: NGColors.accent),
                                    const SizedBox(width: 6),
                                    const Text('Community rules', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ]),
                                  const SizedBox(height: 8),
                                  ...community.rules.map((r) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 5),
                                            child: Container(width: 4, height: 4, decoration: BoxDecoration(color: NGColors.textMuted, shape: BoxShape.circle)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(r, style: TextStyle(color: NGColors.textMuted, fontSize: 13, height: 1.3))),
                                        ]),
                                      )),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (pinnedPostId != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: _PinnedPostBanner(communityId: widget.communityId, postId: pinnedPostId),
                          ),
                        ),
                      if (!isMember)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await _service.joinCommunity(widget.communityId);
                                  _loadRole();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: NGColors.accent,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Join Community', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('communities')
                            .doc(widget.communityId)
                            .collection('posts')
                            .orderBy('createdAt', descending: true)
                            .limit(50)
                            .snapshots(),
                        builder: (context, postsSnap) {
                          if (!postsSnap.hasData) return const SliverToBoxAdapter(child: SizedBox.shrink());
                          final posts = postsSnap.data!.docs;
                          if (posts.isEmpty) {
                            return SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 48),
                                child: Center(
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.forum_outlined, size: 40, color: NGColors.textMuted.withOpacity(0.6)),
                                    const SizedBox(height: 10),
                                    Text('No posts yet', style: TextStyle(color: NGColors.textMuted)),
                                  ]),
                                ),
                              ),
                            );
                          }
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final doc = posts[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final username = (data['username'] ?? 'user').toString();
                                final role = (data['role'] ?? 'member').toString();
                                final isOwnerPost = role == 'owner';
                                final avatarColor = _colorForUsername(username);
                                final reactions = (data['reactions'] as Map<String, dynamic>?) ?? {};
                                final likeUsers = (reactions['like'] as List<dynamic>?) ?? [];
                                final heartUsers = (reactions['heart'] as List<dynamic>?) ?? [];
                                final isPinned = pinnedPostId == doc.id;

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: NGColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: isOwnerPost ? Border.all(color: const Color(0xFFFFD54F).withOpacity(0.35), width: 1) : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        CircleAvatar(
                                          radius: 15,
                                          backgroundColor: avatarColor,
                                          child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Row(children: [
                                            Flexible(
                                              child: Text('@$username',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                                            ),
                                            _roleBadge(role),
                                          ]),
                                        ),
                                        Text(_relativeTime(data['createdAt'] as Timestamp?), style: TextStyle(color: NGColors.textMuted, fontSize: 11)),
                                        if (canPost) ...[
                                          const SizedBox(width: 2),
                                          InkWell(
                                            borderRadius: BorderRadius.circular(20),
                                            onTap: () => _togglePin(doc.id, isPinned),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                                  size: 16, color: isPinned ? const Color(0xFFFFD54F) : NGColors.textMuted),
                                            ),
                                          ),
                                        ],
                                      ]),
                                      const SizedBox(height: 10),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 38),
                                        child: Text(data['text'] ?? '', style: TextStyle(color: NGColors.textSecondary, fontSize: 13.5, height: 1.4)),
                                      ),
                                      const SizedBox(height: 10),
                                      Padding(padding: const EdgeInsets.only(left: 32), child: Divider(color: NGColors.divider, height: 1)),
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 26),
                                        child: Row(children: [
                                          _reactionChip(
                                            icon: Icons.thumb_up_alt_outlined,
                                            filledIcon: Icons.thumb_up_alt,
                                            activeColor: NGColors.accent,
                                            users: likeUsers,
                                            ref: doc.reference,
                                            reactionKey: 'like',
                                          ),
                                          _reactionChip(
                                            icon: Icons.favorite_border,
                                            filledIcon: Icons.favorite,
                                            activeColor: Colors.redAccent,
                                            users: heartUsers,
                                            ref: doc.reference,
                                            reactionKey: 'heart',
                                          ),
                                          const Spacer(),
                                          InkWell(
                                            borderRadius: BorderRadius.circular(20),
                                            onTap: () => _openReplies(doc.id, isMember),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                Icon(Icons.chat_bubble_outline, size: 15, color: NGColors.textMuted),
                                                const SizedBox(width: 4),
                                                Text('Reply', style: TextStyle(color: NGColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                                              ]),
                                            ),
                                          ),
                                        ]),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              childCount: posts.length,
                            ),
                          );
                        },
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                  ),
                ),

                // Fixed compose bar
                if (showComposeBar)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: NGColors.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: NGColors.divider),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _postController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: canPost || community.type == CommunityType.group ? 'Post something...' : 'Only moderators can post here',
                              hintStyle: TextStyle(color: NGColors.textMuted),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(color: NGColors.accent, shape: BoxShape.circle),
                          child: IconButton(
                            icon: _isPosting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                            onPressed: _isPosting ? null : _post,
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PinnedPostBanner extends StatelessWidget {
  final String communityId;
  final String postId;

  const _PinnedPostBanner({required this.communityId, required this.postId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').doc(communityId).collection('posts').doc(postId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>;
        final username = (data['username'] ?? 'user').toString();
        final text = (data['text'] ?? '').toString();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD54F).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.push_pin, size: 14, color: Color(0xFFFFD54F)),
              const SizedBox(width: 6),
              Text('Pinned • @$username', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: NGColors.textSecondary, fontSize: 13.5, height: 1.4)),
          ]),
        );
      },
    );
  }
}

class _RepliesSheet extends StatefulWidget {
  final String communityId;
  final String postId;
  final bool canReply;

  const _RepliesSheet({required this.communityId, required this.postId, required this.canReply});

  @override
  State<_RepliesSheet> createState() => _RepliesSheetState();
}

class _RepliesSheetState extends State<_RepliesSheet> {
  final _replyController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('posts')
          .doc(widget.postId)
          .collection('replies')
          .add({
        'userId': AppAuth.uid,
        'username': AppAuth.displayHandle,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _replyController.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4, decoration: BoxDecoration(color: NGColors.textMuted, borderRadius: BorderRadius.circular(2))),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline, size: 15, color: NGColors.accent),
            const SizedBox(width: 6),
            const Text('Replies', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 8),
          const Divider(color: NGColors.divider, height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(widget.communityId)
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('replies')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final replies = snap.data!.docs;
                if (replies.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.mode_comment_outlined, size: 32, color: NGColors.textMuted.withOpacity(0.6)),
                      const SizedBox(height: 8),
                      Text('No replies yet', style: TextStyle(color: NGColors.textMuted)),
                    ]),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: replies.length,
                  separatorBuilder: (_, __) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(color: NGColors.divider, height: 1)),
                  itemBuilder: (context, index) {
                    final data = replies[index].data() as Map<String, dynamic>;
                    final username = (data['username'] ?? 'user').toString();
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('@$username', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(data['text'] ?? '', style: TextStyle(color: NGColors.textSecondary, fontSize: 13, height: 1.3)),
                    ]);
                  },
                );
              },
            ),
          ),
          if (widget.canReply)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(color: NGColors.background, borderRadius: BorderRadius.circular(24), border: Border.all(color: NGColors.divider)),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        hintStyle: TextStyle(color: NGColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(color: NGColors.accent, shape: BoxShape.circle),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                      onPressed: _isSending ? null : _sendReply,
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _MembersSheet extends StatelessWidget {
  final String communityId;
  const _MembersSheet({required this.communityId});

  static const List<Color> _avatarPalette = [
    Color(0xFFE57373), Color(0xFF64B5F6), Color(0xFF81C784), Color(0xFFFFB74D), Color(0xFFBA68C8), Color(0xFF4DB6AC),
  ];

  Color _colorForUsername(String username) {
    if (username.isEmpty) return _avatarPalette[0];
    final hash = username.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return _avatarPalette[hash % _avatarPalette.length];
  }

  int _rolePriority(String role) {
    if (role == 'owner') return 0;
    if (role == 'moderator') return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4, decoration: BoxDecoration(color: NGColors.textMuted, borderRadius: BorderRadius.circular(2))),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.groups_outlined, size: 15, color: NGColors.accent),
          const SizedBox(width: 6),
          const Text('Members', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 8),
        const Divider(color: NGColors.divider, height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('communities').doc(communityId).collection('members').orderBy('joinedAt', descending: false).limit(200).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = List.of(snap.data!.docs);
              docs.sort((a, b) {
                final roleA = ((a.data() as Map<String, dynamic>)['role'] ?? 'member').toString();
                final roleB = ((b.data() as Map<String, dynamic>)['role'] ?? 'member').toString();
                return _rolePriority(roleA).compareTo(_rolePriority(roleB));
              });

              if (docs.isEmpty) {
                return Center(child: Text('No members yet', style: TextStyle(color: NGColors.textMuted)));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => Divider(color: NGColors.divider, height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final username = (data['username'] ?? 'member').toString();
                  final role = (data['role'] ?? 'member').toString();
                  final avatarColor = _colorForUsername(username);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: avatarColor,
                      child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    title: Text('@$username', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: role == 'owner'
                        ? const Text('OWNER', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 10, fontWeight: FontWeight.bold))
                        : role == 'moderator'
                            ? Text('MOD', style: TextStyle(color: NGColors.accent, fontSize: 10, fontWeight: FontWeight.bold))
                            : null,
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
