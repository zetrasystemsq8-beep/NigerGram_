import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/inbox/presentation/view/chat_view.dart';

class InboxView extends StatefulWidget {
  const InboxView({super.key});

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Toggles between the normal inbox and the archived-chats view.
  bool _showArchived = false;

  String get _currentUserId => AppAuth.uid;
  bool get _isUserLoggedIn => _currentUserId.isNotEmpty;

  String _getChatId(String userId1, String userId2) {
    final List<String> ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openChat(String chatId, String otherUserId) async {
    if (!_isUserLoggedIn || otherUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to chat')),
        );
      }
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(otherUserId).get();
      final displayName = userDoc.data()?['displayName'] ?? 'User';
      final profilePic = userDoc.data()?['profilePicUrl'] ?? '';

      try {
        await _firestore.collection('chats').doc(chatId).update({
          'participantData.${otherUserId}.displayName': displayName,
          'participantData.${otherUserId}.profilePic': profilePic,
          'unreadCount.${_currentUserId}': 0,
        });
      } catch (_) {}

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatView(
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserDisplayName: displayName,
              otherUserProfilePic: profilePic,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening chat: $e')),
        );
      }
    }
  }

  Future<void> _startNewChat(String otherUserId) async {
    if (!_isUserLoggedIn || otherUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to start a chat')),
        );
      }
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(otherUserId).get();
      final displayName = userDoc.data()?['displayName'] ?? 'User';
      final profilePic = userDoc.data()?['profilePicUrl'] ?? '';

      final chatId = _getChatId(_currentUserId, otherUserId);
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      if (chatDoc.exists) {
        // Reopening an existing chat should pull it out of Archived
        // automatically — otherwise it'd vanish from the main inbox
        // again the moment they leave the conversation.
        final data = chatDoc.data();
        final archivedBy = List<String>.from(data?['archivedBy'] ?? []);
        if (archivedBy.contains(_currentUserId)) {
          await _firestore.collection('chats').doc(chatId).update({
            'archivedBy': FieldValue.arrayRemove([_currentUserId]),
          });
        }
        await _openChat(chatId, otherUserId);
        return;
      }

      final currentUserData = await _firestore.collection('users').doc(_currentUserId).get();
      final currentDisplayName = currentUserData.data()?['displayName'] ??
          AppAuth.displayHandle;
      final currentProfilePic = currentUserData.data()?['profilePicUrl'] ?? '';

      await _firestore.collection('chats').doc(chatId).set({
        'participants': [_currentUserId, otherUserId],
        'participantData': {
          _currentUserId: {
            'displayName': currentDisplayName,
            'profilePic': currentProfilePic,
          },
          otherUserId: {
            'displayName': displayName,
            'profilePic': profilePic,
          },
        },
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': '',
        'unreadCount': {
          _currentUserId: 0,
          otherUserId: 0,
        },
        'archivedBy': <String>[],
        'typing': <String, bool>{},
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatView(
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserDisplayName: displayName,
              otherUserProfilePic: profilePic,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
        );
      }
    }
  }

  int _getUnreadCount(Map<String, dynamic> chat) {
    final unread = chat['unreadCount']?[_currentUserId];
    if (unread is num) return unread.toInt();
    return 0;
  }

  bool _isArchived(Map<String, dynamic> chat) {
    final archivedBy = chat['archivedBy'];
    if (archivedBy is List) return archivedBy.contains(_currentUserId);
    return false;
  }

  bool _isOtherUserTyping(Map<String, dynamic> chat, String otherUserId) {
    final typing = chat['typing'];
    if (typing is Map) return typing[otherUserId] == true;
    return false;
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Now';
  }

  Future<void> _archiveChat(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'archivedBy': FieldValue.arrayUnion([_currentUserId]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat archived'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive: $e')),
        );
      }
    }
  }

  Future<void> _unarchiveChat(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'archivedBy': FieldValue.arrayRemove([_currentUserId]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat moved to Inbox'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unarchive: $e')),
        );
      }
    }
  }

  Future<void> _deleteChat(String chatId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NGColors.surface,
        title: const Text('Delete conversation?', style: TextStyle(color: NGColors.textPrimary)),
        content: const Text(
          'This removes the conversation from your inbox permanently. This cannot be undone.',
          style: TextStyle(color: NGColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: NGColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('chats').doc(chatId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation deleted'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  void _showChatOptions(String chatId, bool isArchived) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NGColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NGColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                isArchived ? Icons.unarchive : Icons.archive,
                color: NGColors.textPrimary,
              ),
              title: Text(
                isArchived ? 'Move to Inbox' : 'Archive chat',
                style: const TextStyle(color: NGColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                isArchived ? _unarchiveChat(chatId) : _archiveChat(chatId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete conversation', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteChat(chatId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Avatar with a live green dot when the other user is online.
  /// Reads users/{otherUserId}.isOnline — see note on presence tracking.
  Widget _buildAvatarWithStatus(String otherUserId, String imageUrl, double radius) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildProfileImage(imageUrl, radius),
        if (otherUserId.isNotEmpty)
          Positioned(
            bottom: -1,
            right: -1,
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(otherUserId).snapshots(),
              builder: (context, snapshot) {
                final isOnline = snapshot.data?.get('isOnline') == true;
                if (!snapshot.hasData || !isOnline) return const SizedBox.shrink();
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: NGColors.background, width: 2),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProfileImage(String imageUrl, double radius) {
    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: NGColors.surfaceLight,
        child: Icon(Icons.person, color: NGColors.textMuted, size: radius * 1.2),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: NGColors.surfaceLight,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: NGColors.accent, strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: NGColors.surfaceLight,
          child: Icon(Icons.person, color: NGColors.textMuted, size: radius * 1.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        elevation: 0,
        title: Text(
          _showArchived ? '🗄️ Archived' : '💬 Inbox',
          style: const TextStyle(
            color: NGColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showArchived ? Icons.inbox : Icons.archive_outlined,
              color: NGColors.textPrimary,
            ),
            tooltip: _showArchived ? 'Back to Inbox' : 'Archived chats',
            onPressed: _isUserLoggedIn
                ? () => setState(() => _showArchived = !_showArchived)
                : null,
          ),
          if (!_showArchived)
            IconButton(
              icon: const Icon(Icons.person_add, color: NGColors.textPrimary),
              onPressed: _isUserLoggedIn ? () => _showNewChatDialog() : null,
            ),
        ],
      ),
      body: !_isUserLoggedIn
          ? const Center(
              child: Text(
                'Please login to view messages',
                style: TextStyle(color: NGColors.textSecondary),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: NGColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      hintStyle: const TextStyle(color: NGColors.textMuted),
                      prefixIcon: const Icon(Icons.search, color: NGColors.textMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: NGColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: NGColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('chats')
                        .where('participants', arrayContains: _currentUserId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading chats: ${snapshot.error}',
                            style: const TextStyle(color: NGColors.textMuted),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: NGColors.accent),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
                      sortedDocs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aTime = aData['lastMessageTime'] as Timestamp?;
                        final bTime = bData['lastMessageTime'] as Timestamp?;
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        return bTime.compareTo(aTime);
                      });

                      final chatList = sortedDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        data['id'] = doc.id;
                        return data;
                      }).toList();

                      // Split into inbox vs archived based on current toggle.
                      final scopedChats = chatList
                          .where((chat) => _isArchived(chat) == _showArchived)
                          .toList();

                      if (scopedChats.isEmpty && !_showArchived) return _buildEmptyState();
                      if (scopedChats.isEmpty && _showArchived) return _buildEmptyArchiveState();

                      final filteredChats = _searchQuery.isEmpty
                          ? scopedChats
                          : scopedChats.where((chat) {
                              final participants = chat['participantData'] as Map<String, dynamic>? ?? {};
                              final otherUserId = (chat['participants'] as List).firstWhere(
                                (id) => id != _currentUserId,
                                orElse: () => '',
                              );
                              final otherUserData = participants[otherUserId] as Map<String, dynamic>? ?? {};
                              final name = (otherUserData['displayName'] ?? '').toString().toLowerCase();
                              final username = (otherUserData['username'] ?? '').toString().toLowerCase();
                              return name.contains(_searchQuery) || username.contains(_searchQuery);
                            }).toList();

                      if (filteredChats.isEmpty && _searchQuery.isNotEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off, color: NGColors.textMuted, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'No results for "$_searchQuery"',
                                style: const TextStyle(color: NGColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        itemCount: filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = filteredChats[index];
                          final chatId = chat['id'];
                          final participants = List<String>.from(chat['participants'] ?? []);
                          final otherUserId = participants.firstWhere(
                            (id) => id != _currentUserId,
                            orElse: () => '',
                          );

                          if (otherUserId.isEmpty) return const SizedBox.shrink();

                          final participantData = chat['participantData'] as Map<String, dynamic>? ?? {};
                          final otherUserData = participantData[otherUserId] as Map<String, dynamic>? ?? {};
                          final displayName = otherUserData['displayName'] ?? 'User';
                          final profilePic = otherUserData['profilePic'] ?? '';
                          final lastMessage = chat['lastMessage'] ?? 'Start chatting...';
                          final lastMessageTime = chat['lastMessageTime'] as Timestamp?;
                          final unreadCount = _getUnreadCount(chat);
                          final isTyping = _isOtherUserTyping(chat, otherUserId);

                          return GestureDetector(
                            onTap: () => _openChat(chatId, otherUserId),
                            onLongPress: () => _showChatOptions(chatId, _showArchived),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: unreadCount > 0 ? NGColors.surface : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: NGColors.divider.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildAvatarWithStatus(otherUserId, profilePic, 26),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                displayName,
                                                style: TextStyle(
                                                  color: NGColors.textPrimary,
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  fontSize: 15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              _formatTime(lastMessageTime),
                                              style: const TextStyle(
                                                color: NGColors.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: isTyping
                                                  ? const Text(
                                                      'typing...',
                                                      style: TextStyle(
                                                        color: NGColors.accent,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 13,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    )
                                                  : Text(
                                                      lastMessage,
                                                      style: TextStyle(
                                                        color: unreadCount > 0
                                                            ? NGColors.textPrimary
                                                            : NGColors.textMuted,
                                                        fontWeight: unreadCount > 0
                                                            ? FontWeight.w600
                                                            : FontWeight.normal,
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                            ),
                                            if (unreadCount > 0)
                                              Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                padding: const EdgeInsets.all(6),
                                                decoration: const BoxDecoration(
                                                  color: NGColors.accent,
                                                  shape: BoxShape.circle,
                                                ),
                                                constraints: const BoxConstraints(
                                                  minWidth: 20,
                                                  minHeight: 20,
                                                ),
                                                child: Text(
                                                  unreadCount.toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: _showArchived
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: FloatingActionButton(
                backgroundColor: NGColors.accent,
                child: const Icon(Icons.chat, color: Colors.white),
                onPressed: _isUserLoggedIn ? () => _showNewChatDialog() : null,
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, color: NGColors.textMuted, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
              color: NGColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a conversation with someone!',
            style: TextStyle(color: NGColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isUserLoggedIn ? () => _showNewChatDialog() : null,
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('Find People'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NGColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyArchiveState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined, color: NGColors.textMuted, size: 64),
          SizedBox(height: 16),
          Text(
            'No archived chats',
            style: TextStyle(
              color: NGColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog() {
    if (!_isUserLoggedIn) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NewChatSheet(
        onUserSelected: (userId) => _startNewChat(userId),
      ),
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  final void Function(String userId) onUserSelected;
  const _NewChatSheet({required this.onUserSelected});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  String get _currentUserId => AppAuth.uid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildProfileImage(String imageUrl, double radius) {
    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: NGColors.surfaceLight,
        child: Icon(Icons.person, color: NGColors.textMuted, size: radius * 1.2),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: NGColors.surfaceLight,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: NGColors.accent, strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: NGColors.surfaceLight,
          child: Icon(Icons.person, color: NGColors.textMuted, size: radius * 1.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: NGColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NGColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'New Conversation',
            style: TextStyle(
              color: NGColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: NGColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by name or username...',
              hintStyle: const TextStyle(color: NGColors.textMuted),
              prefixIcon: const Icon(Icons.search, color: NGColors.textMuted),
              filled: true,
              fillColor: NGColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .orderBy('displayName')
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: NGColors.accent),
                  );
                }

                final docs = snapshot.data!.docs;
                final filteredDocs = _searchQuery.isEmpty
                    ? docs
                    : docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['displayName'] ?? '').toString().toLowerCase();
                        final username = (data['username'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery) || username.contains(_searchQuery);
                      }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_off, color: NGColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty ? 'No users found' : 'No results for "$_searchQuery"',
                          style: const TextStyle(color: NGColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = doc.id;
                    if (userId == _currentUserId) return const SizedBox.shrink();
                    final displayName = data['displayName'] ?? 'User';
                    final username = data['username'] ?? 'user';
                    final profilePic = data['profilePicUrl'] ?? '';
                    return ListTile(
                      leading: _buildProfileImage(profilePic, 22),
                      title: Text(displayName, style: const TextStyle(color: NGColors.textPrimary)),
                      subtitle: Text('@$username', style: const TextStyle(color: NGColors.textMuted, fontSize: 12)),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onUserSelected(userId);
                      },
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
