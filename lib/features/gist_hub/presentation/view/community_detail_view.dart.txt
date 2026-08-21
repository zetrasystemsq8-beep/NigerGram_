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
        child: const Text(
          'OWNER',
          style: TextStyle(color: Color(0xFFFFD54F), fontSize: 9, fontWeight: FontWeight.bold),
        ),
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
        child: Text(
          'MOD',
          style: TextStyle(color: NGColors.accent, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      );
    }
    return const SizedBox.shrink();
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? filledIcon : icon, size: 16, color: active ? activeColor : NGColors.textMuted),
            if (users.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text('${users.length}',
                  style: TextStyle(color: active ? activeColor : NGColors.textMuted, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  void _openReplies(String postId, bool canReply) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _RepliesSheet(
        communityId: widget.communityId,
        postId: postId,
        canReply: canReply,
      ),
    );
  }

  void _openMembers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _MembersSheet(communityId: widget.communityId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMember = _myRole != null;
    final canPost = _myRole == 'owner' || _myRole == 'moderator';

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

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: NGColors.surface,
                pinned: true,
                title: Text(community.name, style: const TextStyle(color: Colors.white)),
                actions: [
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(community.description, style: TextStyle(color: NGColors.textMuted)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            community.type == CommunityType.channel ? Icons.campaign_outlined : Icons.groups_outlined,
                            size: 14,
                            color: NGColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${community.memberCount} members • ${community.type == CommunityType.channel ? "Channel" : "Group"}',
                            style: TextStyle(color: NGColors.textMuted, fontSize: 12),
                          ),
                          if (_myRole != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: NGColors.accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _myRole!.toUpperCase(),
                                style: TextStyle(color: NGColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (community.rules.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Rules', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        ...community.rules.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $r', style: TextStyle(color: NGColors.textMuted, fontSize: 13)),
                            )),
                      ],
                      if (pinnedPostId != null) ...[
                        const SizedBox(height: 16),
                        _PinnedPostBanner(communityId: widget.communityId, postId: pinnedPostId),
                      ],
                      const Divider(height: 32, color: NGColors.divider),
                      if (!isMember)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              await _service.joinCommunity(widget.communityId);
                              _loadRole();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: NGColors.accent),
                            child: const Text('Join Community'),
                          ),
                        )
                      else if (canPost || community.type == CommunityType.group)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _postController,
                                enabled: canPost || community.type == CommunityType.group,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: canPost || community.type == CommunityType.group
                                      ? 'Post something...'
                                      : 'Only moderators can post here',
                                  hintStyle: TextStyle(color: NGColors.textMuted),
                                  filled: true,
                                  fillColor: NGColors.surface,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.send, color: NGColors.accent),
                              onPressed: _isPosting ? null : _post,
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                    ],
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
                  if (!postsSnap.hasData) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  final posts = postsSnap.data!.docs;
                  if (posts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('No posts yet', style: TextStyle(color: NGColors.textMuted)),
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
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NGColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: isOwnerPost
                                ? Border.all(color: const Color(0xFFFFD54F).withOpacity(0.35), width: 1)
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: avatarColor,
                                    child: Text(
                                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text('@$username',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ),
                                        _roleBadge(role),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _relativeTime(data['createdAt'] as Timestamp?),
                                    style: TextStyle(color: NGColors.textMuted, fontSize: 11),
                                  ),
                                  if (canPost) ...[
                                    const SizedBox(width: 4),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => _togglePin(doc.id, isPinned),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                          size: 16,
                                          color: isPinned ? const Color(0xFFFFD54F) : NGColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 36),
                                child: Text(data['text'] ?? '', style: TextStyle(color: NGColors.textSecondary)),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 30),
                                child: Row(
                                  children: [
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
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.chat_bubble_outline, size: 15, color: NGColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text('Reply', style: TextStyle(color: NGColors.textMuted, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
            ],
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
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('posts')
          .doc(postId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>;
        final username = (data['username'] ?? 'user').toString();
        final text = (data['text'] ?? '').toString();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD54F).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.push_pin, size: 14, color: Color(0xFFFFD54F)),
                  const SizedBox(width: 6),
                  Text('Pinned • @$username',
                      style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Text(text, style: TextStyle(color: NGColors.textSecondary)),
            ],
          ),
        );
      },
    );
  }
}

class _RepliesSheet extends StatefulWidget {
  final String communityId;
  final String postId;
  final bool canReply;

  const _RepliesSheet({
    required this.communityId,
    required this.postId,
    required this.canReply,
  });

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
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
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: NGColors.textMuted, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Replies', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
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
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final replies = snap.data!.docs;
                  if (replies.isEmpty) {
                    return Center(
                      child: Text('No replies yet', style: TextStyle(color: NGColors.textMuted)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: replies.length,
                    itemBuilder: (context, index) {
                      final data = replies[index].data() as Map<String, dynamic>;
                      final username = (data['username'] ?? 'user').toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@$username',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(data['text'] ?? '', style: TextStyle(color: NGColors.textSecondary)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (widget.canReply)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Write a reply...',
                          hintStyle: TextStyle(color: NGColors.textMuted),
                          filled: true,
                          fillColor: NGColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: NGColors.accent),
                      onPressed: _isSending ? null : _sendReply,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MembersSheet extends StatelessWidget {
  final String communityId;

  const _MembersSheet({required this.communityId});

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

  int _rolePriority(String role) {
    if (role == 'owner') return 0;
    if (role == 'moderator') return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: NGColors.textMuted, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Members', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const Divider(color: NGColors.divider, height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(communityId)
                  .collection('members')
                  .orderBy('joinedAt', descending: false)
                  .limit(200)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = List.of(snap.data!.docs);
                docs.sort((a, b) {
                  final roleA = ((a.data() as Map<String, dynamic>)['role'] ?? 'member').toString();
                  final roleB = ((b.data() as Map<String, dynamic>)['role'] ?? 'member').toString();
                  return _rolePriority(roleA).compareTo(_rolePriority(roleB));
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Text('No members yet', style: TextStyle(color: NGColors.textMuted)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final username = (data['username'] ?? 'member').toString();
                    final role = (data['role'] ?? 'member').toString();
                    final avatarColor = _colorForUsername(username);

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: avatarColor,
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text('@$username', style: const TextStyle(color: Colors.white, fontSize: 14)),
                      trailing: role == 'owner'
                          ? const Text('OWNER',
                              style: TextStyle(color: Color(0xFFFFD54F), fontSize: 10, fontWeight: FontWeight.bold))
                          : role == 'moderator'
                              ? Text('MOD',
                                  style: TextStyle(color: NGColors.accent, fontSize: 10, fontWeight: FontWeight.bold))
                              : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
